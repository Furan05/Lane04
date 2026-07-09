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

> **⚠️ REVIREMENT DE DIRECTION (operator) — pictogrammes seuls, PAS de texte.**
> La nav est passée de **texte seul** à **pictogrammes seuls** (style Instagram : épuré, glyphes centrés). **« Le mot est le symbole » (§06) reste la règle des STATUTS `[BRACKET]`, JAMAIS de la navigation.** Ne PAS ré-appliquer « texte seul » à la tab bar. Décision explicite de l'operator, non négociable sans nouvel accord.

- **`TabBar` dans `RootView.swift`** : dernier composant hors design system remplacé. **Pictogrammes seuls, aucun texte visible** — glyphes custom `NavGlyphView` (fichier `App/NavGlyphs.swift`). Matériau Liquid Glass (`.ultraThinMaterial` ≈ `Surface.navBlur`) sur VOID, débordant sous l'home indicator (`.ignoresSafeArea(.bottom)` + `Grid.safeBottom`), hairline supérieure comme seule séparation.
- **Glyphes custom (`App/NavGlyphs.swift`)** — grammaire §06 : grille 24×24, trait **1.5 pt constant**, **contour seul** (jamais de fill), butt caps, joints vifs (miter, radius 0), géométrie primitive, dessinés en `Path` (**jamais de SF Symbols**). PROTOCOLS = 3 rectangles horizontaux empilés (la liste) ; LOGS = document au coin coupé + entrées décroissantes ; CONSOLE = chevron `>` + underscore `_` (prompt terminal). Seam de galerie DEBUG `-uitest-glyph-preview` (dans `Lane04App`) pour re-capturer/itérer les glyphes.
- **États (§09)** : ACTIVE = trait **blanc** + **micro-barre indicatrice** 2 pt sous le glyphe (blanche, clin d'œil QUAD — **jamais EMBER**, l'aplat reste au hero) ; INACTIVE = `steel` ; **FAULT** = le glyphe **CONSOLE** passe en **trait EMBER** (signal, pas d'aplat) quand `LinkController.hasFault` (NO LINK / ACCESS DENIED) — l'indicateur reste blanc ; **DISABLED-TX** = barre entière à **40 %** + `allowsHitTesting(false)` quand `InjectionController.isTransmitting` (cohérent avec l'écran à 40 % pendant ARM).
- **Transition** : bascule d'onglet en `Duration.micro` (90 ms), courbe maîtresse, opacity+transform only. **Reduce Motion** → fondu simple `Duration.reduceMotion`, zéro scale sur l'indicateur.
- **Accessibilité (CRITIQUE — plus aucun texte visible)** : `accessibilityIdentifier` = le mot brut (tests + parité ancienne TabView) ; `accessibilityLabel` **FR** (« Protocoles / Journal / Console ») **porte seul le sens pour VoiceOver** ; trait `.isSelected` sur l'actif ; conteneur `.isTabBar`. La perte de la TabView native ne coûte rien à VoiceOver.
- **Seam de test UI `-uitest-simulate-tx`** (DEBUG, `Lane04App` non — porté par `RootView.task` + `InjectionController.simulateTransmittingForUITest()`) : fige la barre en état TX sans injection réelle (le hero est éteint sans montre pairée en simulateur). Couvre `TabBarUITests.testBarDisabledDuringTransmission`. ⚠️ XCUITest `isHittable` **ne respecte pas** `allowsHitTesting(false)` → le test vérifie l'**absence de navigation** au tap, pas `isHittable`.
- Tests : `Lane04UITests/TabBarUITests` (navigation 3 onglets, état sélectionné, raccourci OPERATOR intact, barre désactivée pendant TX). Raccourci OPERATOR toujours couvert par `CalibrationShortcutUITests`.

### Builder manuel — création « from scratch » (comme Nolio)
- **Décision operator** : en plus de `COMPILE FROM TEMPLATE`, on peut **construire un protocole vierge bloc-par-bloc**. Le modèle SwiftData supportait déjà des protocoles arbitraires (blocs→pas, rôles, objectif durée/distance, %VMA, itérations, ordre) — le chantier était **100 % UI**. Cela rapproche l'app de la vision « compilateur » du case study (voir tension #1 de `data-model.md`), le sélecteur de presets devient un vrai éditeur.
- **Point d'entrée (écran PROTOCOLS)** : `OutlineActionButton "NEW FROM SCRATCH"` **en contour**, sous l'aplat EMBER `COMPILE FROM TEMPLATE`. Deux boutons, **un seul aplat** (règle n°1) — la création vierge ne dépense pas l'accent (même grammaire que le recours TEST_VMA). Route par le **chemin nominal** (`router.openEditor` → éditeur), aucun flux parallèle.
- **`ProtocolActions` (off-UI, testable)** — toute la logique de structure y vit : `createBlank` (scaffold WARM-UP 15′ + 1 bloc d'effort + COOL-DOWN 10′, `[DRAFT]`, tag `.vma` par défaut), `addWorkBlock` (**insère avant le COOL-DOWN**), `deleteBlock` (garde ≥1 bloc), `moveBlock(by:)` (échange d'ordre, no-op aux extrémités), `addStep`/`deleteStep` (garde **≥1 pas** par bloc). **Ordres toujours renumérotés contigus 0…n** (comme le catalogue). Couvert par `ProtocolActionsTests` (create/add/del/reorder blocs + pas).
- **`ProtocolEditorView` = le builder** : les affordances n'apparaissent **que pour un `[DRAFT]`** (`proto.state == .draft`) — un `[SYNCED]` reste en lecture. Ajouts : nom éditable (`TextField` mono expandé), tag éditable (`Menu` des **5 filières**, jamais de 6e), `⋯` par bloc d'effort (MONTER/DESCENDRE/SUPPRIMER), stepper reps (existant), `+ EFFORT`(ember)/`+ RÉCUP`(cyan) — **signaux thermiques en TEXTE contour, jamais un aplat**, objectif de chaque pas éditable via `StepGoalSheet`, allure d'effort via `PaceSheet` (existant), `×` supprime un pas, `+ AJOUTER UN BLOC` en contour sous les blocs.
- **`StepGoalSheet` (`App/StepGoalSheet.swift`)** : édite l'objectif d'un pas — sélecteur neutre **DURÉE/DISTANCE** (mutuellement exclusif → un seul aplat COMMIT), readout DATA-XL, crans adaptés (±15 S/±1 MIN ou ±100 M/±1 KM). Bornes 5 s…60 min / 50 m…20 km. `Format.goalTime`/`goalDistance` ajoutés.
- **Wrappers WARM-UP/COOL-DOWN** : présents par défaut, **objectif (durée) éditable**, mais **pas de menu ni de reps ni suppression** en V1 (ce sont les extrémités structurelles). Le rôle des pas n'est pas « changé » après coup : on choisit à l'ajout (`+ EFFORT`/`+ RÉCUP`), la dualité effort/récup reste nette. *Non fait V1 (si besoin plus tard) : réordonner/supprimer les wrappers, insérer un pas à une position précise, éditer l'allure de récup.*
- **⚠️ Dim retiré pour les `[DRAFT]`** : l'écran 09 dimme les cellules à 45 % sans liaison, MAIS un draft **se construit hors ligne** → `.opacity(link.isReady || isDraft ? 1 : 0.45)`. La faute de liaison reste portée par le **hero** (fault card), pas par le contenu éditable. Ne pas re-dimmer les drafts.
- Tests : `Lane04UITests/BuilderUITests` (NEW FROM SCRATCH → éditeur → ajout de bloc, capture `BUILDER_FROM_SCRATCH`).

### Bibliothèque de templates — navigation par DOSSIERS de style (décision operator)
- **`COMPILE FROM TEMPLATE` n'ouvre plus une liste à plat** mais une **navigation à deux niveaux** dans la sheet (`NavigationStack`) : **niveau 1 = 5 dossiers de style** (une carte `StyleFolderCard` par filière peuplée), **niveau 2 = les templates de la filière choisie** (`TemplateFolderView`, réutilise `TemplateRow`). On choisit un style avant de voir ses séances.
- **Carte-dossier** : `TagBadge` (contour **teinté thermique** — l'identité du dossier, VMA ember → RECUP cyan sur la rampe curatée) + **sous-titre FR** (`Discipline.subtitle`, langue de lecture §02) + **compte** + chevron. **Aucun aplat** (l'accent EMBER reste au hero PROTOCOLS, règle n°1). Le dégradé thermique des 5 dossiers est un bonus de lisibilité on-brand.
- **`Discipline.subtitle`** ajouté (Models.swift, computed — pas de migration) : VMA « Vitesse maximale aérobie », SEUIL « Allure seuil », TEMPO « Endurance active », FARTLEK « Jeu d'allures », RECUP « Récupération ».
- **Fermeture** : le pick d'un template appelle `onPick` qui **clone + ferme la sheet** (`showingLibrary = false` dans `ProtocolsScreen`) — fonctionne même depuis un dossier poussé (ne dépend plus du `dismiss` interne de la sheet). Le `<` du niveau 2 fait un simple pop nav ; le `×` du niveau 1 ferme la sheet.
- Ordre des dossiers = ordre thermique de l'enum `Discipline` (EMBER→CRYO). Dossiers vides masqués (tous peuplés en V1 : 11/8/4/3/5 = 31 templates).
- Tests : `Lane04UITests/TemplateFoldersUITests` (dossiers → détail → compile ferme la sheet ; captures `TEMPLATE_FOLDERS` / `TEMPLATE_FOLDER_DETAIL`).

### CALENDAR — planification des séances (feature majeure, décision operator)

> **Insight décisif** : `WorkoutScheduler.schedule(_:at:)` planifie nativement une séance pour **n'importe quelle date future** (elle apparaît seule dans l'app Exercice le jour prévu). `InjectionService.schedule` le faisait déjà mais avec `at` **codé en dur à now+60s**. Donc **planifier = programmer la transmission réelle à l'avance**, natif, sans serveur. Fidèle à « l'instrument ne ment jamais ».

- **Modèle** — nouvelle entité `PlannedSession { date, state, → RunProtocol }` (occurrence datée référençant un protocole ; le même protocole peut être planifié plusieurs jours). Relation `RunProtocol.plans` **cascade** (supprimer un protocole retire ses plans — couvert par `deletingProtocol_cascadesToPlans`). Ajoutée à `LaneSchema` + aux 2 `modelContainer` en dur (`Lane04App`, preview `RootView`). **Schéma dev, pas de migration.**
- **États `PlannedState`** (verrou de vérité) : `PLANNED` = prévu dans l'app (offline) ; `SCHEDULED` = **réellement sur la montre** pour sa date ; `SCHEDULE FAULT`. Badge `PlannedStateBadge` (steel / cyan / ember).
- **Injection généralisée** : `InjectionService.schedule(_ workout, at date: Date = now+60s)`. L'injection immédiate (éditeur) garde son défaut ; le calendrier passe la date du plan. **Pas de RunLog** sur un COMMIT planifié (LOGS reste la trace des injections immédiates).
- **Modèle « planifier puis injecter »** (choix operator) : on construit sa semaine **offline** (PLANNED, sans montre) ; `COMMIT` transmet à la montre pour la date → SCHEDULED. Gated sur `link.isReady` (sinon « NO LINK »). Cohérent avec le builder offline.
- **Navigation** : **4e onglet CALENDAR** — `Tab.calendar` (entre protocols et logs), glyphe custom `CalendarGlyph` (Path §06 : cadre + bandeau + reliures + marques de jour), voiceOver « Calendrier ». La bottom bar flottante encaisse 4 glyphes.
- **`CalendarScreen`** (semaine + agenda) : bande 7 jours (lundi→dim, points thermiques par séance, jour sélectionné souligné, aujourd'hui en blanc), navigation semaine ‹ ›, agenda du jour (cartes tag + nom + heure + état + COMMIT/RETRY contour), `PLAN A TRAINING` (aplat) → `PlanPickerSheet` (MES PROTOCOLES + TEMPLATES). Suppression par **contextMenu** (⚠️ `swipeActions` inertes hors `List` — retirés).
- **Bascule `SEMAINE` / `À VENIR`** (sélecteur neutre en tête) : `À VENIR` liste **toutes les séances à traiter** — futur (aujourd'hui inclus, tous états) + **passé non transmis** (états ≠ SCHEDULED : oubliées/en faute ; une SCHEDULED passée est déjà sur la montre → masquée). Groupées par jour ; un jour passé non transmis porte un en-tête **EMBER « EN RETARD »** (alerte). Tap sur une séance → **saute au jour dans la vue SEMAINE**. Le badge `[N PLANNED]` reflète le mode (semaine vs total à traiter).
- **`PlanActions`** (off-UI, testable) : `plan` (heure défaut **07:00**), `remove`, `reschedule` (garde l'heure, **repasse en PLANNED** → re-commit), `sessions(on:)/(inWeekOf:)`, `weekDays(containing:)` (lundi en tête). Couvert par `PlanActionsTests`.
- **Bornes V1** (*non fait, plus tard*) : vue **mois**, **glisser-déposer** pour replanifier, **heure éditable** (07:00 fixe en V1), **semaines récurrentes / templates de semaine**, **compliance HealthKit** (prévu vs réalisé), métriques de charge, désinjecter la montre à la suppression d'un SCHEDULED.
- Tests : `PlanActionsTests` (unitaire) + `CalendarUITests` (onglet → planifier → agenda ; captures `CALENDAR_EMPTY` / `CALENDAR_PLANNED`).

### Vocabulaire : TRAINING remplace PAYLOAD (décision operator)
- **Le case study nomme la séance compilée `PAYLOAD`** (métaphore compile → inject payload → run). L'operator a tranché : **« payload » pas assez explicite → `TRAINING` partout**, en gardant le registre système anglais MAJUSCULES (règle n°5).
- **6 chaînes visibles** basculées : `INJECT TRAINING` (hero), `TRAINING DELIVERED`, `[TRAINING READY]` (`ProtocolState.ready` rawValue), `0 TRAININGS` (empty PROTOCOLS), `NO TRAINING LOGGED` (empty LOGS), `TRAINING LINK ESTABLISHED` (pairing). `CLAUDE.md` règles 4/5/9/12 mises à jour pour éviter un revert par une session future.
- ⚠️ **`ProtocolState.ready` rawValue a changé** (`"PAYLOAD READY"` → `"TRAINING READY"`) : valeur **persistée** en SwiftData. Pas de migration (aucune donnée livrée, modèle dev) — une base sim antérieure peut porter l'ancienne valeur ; reset du simulateur si besoin.
- **Non balayé** (référence case study extraite, pas du code applicatif) : `docs/screens.md`, `docs/copy.md`, `docs/design-tokens.md`, `docs/data-model.md` citent encore `PAYLOAD`. Lire « PAYLOAD » = « TRAINING » dans ces extraits, ou les harmoniser plus tard.

### Contrainte ferme
- **JAMAIS de cible watchOS** (principe fondateur). Seule exception future possible (V3, sur demande explicite) : complication QUAD. Voir mémoire projet `[[lane04-design-decisions]]`.

---

## Comment reprendre
1. Lire `CLAUDE.md` (règles absolues) + ce fichier + `docs/screens.md` (avancement).
2. Trancher la question LOGS ci-dessus **avant** la 3d.
3. Cadence : commit à la fin de chaque sous-phase, état des lieux avant la suivante, captures via `xcrun simctl` (le sim peut s'éteindre après `xcodebuild test` — `bootstatus` avant `install`).
