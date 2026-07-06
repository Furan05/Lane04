# CLAUDE.md

Guide pour travailler efficacement sur **Lane 04**. Garde ce fichier court et à jour : n'y mets que ce qui n'est pas déductible du code (commandes, conventions, pièges).

## Projet

App iOS SwiftUI (iOS 26, Xcode 26) qui construit des **séances de course basées sur la VMA** et les injecte sur l'Apple Watch via **WorkoutKit**. Bundle id `furan.Lane04`.

## Commandes

Simulateur : iPhone 17 Pro. Récupérer un UDID booté : `xcrun simctl list devices booted`.

```bash
# Build (simulateur, sans signature)
xcodebuild -project Lane04.xcodeproj -scheme Lane04 -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' -configuration Debug \
  build CODE_SIGNING_ALLOWED=NO

# Tests (Swift Testing)
xcodebuild test -project Lane04.xcodeproj -scheme Lane04 \
  -destination 'platform=iOS Simulator,id=<UDID>' -only-testing:Lane04Tests

# Lancer + capturer dans le simulateur
xcrun simctl bootstatus <UDID> -b
xcrun simctl install <UDID> <DerivedData>/Build/Products/Debug-iphonesimulator/Lane04.app
xcrun simctl launch <UDID> furan.Lane04
xcrun simctl io <UDID> screenshot out.png
```

⚠️ `xcodebuild test` s'exécute sur un **clone** et peut laisser le simulateur principal éteint — refaire `bootstatus` avant `install`.

## Architecture

- `VMACalculator.swift` — VMA (km/h) + % → vitesse (m/s), allure `m:ss`, plage cible `Measurement<UnitSpeed>`.
- `RunSession.swift` — modèle (`SessionCategory`, `SessionStep`, `SessionBlock`, `RunSession`), catalogue de séances regroupées en 6 familles, et le builder `customWorkout(vma:)`.
- `WorkoutBuilderView.swift` — UI : saisie VMA, filtre par famille, sélecteur de séance, aperçu de structure, bouton d'injection.
- `PaceConverter.swift` — utilitaire de conversion d'allure (`m:ss/km` ↔ m/s), indépendant.
- Tests : `Lane04Tests/` (Swift Testing : `import Testing`, `@Test`, `#expect`).

## Conventions

- **Design system Lane 04** : fond noir OLED absolu, cartes « Liquid Glass » (`.ultraThinMaterial`) à fine bordure cyan `#00FFFF`, typographie `.monospaced` pour toutes les données, en-tête « LANE 04 » en gras.
- Le projet force `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` : marquer `nonisolated` les helpers purs appelés hors contexte isolé.
- Nouvelles séances : les ajouter au `catalog` dans `RunSession.swift` avec une `category` existante (le filtre UI les range automatiquement).

## Pièges

- **Groupes Xcode synchronisés** (`PBXFileSystemSynchronizedRootGroup`, `objectVersion 77`) : tout `.swift` déposé dans `Lane04/` est inclus automatiquement — **ne pas éditer le `.pbxproj`** pour ajouter un fichier.
- **Info.plist** généré (`GENERATE_INFOPLIST_FILE = YES`) : ajouter les clés via des build settings `INFOPLIST_KEY_*`, pas de fichier plist.
- **Entitlements** dans `Lane04/Lane04.entitlements` (`workout-kit` + `healthkit`). Le simulateur build sans signer ; sur device, Xcode demandera d'enregistrer les capabilities.
- **WorkoutKit** : `SpeedRangeAlert` prend `ClosedRange<Measurement<UnitSpeed>>` (pas `HKQuantity`, non `Comparable`) ; `WorkoutScheduler.schedule`/`requestAuthorization` sont `async` **non-throwing**. En test, importer explicitement `WorkoutKit` pour accéder aux membres de `CustomWorkout`.
