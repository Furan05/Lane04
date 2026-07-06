# Design Tokens — LANE 04

Extrait fidèle du case study **§04 Color System** et **§05 Typography → Design Tokens**. Colonne `SwiftUI` = nom du token attendu dans `Theme.swift`.

## Couleurs

### Fonds — l'écosystème sombre (hiérarchie par luminance)

| Token | Hex | Usage | SwiftUI |
|---|---|---|---|
| `color.void` | `#000000` | Canvas racine. Pixels OLED éteints = autonomie. | `Color.void` |
| `color.carbon1` | `#0B0D10` | Surface posée : cartes au repos, listes. | `Color.carbon1` |
| `color.carbon2` | `#14171C` | Surface levée : sheets, éléments actifs. | `Color.carbon2` |
| GLASS | white 5 % + blur 20 | Liquid Glass : conteneurs flottants, barres. | (matériau, voir plus bas) |
| HAIRLINE | white 8–10 %, 1 px | **La seule séparation autorisée.** | `Material.hairline` |

> Jamais de gris moyen, jamais d'ombre portée diffuse. La profondeur se construit par paliers de luminance + hairlines.

### Accents & texte

| Token | Hex | Usage | SwiftUI |
|---|---|---|---|
| `color.ember` | `#FF4D00` | **Effort, action primaire, allure dépassée, alerte.** Signal, jamais décor (règle des 10 %). | `Color.ember` |
| `color.cryo` | `#00E5FF` | **Récupération, allure conforme, sync OK, confirmations.** | `Color.cryo` |
| `color.white` | `#F2F4F5` | Data neutre, texte primaire. | `Color.white` (custom) |
| `color.steel` | `#99A1AB` | Texte secondaire. | `Color.steel` |
| `color.steelHi` | `#7A828C` | **Labels porteurs d'info** (STEEL-DIM échoue AA → tout label informatif passe ici). | `Color.steelHi` |
| `color.steelDim` | `#565E68` | **Décoratif uniquement** (échoue AA à 3.2:1). | `Color.steelDim` |

### Contrastes sur VOID `#000000` (audit accessibilité)

| Couleur | Ratio | Verdict |
|---|---|---|
| WHITE `#F2F4F5` | 19.0:1 | AAA |
| CRYO `#00E5FF` | 13.7:1 | AAA |
| STEEL `#99A1AB` | 8.0:1 | AA |
| STEEL-HI `#7A828C` | 5.4:1 | AA (labels info) |
| EMBER `#FF4D00` | 6.3:1 | AA |
| STEEL-DIM `#565E68` | 3.2:1 | ❌ ÉCHEC AA → décoratif strict |

## Espacement — base 4 pt

| Token | Valeur | Usage | SwiftUI |
|---|---|---|---|
| `space.xs` | 4 pt | gap icône/label | `Spacing.xs` |
| `space.s` | 8 pt | gouttière entre cartes | `Spacing.s` |
| `space.m` | 12 pt | padding interne compact | `Spacing.m` |
| `space.l` | 16 pt | marge écran, padding cartes | `Spacing.l` |
| `space.xl` | 24 pt | padding sheets | `Spacing.xl` |
| `space.2xl` / `space.3xl` | 32 / 48 pt | respiration inter-groupes, éditorial | `Spacing.xxl` / `.xxxl` |

## Rayons

| Token | Valeur | Usage | SwiftUI |
|---|---|---|---|
| `radius.badge` | **0** | tags et statuts : **jamais arrondis** | `Radius.badge` |
| `radius.control` | 8 | steppers, inputs, mini-boutons | `Radius.control` |
| `radius.card` | 14 | cartes d'intervalles, cellules de liste | `Radius.card` |
| `radius.button` | 16 | hero button | `Radius.button` |
| `radius.sheet` | 24 | sheets, coins hauts seulement | `Radius.sheet` |

## Grille iPhone

