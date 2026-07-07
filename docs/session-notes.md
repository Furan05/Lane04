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

### Actions de cellule PROTOCOLS (`0e7d8c3`)
- **DELETE** (swipe leading + trailing) = aplat **EMBER** (destructif = signal chaud). Confirmation par alerte **uniquement si `[SYNCED]`** (vit peut-être sur la montre) ; un `[DRAFT]` se supprime sans confirmation.
- **DUPLICATE** = tint **neutre `carbon2`**, PAS l'ember — choix assumé : `swipeActions` SwiftUI ne fait que des boutons pleins, donc « contour » = interprété comme « ne dépense pas l'accent ». Ne pas le repasser en ember (ce serait deux aplats d'accent). Clone → `[DRAFT] NOM_COPY`.
- **Templates non supprimables** : aucune action de suppression dans la bibliothèque — le catalogue est le socle.
- `ProtocolActions.delete` **ne touche jamais les `RunLog`** (pas de relation ; la trace survit). Logique hors UI dans `Data/ProtocolActions.swift`, couverte par `ProtocolActionsTests`.

### Calibration VMA — MESURE vs ESTIMATION (feature VMA)
- **`OperatorProfile.provenance`** (`VMAProvenance` : `.calibrated` / `.estimated` / `.uncalibrated`) : l'instrument distingue la mesure de l'estimation. Statut OPERATOR/[BRACKET] : `[CALIBRATED — dd.MM]` (aplat cyan, confirmé) / `[ESTIMATED]` / `[UNCALIBRATED]`.
- **Défaut 14.0 `[UNCALIBRATED]`** (était 16.0). Coureur médian, jamais flatteur — un défaut haut fausserait la première lecture des zones. `Seeder.ensureOperatorProfile` insère sans argument (14.0/uncalibrated).
- **Deux voies, jamais deux aplats** : `CalibrationVoiePicker` (dans `App/CalibrationInputs.swift`) est un sélecteur MESURE/ESTIMATION **mutuellement exclusif** — un seul picker, donc un seul `PrimaryActionButton` EMBER visible à la fois (règle absolue n°1). Réutilisé par OPERATOR **et** l'onboarding.
  - **MESURE** = demi-Cooper : `VMACalculator.vmaFromHalfCooper(meters:)` = `distance / 100`. Formule affichée dans l'UI (« VMA = 1720 / 100 »). Crans 10 m. → `.calibrated`.
  - **ESTIMATION** = `VMAEstimator` : coefficient (% VMA tenu) par **paliers secs sur le chrono** (pas d'interpolation — l'UI montre le coeff discret réellement utilisé). Barème 5K/10K/SEMI, source consensus coaching FR. `VMA = vitesse / coeff`. → `.estimated`.

### Onboarding — DÉROGATION aux « 3 écrans max » (feature VMA)
- Le case study §01 dit **3 écrans max**. On passe à **4** : `promesse → CALIBRATION → HealthKit → pairing`. **Dérogation assumée** : la CALIBRATION est en **2e position** mais **skippable en un tap** (« TESTER PLUS TARD » en **contour**, pas un aplat), défaut 14.0 `[UNCALIBRATED]`. Le parcours minimal reste 3 taps — l'écran calibration n'impose rien. Ne pas le repasser à 3 écrans sans reconsidérer l'accès à la VMA dès l'onboarding.

### TEST_VMA — 31e template (feature VMA)
- **31 templates** (était 30) : ajout de `TEST_VMA` (`[VMA]`, `isTest = true` → badge `[TEST]`). Structure : warmup 15 + « EFFORT MAXIMAL · 6 MIN » (durée seule) + cooldown 10.
- **Amendement builder** : l'effort de test porte `targetsPace = false` → **aucun `SpeedRangeAlert`** injecté sur le pas d'effort (`WorkoutBuilder.speedAlert` renvoie `nil`). La montre ne dira jamais « trop vite » pendant un test maximal. Couvert par `testVMA_effortHasNoSpeedRangeAlert`.
- `RunProtocol.isTest` : booléen porté du template au clone (`Seeder.clone`) ; badge `[TEST]` en cellule PROTOCOLS et en ligne de bibliothèque.

### Pont CALIBRATION → TEST_VMA (raccourci MESURE)
- **Friction résolue** : la voie MESURE demande la distance du test 6:00 sans offrir de chemin vers le test. Ajout d'une **ligne de recours EN CONTOUR** sous VALIDATE : « PAS ENCORE TESTÉ ? → INJECT TEST_VMA » (`OutlineActionButton`, jamais un aplat — l'aplat de l'écran reste sur VALIDATE). Présente en **OPERATOR et onboarding**. VoiceOver : « Préparer le protocole de test VMA ».
- **`ProtocolActions.prepareTestVMA(in:)`** : **idempotent**. Réutilise un `TEST_VMA` non-template déjà cloné ([DRAFT] ou [SYNCED], le plus récent) s'il existe — sinon clone le template via `Seeder.clone`. **Pas d'accumulation de tests fantômes.** Aucune logique d'injection nouvelle.
- **Chemin nominal, pas de flux parallèle** : le tap ouvre l'**éditeur** du test (hero INJECT PAYLOAD existant fait le reste).
  - **OPERATOR** : `AppRouter` (`@Observable`, dans `App/AppRouter.swift`) détenu par `RootView`, porte `tab` + `protocolsPath`. `openEditor(_:)` bascule sur PROTOCOLS et pousse l'éditeur dans **le** `navigationDestination` existant. `RootView` pilote l'onglet via `router.tab` ; `ProtocolsScreen` lie sa `NavigationStack(path:)` à `router.protocolsPath`. **Ne pas** réintroduire un `@State tab` local dans RootView ni un second éditeur.
  - **Onboarding** : **option (b) choisie** (la moins fragile) — le tap clone TEST_VMA **en silence** (idempotent) et **poursuit l'onboarding** (HealthKit + pairing restent requis pour injecter). Pas de note transitoire inter-écrans (état fragile) : l'utilisateur retrouve TEST_VMA `[DRAFT]` dans PROTOCOLS, repérable au badge `[TEST]`. Ne PAS faire sauter l'onboarding vers l'éditeur (on ne peut pas injecter sans liaison).
- **Seam de test UI** : `Lane04App` honore `-uitest-skip-onboarding` / `-uitest-force-onboarding` (écrit `hasOnboarded`). Couvert par `Lane04UITests/CalibrationShortcutUITests` (raccourci → éditeur ; recours présent onboarding). Idempotence/clone en unitaire (`ProtocolActionsTests`).

### Bottom bar custom LANE 04 (remplace la TabView native)
- **`TabBar` dans `RootView.swift`** : dernier composant hors design system remplacé. **Texte seul, aucune icône** (« le mot est le symbole », §06) — PROTOCOLS / LOGS / CONSOLE en `Font.label`. Matériau Liquid Glass (`.ultraThinMaterial` ≈ `Surface.navBlur`) sur VOID, débordant sous l'home indicator (`.ignoresSafeArea(.bottom)` + `Grid.safeBottom`), hairline supérieure comme seule séparation.
- **États (§09)** : ACTIVE = mot **blanc** + **micro-barre indicatrice** 2 pt sous le mot (blanche, clin d'œil QUAD — **jamais EMBER**, l'aplat reste au hero) ; INACTIVE = `steel` ; **FAULT** = le mot **CONSOLE** passe en **EMBER texte** (signal, pas d'aplat) quand `LinkController.hasFault` (NO LINK / ACCESS DENIED) — l'indicateur reste blanc ; **DISABLED-TX** = barre entière à **40 %** + `allowsHitTesting(false)` quand `InjectionController.isTransmitting` (cohérent avec l'écran à 40 % pendant ARM).
- **Transition** : bascule d'onglet en `Duration.micro` (90 ms), courbe maîtresse, opacity+transform only. **Reduce Motion** → fondu simple `Duration.reduceMotion`, zéro scale sur l'indicateur.
- **Accessibilité** : `accessibilityIdentifier` = le mot brut (tests + parité ancienne TabView) ; `accessibilityLabel` **FR** (« Protocoles / Journal / Console ») ; trait `.isSelected` sur l'actif ; conteneur `.isTabBar`. La perte de la TabView native ne coûte rien à VoiceOver.
- **Seam de test UI `-uitest-simulate-tx`** (DEBUG, `Lane04App` non — porté par `RootView.task` + `InjectionController.simulateTransmittingForUITest()`) : fige la barre en état TX sans injection réelle (le hero est éteint sans montre pairée en simulateur). Couvre `TabBarUITests.testBarDisabledDuringTransmission`. ⚠️ XCUITest `isHittable` **ne respecte pas** `allowsHitTesting(false)` → le test vérifie l'**absence de navigation** au tap, pas `isHittable`.
- Tests : `Lane04UITests/TabBarUITests` (navigation 3 onglets, état sélectionné, raccourci OPERATOR intact, barre désactivée pendant TX). Raccourci OPERATOR toujours couvert par `CalibrationShortcutUITests`.

### Contrainte ferme
- **JAMAIS de cible watchOS** (principe fondateur). Seule exception future possible (V3, sur demande explicite) : complication QUAD. Voir mémoire projet `[[lane04-design-decisions]]`.

---

## Comment reprendre
1. Lire `CLAUDE.md` (règles absolues) + ce fichier + `docs/screens.md` (avancement).
2. Trancher la question LOGS ci-dessus **avant** la 3d.
3. Cadence : commit à la fin de chaque sous-phase, état des lieux avant la suivante, captures via `xcrun simctl` (le sim peut s'éteindre après `xcodebuild test` — `bootstatus` avant `install`).
