//
//  Components.swift
//  Lane04
//
//  Composants UI partagés, conformes au design system (§06, §09).
//

import SwiftUI

// MARK: - Tag de filière (contour, couleur = température, radius 0)

struct TagBadge: View {
    let discipline: Discipline
    var body: some View {
        Text(discipline.tag)
            .font(.label)
            .tracking(1.5)
            .foregroundStyle(discipline.tint)
            .padding(.horizontal, Spacing.s)
            .padding(.vertical, Spacing.xs)
            .overlay {
                RoundedRectangle(cornerRadius: Radius.badge)
                    .strokeBorder(discipline.tint.opacity(0.55), lineWidth: 1)
            }
    }
}

// MARK: - Statut d'un protocole ([BRACKET], couleur selon l'état)

struct StateBadge: View {
    let state: ProtocolState
    private var tint: Color {
        switch state {
        case .synced: return .cryo    // confirmé
        case .fault:  return .ember   // faute / action requise
        default:      return .steelHi
        }
    }
    var body: some View {
        Text("[\(state.rawValue)]")
            .font(.label)
            .tracking(1.5)
            .foregroundStyle(tint)
            .padding(.horizontal, Spacing.s)
            .padding(.vertical, Spacing.xs)
            .overlay {
                RoundedRectangle(cornerRadius: Radius.badge)
                    .strokeBorder(tint.opacity(0.4), lineWidth: 1)
            }
    }
}

/// Statut d'une séance PLANIFIÉE. PLANNED = contour steel (attente) ; SCHEDULED =
/// cyan (confirmé, sur la montre) ; FAULT = ember (action requise).
struct PlannedStateBadge: View {
    let state: PlannedState
    private var tint: Color {
        switch state {
        case .scheduled: return .cryo
        case .fault:     return .ember
        case .planned:   return .steelHi
        }
    }
    var body: some View {
        Text("[\(state.rawValue)]")
            .font(.label).tracking(1.5).foregroundStyle(tint)
            .padding(.horizontal, Spacing.s).padding(.vertical, Spacing.xs)
            .overlay {
                RoundedRectangle(cornerRadius: Radius.badge)
                    .strokeBorder(tint.opacity(0.4), lineWidth: 1)
            }
    }
}

// MARK: - Bouton d'action primaire (aplat EMBER — la seule couleur pleine)

struct PrimaryActionButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button {
            Haptic.arm()
            action()
        } label: {
            Text(title)
                .font(.button)
                .foregroundStyle(Color.void)
                .frame(maxWidth: .infinity, minHeight: Touch.min)
                .padding(.vertical, Spacing.m)
                .background(Color.ember, in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
        }
        .buttonStyle(PressableStyle())
    }
}

/// Bouton de recours EN CONTOUR (hairline, jamais d'aplat) — ne dépense pas
/// l'accent de l'écran. Réservé aux voies secondaires (« plus tard », raccourcis).
struct OutlineActionButton: View {
    let title: String
    /// Contour en pointillé (grammaire `[DRAFT]`, §09) — pour une action qui
    /// fabrique un brouillon vierge (ex. NEW FROM SCRATCH). Trait plein sinon.
    var dashed: Bool = false
    let action: () -> Void

    var body: some View {
        Button {
            Haptic.selection()
            action()
        } label: {
            Text(title)
                .font(.label).tracking(1.5)
                .foregroundStyle(Color.steel)
                .frame(maxWidth: .infinity, minHeight: Touch.min)
                .padding(.vertical, Spacing.s)
                .overlay {
                    // Pointillé = signal [DRAFT] lisible (steel, tirets marqués) ;
                    // trait plein = hairline discret (contour secondaire neutre).
                    RoundedRectangle(cornerRadius: Radius.button)
                        .strokeBorder(dashed ? Color.steel : Surface.hairline,
                                      style: StrokeStyle(lineWidth: dashed ? 1.5 : 1,
                                                         dash: dashed ? [6, 5] : []))
                }
        }
        .buttonStyle(PressableStyle())
    }
}

/// Style pressé conforme : scale 0.97, courbe maîtresse, 90 ms. Transform only.
struct PressableStyle: ButtonStyle {
    func makeBody(configuration configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.master(Duration.micro), value: configuration.isPressed)
    }
}

// MARK: - QUAD — l'unique indicateur animé (quatre rectangles, §03)

