//
//  AppRouter.swift
//  Lane04
//
//  Navigation partagée hors hiérarchie de vue. Permet à un écran d'un onglet
//  (ex. OPERATOR sous CONSOLE) de router vers l'éditeur de PROTOCOLS **par le
//  chemin nominal** — un seul éditeur, aucun flux parallèle.
//

import SwiftUI

@MainActor
@Observable
final class AppRouter {
    /// Onglet affiché (détenu ici pour être pilotable depuis n'importe où).
    var tab: Tab = .protocols
    /// Pile de navigation de PROTOCOLS (l'éditeur y est poussé).
    var protocolsPath: [RunProtocol] = []

    /// Ouvre l'éditeur d'un protocole : bascule sur PROTOCOLS et pousse l'éditeur.
    /// Réutilise le `navigationDestination` existant — pas de second éditeur.
    func openEditor(_ proto: RunProtocol) {
        tab = .protocols
        protocolsPath = [proto]
    }
}
