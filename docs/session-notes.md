# Session Notes — handoff LANE 04

Décisions prises **en cours de route**, non écrites dans le case study, que la prochaine session doit connaître pour **ne pas les défaire**. Référence design = `docs/LANE_04_Case_Study.pdf` (v3). Avancement écrans = `docs/screens.md`.

---

## ✅ DÉCISION LOGS (tranchée) — option (b) maintenant, (a) en V2

**Le `RunLog` est une trace de transmission, pas une séance courue.** L'instrument ne ment jamais : on n'affiche que ce qu'on sait.
- **LOGS (V1)** = journal d'**injections** : `[SYNCED]` + nom du protocole + date/heure. **JAMAIS de km ni de chrono prétendus exécutés.** (Le `RunLog` porte `distanceMeters`/`durationSeconds` du protocole *prévu* — ne PAS les présenter comme courus ; s'en tenir au tag + nom + horodatage de transmission.)
- **Chantier V2 (a)** : lecture **HealthKit** des vraies séances exécutées (`HKWorkout` écrits par l'app Exercice après la course) pour afficher des km/chrono réels. Non fait en V1.

Empty state LOGS : « le zéro est une donnée » (`NO DATA LOGGED` en mono, pas une excuse).

---

## Décisions hors case study — NE PAS DÉFAIRE

### Injection — verrou de vérité (`bfa010e`)
- `FLASH` et `CONFIRM` ne se déclenchent **jamais** avant la résolution réelle de `InjectionService.schedule()`. Le faisceau monte à **90 %** puis **tient** (le `%` « respire » via une pulsation d'opacité, pas de gel) tant que la vérité n'est pas connue.
- Une erreur → **interruption immédiate au % courant** → `[SYNC FAULT]` + cause + `RETRY`.
- `PAYLOAD DELIVERED` = vérité, jamais promesse. C'est le contrat validé par l'operator ; toute « accélération optimiste » du flash est un régression.
- `WorkoutScheduler.schedule` est **non-throwing** dans le SDK ; la seule faute réellement remontée par l'API est l'**autorisation refusée**. Les « transfer interrupted » ne sont pas exposés par WorkoutKit — la sémantique de faute repose sur l'autorisation.

### Machine à états dans `RootView` (`bfa010e`)
- `InjectionController` (`@Observable`, `@MainActor`) est détenue par **`RootView`** et passée par `.environment`. Elle **survit à la disparition de l'éditeur** : le statut `[TX…]` vit dans le header (via `injection.status(for:)`), pas dans le bouton. Ne pas la redescendre dans la vue.
- La `Task` d'injection est lancée hors cycle de vie de la vue (pas de `.task`), donc non annulée si l'utilisateur quitte l'écran.
- Compteur d'injections réussies en `UserDefaults` (`SettingsKey.successfulInjections`) → bascule **RITUAL→FAST à la 10ᵉ**. `CONSOLE › TX MODE` force FAST ; Reduce Motion force FAST + fondu 120 ms **sans flash**.

### Builder WorkoutKit = territoire protégé (`70815a4`, porté ; consommé en `bfa010e`)
- `WorkoutBuilder.customWorkout(for:vma:)` produit un `CustomWorkout` (value type Sendable) capturé **avant** l'async. La chorégraphie **lit** ce résultat, ne le modifie jamais. Comportement identique à l'ancien `RunSession.customWorkout`. `SpeedRangeAlert` = `ClosedRange<Measurement<UnitSpeed>>` (pas `HKQuantity`, non `Comparable`).

### Rampe thermique curatée (`b1e2fdd`)
- 5 tokens `Color.zoneZ1…zoneZ5` dans `Theme.swift`, interpolés **par le neutre, jamais par le vert** (EMBER → ambre désaturé → acier chaud → cyan désaturé → CRYO). **Source unique** du spectre : `TrainingZone.color` et `Discipline.tint` lisent ces tokens. Ne pas réintroduire d'interpolation RGB linéaire (helper `Color.blended` supprimé volontairement).

### Nomenclature stricte + zones (`70815a4`, `738afa5`)
- 5 tags **et seulement eux** : `[VMA] [SEUIL] [TEMPO] [FARTLEK] [RECUP]`. **Aucune 6e catégorie sans accord explicite de l'operator.**
- Remap validé : recovery + endurance + sortie longue → `[RECUP]` ; threshold + race → `[SEUIL]` ; vo2max + côtes → `[VMA]` ; **footing progressif → `[TEMPO]`** (seule reclassif de type (c)).
- Templates **TEMPO/FARTLEK ajoutés** (TEMPO_20/30/2X15 @ Z3 ; FARTLEK_30_30/1_1/PYRAMIDE) → **30 templates**, les 5 tags peuplés.
- `TrainingZone` : %VMA centres Z1 62 / Z2 75 / Z3 84 / Z4 95 / Z5 105 + bandes, **calées sur le case study** (VMA 17.2 : Z5 ≤3:29 … Z1 ≥5:01).

### Produit : compiler avec templates (`70815a4`)
- Les 30 presets sont des **templates** (`isTemplate = true`, `state = .ready`), **jamais modifiés**. « COMPILE FROM TEMPLATE » → `Seeder.clone` → nouveau protocole `[DRAFT]` éditable. **Seed idempotent** (si base vide). `ensureOperatorProfile` garantit un profil unique.

### Persistance & archi (`387e2ff`)
- **SwiftData** : `RunProtocol` / `ProtocolBlock` / `ProtocolStep` / `OperatorProfile` / `RunLog`. Réglages CONSOLE simples en `@AppStorage`.
- **`OperatorProfile`** : nom correct (pas de « ProperatorProfile »). Modèle stabilisé **avant** données persistées — éviter migration.
- **Warmup/cooldown** = blocs à pas unique (rôle `.warmup`/`.cooldown`) ; le builder les route vers les slots `warmup`/`cooldown` du `CustomWorkout`. Ne pas ajouter de relations séparées.

### Typo & polices (`17d6a50`)
- Archivo variable (`wght`+`wdth`) + JetBrains Mono variable (OFL, sources officielles) dans `Lane04/Resources/Fonts/`. **Auto-bundlées** par le groupe Xcode synchronisé (pas de `pbxproj`, pas de `UIAppFonts`) ; enregistrées runtime par `FontRegistrar`.
- `Font.*` pilotent les axes via `UIFontDescriptor` (**Expanded = `wdth 125`**) + `UIFontMetrics` (Dynamic Type). Familles réelles : `"Archivo"`, `"JetBrains Mono"`.
- `Font.button` ajouté (7e style hors échelle des 6 — la « voix » appliquée aux boutons). `Color.laneWhite` (car `Color.white` = système) et enum `Surface` (car `Material` = SwiftUI) : renommages assumés.

### Métrique de charge — RETIRÉE en V1
- La métrique **CHARGE** (index durée × intensité) a été **retirée** du header éditeur : un instrument n'affiche pas un chiffre dont il ne peut pas expliquer la formule. Header = **DISTANCE + DURÉE** uniquement.
- **Candidate V2** : une vraie métrique de charge (TRIMP ou équivalent, **formule documentée**), à introduire seulement après usage réel sur device.

### Contrainte ferme
- **JAMAIS de cible watchOS** (principe fondateur). Seule exception future possible (V3, sur demande explicite) : complication QUAD. Voir mémoire projet `[[lane04-design-decisions]]`.

---

## Comment reprendre
1. Lire `CLAUDE.md` (règles absolues) + ce fichier + `docs/screens.md` (avancement).
2. Trancher la question LOGS ci-dessus **avant** la 3d.
3. Cadence : commit à la fin de chaque sous-phase, état des lieux avant la suivante, captures via `xcrun simctl` (le sim peut s'éteindre après `xcodebuild test` — `bootstatus` avant `install`).