struct QuadIndicator: View {
    var lit: Int
    var tint: Color = .ember
    var barWidth: CGFloat = 12
    var height: CGFloat = 48

    var body: some View {
        HStack(spacing: Spacing.s) {
            ForEach(0..<4, id: \.self) { i in
                Rectangle() // radius 0 — aucune courbe
                    .fill(i < lit ? tint : Color.steelDim.opacity(0.4))
                    .frame(width: barWidth, height: height)
            }
        }
    }
}

// MARK: - Carte de faute (contour, cause nommée, une seule action de recours)

struct FaultCard: View {
    let status: String            // système, mono → [STATUS]
    let cause: String             // ligne système en clair (mono)
    var detail: String? = nil     // explication française (langue de lecture)
    var ctaTitle: String? = nil
    var blinking: Bool = false    // clignotement 1.2 s = faute qui exige une action
    var action: (() -> Void)? = nil

    @State private var blink = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Text("[\(status)]")
                .font(.label).tracking(1.5).foregroundStyle(Color.ember)
                .opacity(blinking && blink ? 0.3 : 1)
            Text(cause)
                .font(.data).foregroundStyle(Color.laneWhite).metricDigits()
                .fixedSize(horizontal: false, vertical: true)
            if let detail {
                Text(detail)
                    .font(.bodyBrand).foregroundStyle(Color.steel)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let ctaTitle, let action {
                Button(action: action) {
                    Text(ctaTitle)
                        .font(.button).foregroundStyle(Color.ember)
                        .frame(maxWidth: .infinity, minHeight: Touch.min).padding(.vertical, Spacing.m)
                        .overlay {
                            RoundedRectangle(cornerRadius: Radius.button)
                                .strokeBorder(Color.ember, lineWidth: 1.5)
                        }
                }
                .buttonStyle(PressableStyle())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.l)
        .overlay {
            RoundedRectangle(cornerRadius: Radius.card)
                .strokeBorder(Color.ember.opacity(0.5), lineWidth: 1)
        }
        .onAppear {
            if blinking {
                withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) { blink = true }
            }
        }
    }
}

// MARK: - Formatage des métriques (chasse fixe, majuscules)

enum Format {
    static func distanceKM(_ meters: Double) -> String {
        String(format: "%.1f KM", meters / 1000)
    }
    static func duration(_ seconds: TimeInterval) -> String {
        let t = Int(seconds.rounded())
        let h = t / 3600, m = (t % 3600) / 60, s = t % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }

    /// CHARGE d'entraînement (TRIMP sommé) : score entier, sans unité. Le libellé
    /// « CHARGE » porte le sens ; l'instrument n'ajoute pas d'unité décorative.
    static func load(_ trimp: Int) -> String { "\(trimp)" }

    /// Objectif de pas en durée : « 45 S » sous la minute, « 12 MIN » si multiple
    /// entier, sinon « 1:30 MIN ». Compact, majuscules, pour le builder.
    static func goalTime(_ seconds: Int) -> String {
        if seconds < 60 { return "\(seconds) S" }
        let m = seconds / 60, s = seconds % 60
        return s == 0 ? "\(m) MIN" : String(format: "%d:%02d MIN", m, s)
    }

    /// Objectif de pas en distance : « 400 M » sous le km, « 1.5 KM » au-delà.
    static func goalDistance(_ meters: Int) -> String {
        meters < 1000 ? "\(meters) M" : String(format: "%.1f KM", Double(meters) / 1000)
    }

    private static let dateTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd/MM · HH:mm"
        return f
    }()
    static func dateTime(_ date: Date) -> String { dateTimeFormatter.string(from: date) }

    private static let dayMonthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd.MM"
        return f
    }()
    static func dayMonth(_ date: Date) -> String { dayMonthFormatter.string(from: date) }

    /// Chrono mm:ss à partir de secondes (saisie course).
    static func clock(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

// MARK: - État vide (le zéro est une donnée, en mono, jamais une excuse)

struct EmptyStateView: View {
    let headline: String
    let metric: String
    let note: String

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Text(metric)
                .font(.dataXL)
                .foregroundStyle(Color.laneWhite)
                .metricDigits()
            Text(headline)
                .font(.label)
                .tracking(1.5)
                .foregroundStyle(Color.steelHi)
            Text(note)
                .font(.bodyBrand)
                .foregroundStyle(Color.steel)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.l)
        .glassCard()
    }
}

