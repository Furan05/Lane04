//
//  ConsoleScreen.swift
//  Lane04
//
//  Écran 07 — CONSOLE. Réglages en paires clé/valeur (@AppStorage) + accès OPERATOR.
//  TX MODE ne sera réellement testable qu'avec l'injection (Phase 3).
//

import SwiftUI
import SwiftData

struct ConsoleScreen: View {
    @AppStorage(SettingsKey.txMode) private var txMode = TXMode.ritual.rawValue
    @AppStorage(SettingsKey.paceUnit) private var paceUnit = PaceUnit.minPerKm.rawValue
    @AppStorage(SettingsKey.haptics) private var haptics = true
    @AppStorage(SettingsKey.watchTarget) private var target = WatchTarget.ultra2.rawValue

    @AppStorage(SettingsKey.garminBackendURL) private var garminRelayURL = ""

    @Query private var profiles: [OperatorProfile]
    private var vma: Double { profiles.first?.vma ?? 16.0 }

    @State private var garminLinked = false
    @State private var garminBusy = false
    @State private var garminFault: String?
    @State private var editingRelay = false
    @State private var relayDraft = ""
    @State private var confirmUnlink = false

    var body: some View {
        NavigationStack {
            ScreenScaffold(title: "CONSOLE", status: "V1.0") {
                VStack(spacing: Spacing.l) {
                    NavigationLink { OperatorScreen() } label: { operatorRow }
                        .buttonStyle(PressableStyle())

                    settingsCard
                    garminCard
                    helpCard
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .onAppear { garminLinked = GarminIntegration.shared.isConnected }
        .alert("GARMIN RELAY", isPresented: $editingRelay) {
            TextField("https://relay.exemple.com", text: $relayDraft)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
            Button("COMMIT") {
                garminRelayURL = relayDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                garminFault = nil
            }
            Button("CANCEL", role: .cancel) { }
        } message: {
            Text("L'URL de ton relais Garmin auto-hébergé (voir backend/README.md). Laisser vide pour désactiver.")
        }
        .alert("GARMIN UNLINK", isPresented: $confirmUnlink) {
            Button("UNLINK", role: .destructive) { unlinkGarmin() }
            Button("CANCEL", role: .cancel) { }
        } message: {
            Text("Le compte Garmin sera délié. Les séances déjà envoyées restent sur le compte.")
        }
    }

    // MARK: OPERATOR entry

    private var operatorRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("OPERATOR").font(.button).foregroundStyle(Color.laneWhite)
                Text("PROFIL PHYSIOLOGIQUE").font(.label).tracking(1.5).foregroundStyle(Color.steelHi)
            }
            Spacer()
            Text("VMA \(String(format: "%.1f", vma))")
                .font(.data).foregroundStyle(Color.cryo).metricDigits()
            Image(systemName: "chevron.right").font(.headline).foregroundStyle(Color.steel)
        }
        .frame(maxWidth: .infinity, minHeight: Touch.min, alignment: .leading)
        .padding(Spacing.l)
        .glassCard()
    }

    // MARK: Réglages

    private var settingsCard: some View {
        VStack(spacing: 0) {
            cycleRow("TX MODE", $txMode, TXMode.allCases.map(\.rawValue))
            hairline
            cycleRow("UNITS", $paceUnit, PaceUnit.allCases.map(\.rawValue))
            hairline
            toggleRow("HAPTICS", $haptics)
            hairline
            cycleRow("TARGET", $target, WatchTarget.allCases.map(\.rawValue))
        }
        .padding(.horizontal, Spacing.l)
        .glassCard()
    }

    private func cycleRow(_ key: String, _ value: Binding<String>, _ options: [String]) -> some View {
        Button {
            Haptic.selection()
            let i = options.firstIndex(of: value.wrappedValue) ?? -1
            value.wrappedValue = options[(i + 1) % options.count]
        } label: {
            row(key, value.wrappedValue)
        }
        .buttonStyle(.plain)
    }

    private func toggleRow(_ key: String, _ value: Binding<Bool>) -> some View {
        Button {
            Haptic.selection()
            value.wrappedValue.toggle()
        } label: {
            row(key, value.wrappedValue ? "ON" : "OFF")
        }
        .buttonStyle(.plain)
    }

