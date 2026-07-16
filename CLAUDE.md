# CLAUDE.md — LANE 04

> **Compilateur d'entraînements de course.** L'athlète compile un protocole (fractionné, seuil, fartlek) sur iPhone, puis l'injecte d'un geste dans l'app native **Exercice** de l'Apple Watch via **WorkoutKit**. Gratuit, sans abonnement, sans serveur.
> **La référence de design est [`docs/LANE_04_Case_Study.pdf`](docs/LANE_04_Case_Study.pdf) (v3).** Le code se conforme au case study, jamais l'inverse. Détail extrait dans `docs/`.

Garder ce fichier court et à jour. Il ne contient que ce que Claude ne peut pas déduire du code : **les règles absolues** + les commandes/pièges du repo.

## RÈGLES ABSOLUES (non négociables)

Issues du case study §01–09. Toute PR doit les respecter.

1. **Un seul aplat d'accent par écran** = l'unique action possible. **Jamais EMBER + CRYO en aplat sur le même écran** — seule exception : l'écran de séance en cours (effort/récup superposés).
2. **Règle des 10 %** : les accents ne couvrent jamais plus de 10 % de la surface. EMBER/CRYO sont des **signaux, jamais du décor**.
3. **Sémantique thermique** : `EMBER #FF4D00` = effort, action primaire, allure dépassée, alerte. `CRYO #00E5FF` = récupération, allure conforme, sync OK, confirmation. L'utilisateur lit sa séance sans lire un mot.
4. **Statut `[BRACKET]`** en haut à droite de **chaque** écran, sans exception (ex. `[TRAINING READY]`, `[SYNCED]`, `[NO LINK]`, `[SYNC FAULT]`).
5. **Vocabulaire système** en mono, MAJUSCULES, anglais technique — réservé aux **commandes et statuts** : `COMPILE PROTOCOL`, `COMMIT`, `INJECT TRAINING`, `TRAINING DELIVERED`, `WARM-UP` / `COOL-DOWN`, `LOGS`, `CONSOLE`, `OPERATOR`, `SYNC FAULT — RETRY`. Le **français** reste la langue de lecture (descriptions, aide, onboarding). Pas d'emoji, pas de « bravo », pas de gamification. **`TRAINING` remplace le `PAYLOAD` du case study** (décision operator — « payload » pas assez explicite ; voir `docs/session-notes.md`).
6. **Chiffres tabulaires** (`.monospacedDigit()`, chasse fixe) sur **toute** valeur métrique — chrono, allure, distance, répétition, FC — **sans exception**. Un chrono qui tremble est un instrument cassé.
7. **Cibles tactiles 44 × 44 pt** minimum, sans exception.
8. **Animations : `opacity` + `transform` uniquement.** Une seule courbe : `cubic-bezier(0.16, 1, 0.3, 1)` (`Animation.master`). Décélération brutale, **jamais de rebond**. **Jamais d'ombre portée diffuse** — la profondeur se construit par paliers de luminance (`VOID`→`CARBON-1`→`CARBON-2`→`GLASS`) + hairlines. **Respect de Reduce Motion** : fondu 120 ms, zéro translation.
9. **Badges/statuts : radius 0**, jamais arrondis. Grammaire : pointillé = `[DRAFT]` (brouillon), contour = attente (`[TRAINING READY]`), aplat = confirmé (`[SYNCED]`), clignotement 1.2 s = faute (`[FAULT]`, exige une action).
10. **Le mot porte l'état, jamais la couleur seule.** Toute faute nomme sa cause et propose exactement **une** action.
11. **Extinction pendant l'effort** : une fois le payload injecté, aucune surface LANE 04 n'existe pendant la course — l'app native Exercice reprend la main.
12. **Chorégraphie `INJECT TRAINING`** : `RITUAL` 2400 ms (injections 1–9) → bascule auto `FAST` 900 ms dès la 10ᵉ. Réglable dans `CONSOLE › TX MODE`. Reduce Motion force `FAST` en fondu, sans flash.

## Docs de référence (extraites du case study)

- `docs/design-tokens.md` — table complète des tokens (§05) : couleurs, espacements base 4, rayons, matériaux, typo, motion, haptique, contrastes.
- `docs/screens.md` — les 12 écrans et leurs états (nominaux, empty, faults) + hero button 4 états + matrice des composants (§08–09).
- `docs/copy.md` — grille de conversion lexicale + labels VoiceOver en français clair (§02).
- `docs/data-model.md` — le modèle de données **actuel** tel qu'il est, et ses tensions avec le case study (à trancher).
- `docs/session-notes.md` — **handoff** : décisions hors case study à ne pas défaire + question ouverte LOGS (à lire avant la Phase 3d).
- `docs/screens.md` contient l'**état d'avancement** réel des écrans (✅/🟡/⬜ + commits).

## Commandes

Simulateur : iPhone 17 Pro. UDID booté : `xcrun simctl list devices booted`.

```bash
# Build (simulateur, sans signature)
xcodebuild -project Lane04.xcodeproj -scheme Lane04 -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' -configuration Debug \
  build CODE_SIGNING_ALLOWED=NO

# Tests (Swift Testing)
xcodebuild test -project Lane04.xcodeproj -scheme Lane04 \
  -destination 'platform=iOS Simulator,id=<UDID>' -only-testing:Lane04Tests

# Lancer + capturer
xcrun simctl bootstatus <UDID> -b
xcrun simctl install <UDID> <DerivedData>/Build/Products/Debug-iphonesimulator/Lane04.app
xcrun simctl launch <UDID> furan.Lane04
xcrun simctl io <UDID> screenshot out.png
```

