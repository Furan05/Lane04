# Resources/Fonts

Polices de marque (licence **OFL**), intégrées depuis les sources officielles.

| Fichier | Source | Axes | Usage |
|---|---|---|---|
| `Archivo-VariableFont.ttf` | [google/fonts · ofl/archivo](https://github.com/google/fonts/tree/main/ofl/archivo) | `wght` + `wdth` | Voix (titres, nav, boutons). **Expanded = `wdth` 125**. |
| `JetBrainsMono-VariableFont.ttf` | [JetBrains/JetBrainsMono v2.304](https://github.com/JetBrains/JetBrainsMono/releases) | `wght` | Donnée (métriques, chiffres tabulaires natifs). |

Licences : `OFL-Archivo.txt`, `OFL-JetBrainsMono.txt`.

## Intégration (faite)

- **Bundle** : les `.ttf` sont inclus automatiquement (groupe Xcode synchronisé) — pas d'entrée `.pbxproj` ni `UIAppFonts` nécessaire.
- **Registration** : `FontRegistrar.registerAll()` les enregistre au lancement (`CTFontManagerRegisterFontsForURL`, scope process).
- **Familles réelles** (log DEBUG `[LANE04]`) : `"Archivo"` et `"JetBrains Mono"`.
- **Pilotage des axes** : `Typography.swift` construit les `Font.*` via `UIFontDescriptor` (axes `wght`/`wdth`) puis `UIFontMetrics` (Dynamic Type). L'axe `wdth 125` donne l'Expanded sur display/title/button.