    private func row(_ key: String, _ value: String) -> some View {
        HStack {
            Text(key).font(.label).tracking(1.5).foregroundStyle(Color.steel)
            Spacer()
            Text(value).font(.data).foregroundStyle(Color.laneWhite).metricDigits()
        }
        .frame(minHeight: Touch.min)
        .contentShape(Rectangle())
    }

    private var hairline: some View {
        Rectangle().fill(Surface.hairline).frame(height: 1)
    }

    // MARK: GARMIN — relais auto-hébergé + lien de compte

    /// Le lien Garmin passe par un relais que l'athlète héberge lui-même
    /// (backend/) : l'app ne détient jamais le secret Garmin. Tant qu'aucun
    /// relais n'est renseigné, seule la ligne de configuration apparaît.
    private var garminCard: some View {
        VStack(spacing: 0) {
            Button {
                Haptic.selection()
                relayDraft = garminRelayURL
                editingRelay = true
            } label: {
                row("GARMIN RELAY", relayLabel)
            }
            .buttonStyle(.plain)

            if GarminIntegration.shared.isConfigured {
                hairline
                Button {
                    Haptic.selection()
                    if garminLinked { confirmUnlink = true } else { linkGarmin() }
                } label: {
                    HStack {
                        Text("GARMIN LINK").font(.label).tracking(1.5).foregroundStyle(Color.steel)
                        Spacer()
                        Text(garminBusy ? "LINKING…" : (garminLinked ? "[LINKED]" : "[NO LINK]"))
                            .font(.data)
                            .foregroundStyle(garminLinked ? Color.cryo : Color.steelHi)
                            .metricDigits()
                    }
                    .frame(minHeight: Touch.min)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(garminBusy)
            }

            // La faute nomme sa cause et propose UNE action : réappuyer (§10).
            if let fault = garminFault {
                Text("\(fault) — RETRY")
                    .font(.label).tracking(1.5)
                    .foregroundStyle(Color.ember)
                    .frame(maxWidth: .infinity, minHeight: Touch.min, alignment: .leading)
            }
        }
        .padding(.horizontal, Spacing.l)
        .glassCard()
    }

    private var relayLabel: String {
        if let host = GarminConfiguration.backendURL?.host { return host.uppercased() }
        return garminRelayURL.isEmpty ? "OFF" : "INVALID"
    }

    private func linkGarmin() {
        garminFault = nil
        garminBusy = true
        Task {
            do {
                try await GarminIntegration.shared.connect()
                garminLinked = true
            } catch GarminIntegrationError.authorizationCancelled {
                // Annulation volontaire : pas une faute, pas de message.
            } catch {
                garminFault = error.localizedDescription
            }
            garminBusy = false
        }
    }

    private func unlinkGarmin() {
        garminBusy = true
        Task {
            try? await GarminIntegration.shared.disconnect()
            garminLinked = GarminIntegration.shared.isConnected
            garminBusy = false
        }
    }

    // MARK: Aide — à quoi sert chaque réglage (français, langue de lecture §02)

    private var helpCard: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            Text("AIDE").font(.label).tracking(1.5).foregroundStyle(Color.steelHi)
            helpRow("TX MODE",
                    "La mise en scène de l'envoi vers la montre. RITUAL = l'animation complète ; FAST = envoi rapide. Passe tout seul en FAST après 10 envois réussis.")
            helpRow("UNITS",
                    "L'unité d'affichage des allures : MIN/KM (minutes par kilomètre) ou KM/H (kilomètres par heure).")
            helpRow("HAPTICS",
                    "Les vibrations de retour, à chaque appui et pendant l'injection. ON pour les sentir, OFF pour le silence.")
            helpRow("TARGET",
                    "Le modèle d'Apple Watch visé pour l'envoi : ULTRA 2, SERIES ou SE.")
            helpRow("GARMIN",
                    "Réservé aux montres Garmin : renseigne l'URL de ton relais LANE 04 (auto-hébergé, dossier backend/ du projet), puis lie ton compte Garmin. L'envoi des séances vers la montre Garmin arrivera dans une prochaine version.")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.l)
        .glassCard()
    }

    private func helpRow(_ key: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(key).font(.label).tracking(1.5).foregroundStyle(Color.laneWhite)
            Text(text).font(.bodyBrand).foregroundStyle(Color.steel)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
