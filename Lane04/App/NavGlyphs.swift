//
//  NavGlyphs.swift
//  Lane04
//
//  Glyphes de navigation de la bottom bar — grammaire §06 : grille 24×24,
//  trait 1.5 pt **constant**, **contour seul** (jamais de fill), butt caps,
//  angles vifs (miter, radius 0), géométrie primitive (carré, ligne, diagonale).
//  Dessinés en Path — JAMAIS de SF Symbols.
//
//  Révision de direction (voir docs/session-notes.md) : la nav passe du TEXTE
//  aux PICTOGRAMMES. « Le mot est le symbole » (§06) reste la règle des STATUTS,
//  pas de la navigation.
//

import SwiftUI

enum NavGlyph {
    /// Grille de dessin (et taille de rendu par défaut).
    static let grid: CGFloat = 24
    /// Trait unique : 1.5 pt, butt caps, joints vifs (radius 0).
    static let stroke = StrokeStyle(lineWidth: 1.5, lineCap: .butt, lineJoin: .miter)
}

/// Projette une coordonnée de la grille 24×24 dans `rect` (le glyphe suit la
/// taille de son cadre tout en gardant sa géométrie primitive).
private func gp(_ x: CGFloat, _ y: CGFloat, in rect: CGRect) -> CGPoint {
    CGPoint(x: rect.minX + x / NavGlyph.grid * rect.width,
            y: rect.minY + y / NavGlyph.grid * rect.height)
}

// MARK: - PROTOCOLS — piles/couches : 3 rectangles horizontaux empilés (la liste).

struct ProtocolsGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        for top in [CGFloat(3), 10, 17] {          // 3 barres, gaps réguliers
            path.move(to: gp(3, top, in: rect))
            path.addLine(to: gp(21, top, in: rect))
            path.addLine(to: gp(21, top + 4, in: rect))
            path.addLine(to: gp(3, top + 4, in: rect))
            path.closeSubpath()
        }
        return path
    }
}

// MARK: - LOGS — une trace : document au coin coupé + entrées décroissantes.

struct LogsGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        // Contour du document, coin supérieur droit coupé.
        path.move(to: gp(4, 3, in: rect))
        path.addLine(to: gp(16, 3, in: rect))
        path.addLine(to: gp(20, 7, in: rect))
        path.addLine(to: gp(20, 21, in: rect))
        path.addLine(to: gp(4, 21, in: rect))
        path.closeSubpath()
        // Pli du coin coupé.
        path.move(to: gp(16, 3, in: rect))
        path.addLine(to: gp(16, 7, in: rect))
        path.addLine(to: gp(20, 7, in: rect))
        // Entrées de journal — longueurs décroissantes.
        path.move(to: gp(7, 11, in: rect)); path.addLine(to: gp(17, 11, in: rect))
        path.move(to: gp(7, 14, in: rect)); path.addLine(to: gp(15, 14, in: rect))
        path.move(to: gp(7, 17, in: rect)); path.addLine(to: gp(12, 17, in: rect))
        return path
    }
}

// MARK: - CONSOLE — le prompt terminal : chevron `>` + underscore `_`.

struct ConsoleGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        // Chevron >
        path.move(to: gp(5, 7, in: rect))
        path.addLine(to: gp(11, 12, in: rect))
        path.addLine(to: gp(5, 17, in: rect))
        // Underscore _
        path.move(to: gp(13, 17, in: rect))
        path.addLine(to: gp(19, 17, in: rect))
        return path
    }
}

// MARK: - Vue de glyphe (contour seul, taille grille)

/// Rend le glyphe d'un onglet en contour seul. La couleur (état) est appliquée
/// par l'appelant via `.foregroundStyle`.
struct NavGlyphView: View {
    let tab: Tab
    var size: CGFloat = NavGlyph.grid

    var body: some View {
        shape
            .stroke(style: NavGlyph.stroke)
            .frame(width: size, height: size)
    }

    private var shape: AnyShape {
        switch tab {
        case .protocols: AnyShape(ProtocolsGlyph())
        case .logs:      AnyShape(LogsGlyph())
        case .console:   AnyShape(ConsoleGlyph())
        }
    }
}

// MARK: - Preview capture (DEBUG) — validation des 3 glyphes avant câblage.

#if DEBUG
/// Galerie de validation : les 3 glyphes en grand, puis une maquette de barre
/// montrant les 4 états (ACTIVE + indicateur, INACTIVE, FAULT ember, TX 40 %).
struct NavGlyphPreview: View {
    var body: some View {
        ZStack {
            Color.void.ignoresSafeArea()
            VStack(alignment: .leading, spacing: Spacing.xxl) {
                Text("NAV GLYPHS — §06")
                    .font(.label).tracking(1.5).foregroundStyle(Color.steelHi)

                // Grands glyphes (48 pt) — lecture de la géométrie.
                HStack(spacing: Spacing.xxl) {
                    ForEach(Tab.allCases) { tab in
                        VStack(spacing: Spacing.m) {
                            NavGlyphView(tab: tab, size: 48)
                                .foregroundStyle(Color.laneWhite)
                            Text(tab.rawValue)
                                .font(.label).tracking(1.5)
                                .foregroundStyle(Color.steel)
                        }
                    }
                }

                Text("ÉTATS — TAILLE BARRE (24 pt)")
                    .font(.label).tracking(1.5).foregroundStyle(Color.steelHi)

                // Maquette de barre : ACTIVE / INACTIVE / FAULT.
                mockBar(active: .protocols, fault: .console, tx: false)
                // Même barre, désactivée pendant TX (40 %).
                mockBar(active: .protocols, fault: .console, tx: true)
            }
            .padding(Spacing.xl)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .preferredColorScheme(.dark)
    }

    private func mockBar(active: Tab, fault: Tab, tx: Bool) -> some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases) { tab in
                let isActive = tab == active
                let isFault = tab == fault
                let tint: Color = isFault ? .ember : (isActive ? .laneWhite : .steel)
                VStack(spacing: 0) {
                    NavGlyphView(tab: tab)
                        .foregroundStyle(tint)
                        .overlay(alignment: .bottom) {
                            Rectangle().fill(Color.laneWhite)
                                .frame(height: 2).offset(y: 7)
                                .opacity(isActive ? 1 : 0)
                        }
                }
                .frame(maxWidth: .infinity, minHeight: Touch.min)
            }
        }
        .padding(.vertical, Spacing.m)
        .background {
            Rectangle().fill(.ultraThinMaterial)
                .overlay(alignment: .top) { Rectangle().fill(Surface.hairline).frame(height: 1) }
        }
        .opacity(tx ? 0.4 : 1)
    }
}

#Preview { NavGlyphPreview() }
#endif
