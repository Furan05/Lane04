# Screen Inventory & States — LANE 04

Extrait fidèle du case study **§08 Screen Inventory & States** et **§09 Product / UI Kit**.

## Grammaire commune (s'applique à TOUS les écrans)

- Statut **`[BRACKET]` en haut à droite**, sans exception.
- **Un seul aplat d'accent par écran** = l'action.
- Contour EMBER = action de **recours** (retry, settings). Pointillé = un **vide**. Hachure −54° = territoire **non compilé** (`[DRAFT]`).
- Dualité thermique EMBER/CRYO. **Extinction pendant l'effort.**
- Toute **faute nomme sa cause** et propose exactement **une** action.

## Navigation — Tab bar

Trois onglets : **`PROTOCOLS`** · **`LOGS`** · **`CONSOLE`**.
États de la tab bar : `ACTIVE`, `INACTIVE`, `ALERTE — FAULT`, `DISABLED — TX` (désactivée pendant une injection).

## Les 12 écrans

| # | Écran | États / notes |
|---|---|---|
| 01 | **ONBOARDING** | Trois écrans max : promesse (`COMPILE. INJECT. RUN.` / `INITIALIZE`), permission HealthKit, pairing. Zéro carrousel marketing. |
| 02 | **PAIRING WATCH** | `[SEARCHING]`. Le QUAD sert de jauge de liaison — deux barres = signal partiel. CTA `PAIR`. Cible `TARGET: WATCH ULTRA 2`. |
| 03 | **ACCUEIL / PROTOCOLS** | `[SYNCED]` / `[IDLE]`. Liste des protocoles, **tags thermiques** (`[VMA] 6×400M @ 3:45`, `[SEUIL] 3×2000M @ 4:10`, `[RECUP] 45:00 @ 6:00`). Compilation en un geste : `+ COMPILE`. |
| 04 | **EMPTY / AUCUN PROTOCOLE** | `NO PROTOCOL COMPILED` · `0 PAYLOADS`. Hachures −54°, invitation `COMPILE PROTOCOL`. **Jamais d'illustration consolante.** |
| 05 | **LOGS** | `[30D]` / `[IDLE]`. Données brutes en colonnes tabulaires (`[VMA] 12.4 KM 4:02`…). **Zéro graphe décoratif.** |
| 06 | **EMPTY / AUCUN LOG** | `0.0 KM` · `NO DATA LOGGED`. « Le zéro est une donnée : on l'affiche en mono, pas en excuse. » Texte : *Les données arrivent avec la première séance.* |
| 07 | **CONSOLE** (réglages) | `[V1.0]`. Paires clé/valeur : `TX MODE = RITUAL`, `UNITS = MIN/KM`, `HAPTICS = ON`, `TARGET = ULTRA 2`. **C'est ici que `TX MODE` se tranche** (RITUAL / FAST). |
| 08 | **OPERATOR** (profil) | `[CALIBRATED]`. Profil physiologique : `VMA 17.2` saisie, **zones dérivées** (Z5 ≤3:29, Z4 3:30–3:52, Z3 3:53–4:20, Z2 4:21–5:00, Z1 ≥5:01), spectre thermique. |
| 09 | **FAULT / MONTRE NON APPAIRÉE** | `[NO LINK]`. Hero **éteint** (jamais cliquable sans liaison), bannière contour `WATCH UNPAIRED — OPEN PAIRING`, cellules à 45 % d'opacité. |
| 10 | **FAULT / HEALTHKIT REFUSÉ** | `[ACCESS DENIED]`. `HEALTHKIT REQUIRED` — *L'écriture des séances est bloquée. Autorise LANE 04 dans Réglages.* CTA **contour** `OPEN SETTINGS` (l'action sort de l'app → l'aplat reste réservé à l'injection). |
| 11 | **FAULT / SYNC** | `[SYNC FAULT]`. Statut **clignotant 1.2 s**, cause en clair (`TRANSFER INTERRUPTED AT 64%`), action unique `RETRY INJECT`. Jamais de silence. |
| 12 | **SHEET / SÉLECTEUR D'ALLURE** | `[READY]`. Readout **DATA-XL** (`3:45/KM`), règle graduée, crans 5 s (`−5S` / `+5S`), zone en direct (`ZONE: VMA`), `COMMIT`. Fonctionnel en §09. |

## §09 — WorkoutBuilderView (écran-cœur) : anatomie

