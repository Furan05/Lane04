//
//  GarminIntegration.swift
//  Lane04
//
//  Adaptateur Garmin côté iOS. Le téléphone ne parle pas directement à la
//  montre et ne contient jamais le client secret Garmin : le backend LANE 04
//  (backend/, auto-hébergeable) orchestre OAuth et appelle la Garmin Training
//  API. Ici : lancement de l'autorisation (ASWebAuthenticationSession), garde
//  du jeton de connexion en Keychain, et envoi du protocole validé au relais.
//

import AuthenticationServices
import Foundation
import Security
import UIKit

enum GarminIntegrationError: LocalizedError, Equatable {
    case configurationMissing
    case notConnected
    case authorizationCancelled
    case invalidAuthorizationCallback
    case backendUnavailable
    case backendRejected(Int)

    var errorDescription: String? {
        switch self {
        case .configurationMissing:        return "GARMIN RELAY NOT CONFIGURED"
        case .notConnected:                return "GARMIN ACCOUNT NOT CONNECTED"
        case .authorizationCancelled:      return "GARMIN AUTHORIZATION CANCELLED"
        case .invalidAuthorizationCallback: return "GARMIN AUTHORIZATION INVALID"
        case .backendUnavailable:          return "GARMIN RELAY UNREACHABLE"
        case .backendRejected(let code):   return "GARMIN RELAY REJECTED (\(code))"
        }
    }
}

enum GarminConfiguration {
    /// URL du relais : Info.plist (`GARMIN_BACKEND_URL`, déploiement) sinon
    /// réglage CONSOLE (`SettingsKey.garminBackendURL`). Jamais de secret ici :
    /// le client secret Garmin ne vit que sur le relais.
    static var backendURL: URL? {
        let raw = (Bundle.main.object(forInfoDictionaryKey: "GARMIN_BACKEND_URL") as? String)
            ?? UserDefaults.standard.string(forKey: SettingsKey.garminBackendURL)
        guard let raw, let url = URL(string: raw.trimmingCharacters(in: .whitespacesAndNewlines)),
              let host = url.host else { return nil }
        if url.scheme == "https" { return url }
        #if DEBUG
        // Relais local pendant le développement (ATS exempte localhost).
        if url.scheme == "http", host == "localhost" || host == "127.0.0.1" { return url }
        #endif
        return nil
    }

    /// Le relais redirige vers `lane04://garmin/oauth/callback?connection_token=…`
    /// → host `garmin`, path `/oauth/callback` (le scheme custom fait de `garmin`
    /// le host de l'URL, pas un segment de chemin).
    static let callbackScheme = "lane04"
    static let callbackHost = "garmin"
    static let callbackPath = "/oauth/callback"
}

private struct AuthorizationStart: Decodable {
    let authorizationURL: URL
}

/// Contrat JSON envoyé au relais (`POST /v1/garmin/workouts`). Le relais
/// re-valide tout (bornes ProtocolValidator) puis convertit vers le format
/// Garmin Training API — le téléphone n'émet que des données LANE 04.
struct GarminWorkoutPayload: Encodable, Equatable {
    struct Step: Encodable, Equatable {
        let role: String
        let goalKind: String
        let goalValue: Double
        let percentVMA: Double
        let targetsPace: Bool
    }

    struct Block: Encodable, Equatable {
        let title: String
        let iterations: Int
        let steps: [Step]
    }

    let name: String
    /// Jour calendaire local `yyyy-MM-dd` — le schedule Garmin est un jour,
    /// pas un instant ; formater côté client évite toute dérive de fuseau.
    let scheduledDate: String
    let vma: Double
    let discipline: String
    let blocks: [Block]

    init(proto: RunProtocol, vma: Double, at date: Date) {
        let formatter = DateFormatter()
        formatter.calendar = .current
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"

        self.name = proto.name
        self.scheduledDate = formatter.string(from: date)
        self.vma = vma
        self.discipline = proto.discipline.rawValue
        self.blocks = proto.blocks.sorted { $0.order < $1.order }.map { block in
            Block(
                title: block.title,
                iterations: block.iterations,
                steps: block.steps.sorted { $0.order < $1.order }.map { step in
                    Step(
                        role: step.role.rawValue,
                        goalKind: step.goalKind == .time ? "TIME" : "DISTANCE",
                        goalValue: step.goalValue,
                        percentVMA: step.percentVMA,
                        targetsPace: step.targetsPace
                    )
                }
            )
        }
    }
}

@MainActor
final class GarminIntegration {
    static let shared = GarminIntegration()

    private let tokenStore = GarminTokenStore()
    private var webSession: GarminWebAuthenticationSession?

