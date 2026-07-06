//
//  Components.swift
//  Lane04
//
//  Composants UI partagés, conformes au design system (§06, §09).
//

import SwiftUI
import UIKit

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

/// Style pressé conforme : scale 0.97, courbe maîtresse, 90 ms. Transform only.
struct PressableStyle: ButtonStyle {
    func makeBody(configuration configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.master(Duration.micro), value: configuration.isPressed)
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

// MARK: - Interpolation de couleur (dégradé thermique EMBER↔CRYO)

extension Color {
    func blended(with other: Color, t: Double) -> Color {
        let a = UIColor(self), b = UIColor(other)
        var ar: CGFloat = 0, ag: CGFloat = 0, ab: CGFloat = 0, aa: CGFloat = 0
        var br: CGFloat = 0, bg: CGFloat = 0, bb: CGFloat = 0, ba: CGFloat = 0
        a.getRed(&ar, green: &ag, blue: &ab, alpha: &aa)
        b.getRed(&br, green: &bg, blue: &bb, alpha: &ba)
        let k = CGFloat(max(0, min(1, t)))
        return Color(.sRGB,
                     red: Double(ar + (br - ar) * k),
                     green: Double(ag + (bg - ag) * k),
                     blue: Double(ab + (bb - ab) * k),
                     opacity: Double(aa + (ba - aa) * k))
    }
}