| Zone | Contenu |
|---|---|
| **A — Console header** | Lockup QUAD + nom du protocole en Archivo Expanded. À droite, le statut système vit en permanence : `[PAYLOAD READY]` → `[TX…]` → `[SYNCED]`. Le résumé (distance, durée estimée, charge) recalcule à chaque édition, en **mono tabulaire** — aucun chiffre ne bouge d'un pixel. |
| **B — Cartes d'intervalles** (dualité atomique) | Conteneurs Liquid Glass (white 4 % + blur 14, hairline, radius 14). **Effort = rail EMBER plein, fond teinté chaud, data en accent** ; **récupération = rail CRYO pointillé, fond nu, data acier.** Plein contre pointillé, chaud contre froid. |
| **C — Steppers & sélecteur d'allure** | Fini la roue iOS. Répétitions par stepper ±. Allure éditée dans une **sheet dédiée** (§12) : readout DATA-XL, règle graduée, crans 5 s haptique `.selection`, zone physiologique en direct. |
| **D — Hero button `INJECT PAYLOAD`** | Ancré sous un dégradé de voile noir, précédé de sa ligne de cible (`TARGET: WATCH — [PAIRED]`). Presse-le : compression, faisceau de transfert, pourcentage réel, bascule CRYO — chorégraphie §07. |

## Hero button — les 4 états (standard de tous les composants)

| État | Rendu |
|---|---|
| **DEFAULT** | Aplat EMBER — **la seule couleur pleine de l'écran**. Label `INJECT PAYLOAD`. |
| **PRESSED** | Scale 0.97 / 90 ms + haptique `.rigid`. |
| **INJECTING** | Label `INJECTING 64%`. Faisceau = **progression réelle WorkoutKit**. |
| **SUCCESS** | Bascule **CRYO** 240 ms + double haptique `.success`. Label `PAYLOAD DELIVERED`. |

### Chorégraphie INJECT PAYLOAD — timeline 0 → 2400 ms (mode RITUAL)

- **T+0 — ARM** : compression 0.97, haptique `.rigid`. Label → `INJECTING`. Le reste de l'écran chute à **40 % d'opacité**.
- **T+120 → 1800 — TRANSFER** : faisceau EMBER gauche→droite (progression réelle WorkoutKit), `%` en mono. Tick `.soft` toutes les 400 ms. Le QUAD pulse barre par barre (equalizer).
- **T+1800 — FLASH** : flash blanc 80 ms plein cadre (obturateur). Coupe franche, aucun fondu.
- **T+1900 → 2400 — CONFIRM** : bouton vire **CRYO** = `PAYLOAD DELIVERED`. Double haptique `.success`. Statut → `[SYNCED]`, écran remonte à 100 %, retour au repos en courbe maîtresse.

**Bornage.** `RITUAL` 2400 ms (injections 1–9) → auto `FAST` 900 ms dès la 10ᵉ (faisceau accéléré, un seul tick). Réglable `CONSOLE › TX MODE`. Reduce Motion force `FAST` en fondu sans flash. Le flash de réception n'est supprimé qu'en Reduce Motion.

## Matrice d'états des composants

- **Cellule de liste** : `DEFAULT`, `PRESSED 90 ms`, `[SYNCED]`, `[FAULT]`.
- **Stepper `−  6×  +`** : `DEFAULT`, `PRESSED + .sel`, `MIN ATTEINT` (1×), `DISABLED — TX`.
- **Tag de séance `[VMA]`** : `DEFAULT`, `SELECTED — filtre`, `DISABLED`, `DRAFT — pointillé`.
- **Sheet (sélecteur d'allure)** : `OPENING` (scène 320 ms + scrim blur 4), `CRAN ±5 S` (haptique `.selection`, zone en direct), `COMMIT PRESSED` (fill EMBER 12 %, 90 ms), `OUT OF RANGE` (readout EMBER + `[OUT OF RANGE]`, COMMIT reste actif — *l'athlète a toujours raison*, mais l'écart est nommé), `DISMISS` (tap scrim, retour 180 ms).

## Côté watchOS

LANE 04 disparaît volontairement : le protocole vit dans l'app native Exercice avec les métriques système. Empreinte limitée au strict signal — QUAD en complication, paire SF Pro / SF Mono, dualité EMBER/CRYO reprise par les anneaux d'intervalles.