    var isConfigured: Bool { GarminConfiguration.backendURL != nil }
    var isConnected: Bool { tokenStore.hasToken }

    func connect() async throws {
        guard let baseURL = GarminConfiguration.backendURL else {
            throw GarminIntegrationError.configurationMissing
        }

        var request = URLRequest(url: baseURL.appendingPathComponent("v1/garmin/oauth/start"))
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let start: AuthorizationStart
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw GarminIntegrationError.backendUnavailable
            }
            start = try JSONDecoder().decode(AuthorizationStart.self, from: data)
        } catch let error as GarminIntegrationError {
            throw error
        } catch {
            throw GarminIntegrationError.backendUnavailable
        }

        let callback: URL
        do {
            webSession = GarminWebAuthenticationSession()
            callback = try await webSession!.authenticate(start.authorizationURL,
                                                          callbackScheme: GarminConfiguration.callbackScheme)
            webSession = nil
        } catch let error as GarminIntegrationError {
            webSession = nil
            throw error
        } catch {
            webSession = nil
            throw GarminIntegrationError.authorizationCancelled
        }

        guard callback.host == GarminConfiguration.callbackHost,
              callback.path == GarminConfiguration.callbackPath,
              let token = URLComponents(url: callback, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "connection_token" })?.value,
              !token.isEmpty else {
            throw GarminIntegrationError.invalidAuthorizationCallback
        }
        try tokenStore.save(token)
    }

    /// Coupe le lien : demande au relais d'oublier la connexion (best effort —
    /// un relais injoignable ne doit pas empêcher l'oubli local), puis efface
    /// le jeton du Keychain. L'état local redevient NO LINK quoi qu'il arrive.
    func disconnect() async throws {
        if let baseURL = GarminConfiguration.backendURL,
           let token = try? tokenStore.read() {
            var request = URLRequest(url: baseURL.appendingPathComponent("v1/garmin/connection"))
            request.httpMethod = "DELETE"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            _ = try? await URLSession.shared.data(for: request)
        }
        try tokenStore.delete()
    }

    /// Publie un protocole daté sur le compte Garmin lié. Même ligne de défense
    /// que WorkoutKit : rien ne part sans passer par `ProtocolValidator`.
    func publish(proto: RunProtocol, vma: Double, at date: Date) async throws {
        try ProtocolValidator.validate(proto, vma: vma)
        guard let token = try tokenStore.read() else {
            throw GarminIntegrationError.notConnected
        }
        guard let baseURL = GarminConfiguration.backendURL else {
            throw GarminIntegrationError.configurationMissing
        }

        let payload = GarminWorkoutPayload(proto: proto, vma: vma, at: date)

        var request = URLRequest(url: baseURL.appendingPathComponent("v1/garmin/workouts"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(payload)

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw GarminIntegrationError.backendUnavailable
            }
            guard (200..<300).contains(http.statusCode) else {
                throw GarminIntegrationError.backendRejected(http.statusCode)
            }
        } catch let error as GarminIntegrationError {
            throw error
        } catch {
            throw GarminIntegrationError.backendUnavailable
        }
    }
}

private final class GarminWebAuthenticationSession: NSObject,
    ASWebAuthenticationPresentationContextProviding {
    private var session: ASWebAuthenticationSession?

    func authenticate(_ url: URL, callbackScheme: String) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let auth = ASWebAuthenticationSession(url: url, callbackURLScheme: callbackScheme) { callback, error in
                if let callback {
                    continuation.resume(returning: callback)
                } else if let error = error as? ASWebAuthenticationSessionError,
                          error.code == .canceledLogin {
                    continuation.resume(throwing: GarminIntegrationError.authorizationCancelled)
                } else {
                    continuation.resume(throwing: error ?? GarminIntegrationError.authorizationCancelled)
                }
            }
            auth.presentationContextProvider = self
            auth.prefersEphemeralWebBrowserSession = false
            session = auth
            guard auth.start() else {
                continuation.resume(throwing: GarminIntegrationError.authorizationCancelled)
                session = nil
                return
            }
        }
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow) ?? ASPresentationAnchor()
    }
}

private final class GarminTokenStore {
    private let service = "furan.Lane04.garmin"
    private let account = "connection-token"

    var hasToken: Bool { (try? read()) != nil }

    func save(_ token: String) throws {
        let data = Data(token.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
        var item = query
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(item as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError(status) }
    }

    func read() throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else { throw KeychainError(status) }
        return String(data: data, encoding: .utf8)
    }

    func delete() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw KeychainError(status) }
    }
}

private struct KeychainError: Error {
    let status: OSStatus
    init(_ status: OSStatus) { self.status = status }
}