⚠️ `xcodebuild test` s'exécute sur un **clone** et peut laisser le simulateur principal éteint — refaire `bootstatus` avant `install`.

⚠️ `simctl` ne supporte **pas** `tap` : pour piloter/capturer un écran précis, passer par un test UI (`XCUIApplication`) puis exporter la capture via `xcrun xcresulttool export attachments --path <.xcresult> --output-path <dir>`.

### Déploiement sur iPhone physique (device)

```bash
# 1. UDID device (pour xcodebuild) — PAS l'identifiant coredevice de devicectl
xcodebuild -project Lane04.xcodeproj -scheme Lane04 -showdestinations | grep 'platform:iOS' # → id 000081...
xcrun devicectl list devices                                   # état connecté + version iOS (≥ 26)

# 2. Build signé + 3. install + 4. launch
xcodebuild -project Lane04.xcodeproj -scheme Lane04 -configuration Debug \
  -destination 'platform=iOS,id=<DEVICE_UDID>' -derivedDataPath ./build-device \
  -allowProvisioningUpdates DEVELOPMENT_TEAM=<TEAM> CODE_SIGN_STYLE=Automatic build
xcrun devicectl device install app --device <DEVICE_UDID> ./build-device/Build/Products/Debug-iphoneos/Lane04.app
xcrun devicectl device process launch --device <DEVICE_UDID> furan.Lane04
```

Après install, **premier lancement bloqué** tant que l'utilisateur n'a pas approuvé le certif : *Réglages → Général → VPN et gestion de l'appareil → Faire confiance*. Teams connues de Xcode : `defaults read com.apple.dt.Xcode IDEProvisioningTeamByIdentifier`. Team ID d'un certif local : `security find-certificate -a -p | openssl x509 -noout -subject` (champ `OU=`).

## Pièges du repo

- **Groupes Xcode synchronisés** (`PBXFileSystemSynchronizedRootGroup`, `objectVersion 77`) : tout `.swift` déposé dans `Lane04/` est inclus automatiquement — **ne pas éditer le `.pbxproj`** pour ajouter un fichier.
- **Info.plist** généré (`GENERATE_INFOPLIST_FILE = YES`) : clés via build settings `INFOPLIST_KEY_*`, pas de fichier plist.
- **Entitlements** dans `Lane04/Lane04.entitlements` (`workout-kit` + `healthkit`). Simulateur build sans signer.
- ⚠️ **`workout-kit`/`healthkit` exigent un compte Apple Developer PAYANT** (99 €/an) : la provision **gratuite** (personal team) refuse `com.apple.developer.workout-kit` → build device échoue (« provisioning profile doesn't include… »). **Pour installer un build gratuit sur device** (voir sans injection montre) : signer avec un fichier d'entitlements **vide** (`<dict/>`) hors repo via `CODE_SIGN_ENTITLEMENTS=<tmp>` — l'injection WorkoutKit ne marchera pas (attendu), le reste de l'app oui. ⚠️ Un build gratuit **expire après 7 jours** (réinstaller). Ne pas commiter d'entitlements modifiés.
- **WorkoutKit** : `SpeedRangeAlert` prend `ClosedRange<Measurement<UnitSpeed>>` (pas `HKQuantity`, non `Comparable`) ; `WorkoutScheduler.schedule`/`requestAuthorization` sont `async` **non-throwing**. En test, importer explicitement `WorkoutKit`.
- **Sécurité / sûreté d'injection** : tout envoi à WorkoutKit doit passer par `WorkoutBuilder.validatedCustomWorkout(for:vma:)` ; ne jamais se fier aux seules bornes de l'UI. `ProtocolValidator` impose VMA 8…25, objectifs finis et bornés, intensité 40…150 % et une structure finie. Une séance `SCHEDULED` est immuable localement : sans annulation distante WorkoutKit, ne pas la supprimer, la déplacer ni supprimer son protocole (sinon doublon/séance orpheline sur la montre).
- **Vérité de transmission** : si WorkoutKit a accepté la séance mais que SwiftData ne peut pas l'enregistrer, signaler une faute d'enregistrement local et proposer seulement `RETRY SAVE`/`DISMISS` — **jamais `RETRY INJECT`**, qui créerait un doublon.
- **HealthKit** : l'app ne demande actuellement que l'écriture de `HKWorkoutType` (`read: []`) ; ne pas déclarer de lecture HealthKit dans les textes de permission tant qu'aucune lecture n'est implémentée.
- **Cible actuelle : iOS uniquement** (iOS 26, déploiement 26.0). **Persistance SwiftData en place** (`LaneSchema` : `RunProtocol`/`ProtocolBlock`/`ProtocolStep`/`OperatorProfile`/`RunLog`/`PlannedSession`) — tout nouveau `@Model` doit être ajouté à `LaneSchema.models` **et** aux 2 `modelContainer(for:)` en dur (`Lane04App`, preview `RootView`). Pas de cible watchOS (principe fondateur).
- **Nav : bottom bar custom à glyphes** (`RootView`/`NavGlyphs`, flottante) — 4 onglets **PROTOCOLS / CALENDAR / LOGS / CONSOLE**. Pictogrammes seuls, PAS de texte (« le mot est le symbole » = règle des STATUTS, jamais de la nav — voir `docs/session-notes.md`). Avancement & décisions récentes (builder from-scratch, dossiers de templates, calendrier) : `docs/session-notes.md`.
