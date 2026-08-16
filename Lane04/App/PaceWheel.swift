//
//  PaceWheel.swift
//  Lane04
//
//  Molette d'allure horizontale (mode de saisie COMPLÉMENTAIRE — les boutons ±5 S
//  restent la voie précise). Le curseur EMBER est FIXE au centre : c'est l'échelle
//  qui défile dessous, comme une règle qu'on fait glisser sous une aiguille.
//
//  Aimantation native : `scrollTargetBehavior(.viewAligned)` + `scrollPosition(id:)`.
//  Le système porte l'inertie et le calage ; nous ne réimplémentons pas de gesture.
//

import SwiftUI

struct PaceWheel: View {
    /// L'allure en secondes/km — la valeur de travail de la molette, partagée avec
    /// les boutons de l'éditeur (synchronisation dans les deux sens).
    @Binding var paceSeconds: Int
    let vma: Double
    /// VMA mesurée ou seulement estimée → mention discrète sous le readout.
    var provenance: VMAProvenance = .calibrated

    /// Le cran actuellement centré. Distinct de `paceSeconds` : celui-ci peut sortir
    /// des bornes de la molette (les boutons vont plus loin), la molette se contente
    /// alors de buter sur son extrémité sans tirer la valeur avec elle.
    @State private var centered: Int?
    /// Vrai le temps d'un recentrage PROGRAMMATIQUE (les boutons ont bougé la valeur) :
    /// évite que le recentrage ne se réinjecte dans `paceSeconds` et l'aimante de force.
    @State private var recentringFromValue = false

    private var notches: [Int] { PaceScale.notches(vma: vma) }
    private var boundaries: Set<Int> { PaceScale.zoneBoundaries(vma: vma) }
    private var percent: Int { PaceScale.percent(paceSeconds: paceSeconds, vma: vma) }
    private var zone: TrainingZone? { PaceScale.zone(paceSeconds: paceSeconds, vma: vma) }

    private static let tickSpacing: CGFloat = 18

    var body: some View {
        VStack(spacing: Spacing.m) {
            readout
            wheel
        }
        .onAppear { centered = PaceScale.resolve(paceSeconds, vma: vma) }
        .onChange(of: paceSeconds) { _, new in
            // Les boutons ont parlé : on recentre la molette sans rien lui faire dire.
            let target = PaceScale.resolve(new, vma: vma)
            guard centered != target else { return }
            recentringFromValue = true
            withAnimation(.master(Duration.micro)) { centered = target }
        }
        .onChange(of: centered) { _, new in
            guard let new else { return }
            if recentringFromValue { recentringFromValue = false; return }
            guard new != paceSeconds else { return }
            paceSeconds = new
            Haptic.tick()          // un cran franchi = une impulsion légère
        }
    }

    // MARK: - Readout central : le % en gros (donnée), l'allure en second rang

    private var readout: some View {
        VStack(spacing: Spacing.xs) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                Text("\(percent)")
                    .font(.dataXL).foregroundStyle(Color.laneWhite)
                    .metricDigits().contentTransition(.numericText())
                Text("% VMA").font(.label).tracking(1.5).foregroundStyle(Color.steel)
            }
            HStack(spacing: Spacing.xs) {
                Text(PaceScale.label(paceSeconds))
                    .font(.data).foregroundStyle(Color.steel).metricDigits()
                Text("/KM").font(.label).tracking(1.5).foregroundStyle(Color.steelHi)
            }
            if provenance != .calibrated {
                // Discret : une mention, pas une alerte. L'EMBER reste au signal d'action.
                Text(provenance == .estimated ? "VMA ESTIMÉE" : "VMA NON CALIBRÉE")
                    .font(.label).tracking(1.5).foregroundStyle(Color.steelDim)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(percent) pour cent de VMA, \(PaceScale.label(paceSeconds)) par kilomètre")
    }

    // MARK: - Échelle défilante + curseur fixe

    private var wheel: some View {
        GeometryReader { geo in
            ZStack {
                ScrollView(.horizontal) {
                    HStack(spacing: Self.tickSpacing) {
                        ForEach(notches, id: \.self) { seconds in
                            tick(seconds).id(seconds)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)
                .scrollPosition(id: $centered, anchor: .center)
                .scrollIndicators(.hidden)
                // Marges = demi-largeur : les crans extrêmes peuvent atteindre le centre.
                .contentMargins(.horizontal, geo.size.width / 2, for: .scrollContent)

                cursor
            }
        }
        .frame(height: 64)
    }

    /// Le curseur ne bouge JAMAIS. Hairline EMBER — un signal, pas un aplat (règle n°2).
    private var cursor: some View {
        Rectangle()
            .fill(Color.ember)
            .frame(width: 2, height: 44)
            .allowsHitTesting(false)
    }

    /// Un cran. Teinté par sa zone (rampe thermique existante) ; les frontières de
    /// zone sont plus hautes — c'est ce qui situe l'effort d'un coup d'œil.
    private func tick(_ seconds: Int) -> some View {
        let zone = PaceScale.zone(paceSeconds: seconds, vma: vma)
        let isBoundary = boundaries.contains(seconds)
        return VStack(spacing: Spacing.xs) {
            Rectangle()
                .fill(zone?.color ?? Color.steelDim)
                .frame(width: isBoundary ? 2 : 1, height: isBoundary ? 32 : 20)
                .opacity(isBoundary ? 1 : 0.55)
            if isBoundary, let zone {
                Text(zone.rawValue)
                    .font(.label).tracking(1)
                    .foregroundStyle(zone.color)
            }
        }
        .frame(width: Self.tickSpacing, height: 52, alignment: .top)
        .accessibilityHidden(true)   // la valeur est annoncée par le readout
    }
}