| Token | Valeur | Usage | SwiftUI |
|---|---|---|---|
| `grid.margin` | 16 pt | bord d'écran | `Grid.margin` |
| `grid.gutter` | 8 pt | entre cartes empilées | `Grid.gutter` |
| `grid.safe.top` / `.bottom` | 76 / 42 pt | sous Dynamic Island / au-dessus home indicator | `Grid.safeTop` / `.safeBottom` |
| `touch.min` | **44 × 44 pt** | cible tactile minimale, **sans exception** | `Touch.min` |

## Matériaux — Liquid Glass

| Token | Valeur | Usage | SwiftUI |
|---|---|---|---|
| `blur.scrim` / `.glass` / `.nav` | 4 / 14 / 20 | voile sheets / cartes / barres | `Material.scrim` / `.glass` / `.nav` |
| `fill.glass` / `hairline` | white 4 % / white 8 %, 1 px | remplissage verre / seule séparation autorisée | `Material.glassFill` / `.hairline` |

## Typographie

**Stack.** Archivo Expanded (voix : titres, navigation, boutons) + JetBrains Mono (donnée). Sur **watchOS** : bascule sur SF Pro / SF Mono — même logique, zéro coût.

### Échelle typographique (6 styles nommés)

| Style | Taille | Exemple | Police / réglage | SwiftUI |
|---|---|---|---|---|
| DISPLAY | 64 | `SEUIL 10K` | Archivo Exp 900 / -1 % | `Font.display` |
| TITLE | 28 | `NOUVEAU PROTOCOLE` | Archivo Exp 800 | `Font.title` |
| BODY | 16 | texte de lecture | Archivo 400 / 1.5 | `Font.body` |
| DATA-XL | 56 | `3:45/KM` | JB Mono 500 / **tabular** | `Font.dataXL` |
| DATA | 20 | `12.4 KM — 58:12` | JB Mono 400 / **tabular** | `Font.data` |
| LABEL | 11 | `PAYLOAD READY — TARGET: WATCH ULTRA 2` | JB Mono 400 / +14 % / CAPS | `Font.label` |

> **Règle absolue — data display.** Toute valeur métrique (chrono, allure, distance, répétition, FC) est composée en chasse fixe, **chiffres tabulaires**, sans exception.

### Dynamic Type
Archivo est une variable font mappée sur `UIFontMetrics`, jusqu'aux tailles d'accessibilité. Au-delà de **AX1**, les rangées de data quittent l'alignement tabulaire horizontal pour un empilement vertical (chiffre d'abord, label dessous) et le hero button monte à 64 pt. Rien ne tronque, tout reflow. Les valeurs mono conservent leurs chiffres tabulaires à toutes les tailles.

## Motion

| Token | Valeur | SwiftUI |
|---|---|---|
| `motion.master` | `cubic-bezier(0.16, 1, 0.3, 1)` — **l'unique courbe** | `Animation.master` |
| `duration.micro` | 90 ms (press, toggle) | `Duration.micro` |
| `duration.standard` | 180 ms (cartes, sheets) | `Duration.standard` |
| `duration.scene` | 320 ms (navigation) | `Duration.scene` |
| PROPRIÉTÉS ANIMÉES | **`opacity` + `transform` uniquement** | — |
| REDUCE MOTION | fondu 120 ms, **zéro translation** | — |

Décélération brutale, **jamais de rebond**. Parallaxe limitée à 4 px. Chorégraphie `INJECT PAYLOAD` : `RITUAL` 2400 ms (injections 1–9) / `FAST` 900 ms (auto dès la 10ᵉ) — voir `screens.md`.

## Haptique

| Token | Type | SwiftUI |
|---|---|---|
| `haptic.arm` | `.rigid` | `Haptic.arm` |
| `haptic.tick` | `.soft` | `Haptic.tick` |
| `haptic.done` | `.success` | `Haptic.done` |
| (sélecteur d'allure) | `.selection` (cran ±5 s) | `Haptic.selection` |
