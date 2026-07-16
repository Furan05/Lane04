# LANE 04

Compilateur local d'entraînements de course pour iPhone. Concevez un protocole, ajustez ses intervalles et programmez-le dans l'app **Exercice** de l'Apple Watch via **WorkoutKit**.

LANE 04 fonctionne sans serveur, sans compte et sans abonnement. Les protocoles, le profil physiologique, le calendrier et les journaux restent stockés localement sur l'appareil.

## Fonctionnalités

- Compilation depuis 31 templates classés par filière : VMA, SEUIL, TEMPO, FARTLEK et RECUP.
- Création d'un protocole vierge et édition des blocs, répétitions, objectifs et allures.
- Calibration de la VMA par test demi-Cooper ou estimation depuis une course récente.
- Calcul des zones d'allure et de la charge planifiée TRIMP.
- Planification offline dans le calendrier, puis transmission à une date donnée sur l'Apple Watch.
- Journal des transmissions effectuées, sans présenter une séance prévue comme une séance réellement courue.
- Interface SwiftUI sombre, accessible et compatible avec Reduce Motion.

## Prérequis

- macOS avec Xcode compatible avec le SDK iOS 26.
- iOS 26 minimum ; le projet cible iPhone et iPad, sans cible watchOS.
- Un compte Apple Developer payant est nécessaire pour signer un build utilisant les entitlements HealthKit et WorkoutKit.
- Pour un build simulateur, la signature peut être désactivée.

## Installation

```bash
git clone git@github.com:Furan05/Lane04.git
cd Lane04
open Lane04.xcodeproj
```

Dans Xcode, sélectionnez le scheme `Lane04`, choisissez un simulateur iOS 26, puis lancez l'application.

## Build et tests

Build simulateur sans signature :

```bash
xcodebuild -project Lane04.xcodeproj -scheme Lane04 -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' -configuration Debug \
  build CODE_SIGNING_ALLOWED=NO
```

Tests unitaires :

```bash
xcodebuild test -project Lane04.xcodeproj -scheme Lane04 \
  -destination 'platform=iOS Simulator,id=<UDID>' \
  -only-testing:Lane04Tests
```

Tests d'interface :

```bash
xcodebuild test -project Lane04.xcodeproj -scheme Lane04 \
  -destination 'platform=iOS Simulator,id=<UDID>' \
  -only-testing:Lane04UITests
```

Pour connaître l'UDID d'un simulateur démarré :

```bash
xcrun simctl list devices booted
```

## Architecture

```text
Lane04/
├── App/          écrans SwiftUI, navigation et contrôleurs d'état
├── Data/         modèles SwiftData, catalogue, actions et validation
├── Theme/        tokens visuels, typographie et composants de marque
├── Resources/    polices Archivo et JetBrains Mono
└── Assets.xcassets
```

Les responsabilités principales sont séparées ainsi :

- `WorkoutBuilder` transforme un protocole en `CustomWorkout`.
- `ProtocolValidator` vérifie les données persistées juste avant tout envoi à WorkoutKit.
- `InjectionService` demande l'autorisation et programme la séance.
- `InjectionController` orchestre la machine d'état de transmission.
- `PlanActions` gère le calendrier local et ses états `PLANNED` / `SCHEDULED` / `SCHEDULE FAULT`.

## Données et sécurité

LANE 04 ne contient aucun backend ni appel réseau applicatif. L'accès HealthKit est limité à l'écriture de séances (`HKWorkoutType`) pour permettre la programmation via WorkoutKit ; l'application ne lit pas encore les séances réellement exécutées.

Les données envoyées à WorkoutKit sont validées à la frontière d'injection. Une séance déjà `SCHEDULED` est conservée localement afin d'éviter de créer un doublon ou une séance orpheline sur la montre lorsque l'annulation distante n'est pas disponible.

## Limites connues

- La lecture HealthKit des séances réellement courues et la comparaison prévu/réalisé sont prévues pour une évolution ultérieure.
- L'heure d'une séance planifiée est fixée à 07:00 en V1.
- La suppression ou le déplacement d'une séance déjà programmée sur la montre est volontairement bloqué localement.
- Un build signé avec une équipe personnelle gratuite ne peut pas utiliser les entitlements WorkoutKit ; il sert uniquement à tester l'interface.

## Documentation

- [Case study produit](docs/LANE_04_Case_Study.pdf)
- [Écrans et états](docs/screens.md)
- [Tokens de design](docs/design-tokens.md)
- [Modèle de données](docs/data-model.md)
- [Notes de session et décisions d'architecture](docs/session-notes.md)
- [Guide de contribution pour les agents](CLAUDE.md)
