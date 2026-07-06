# Modèle de données — état actuel (audit)

Décrit le code **tel qu'il existe aujourd'hui**, avant mise en conformité. Les tensions avec le case study sont signalées ⚠️ et les décisions à prendre ❓.

## Types actuels (`Lane04/RunSession.swift`)

```
SessionCategory : enum String     // recovery, endurance, threshold, vo2max, race, hills
StepGoal        : enum            // .time(minutes:) | .distance(meters:) → WorkoutGoal
SessionStep     : struct          // role(.warmup/.work/.recovery/.cooldown), goal, percentVMA, targetsPace
SessionBlock    : struct          // title, [SessionStep], iterations
RunSession      : struct          // id, name, category, focus, summary, warmup?, [blocks], cooldown?
                                  // + customWorkout(vma:) et totals(vma:)
```

- **Catalogue statique** : `RunSession.catalog` = ~24 séances **préconstruites** en dur, groupées en 6 familles.
- **`VMACalculator`** : `speed(vma:percent:)` (m/s), `paceString`, `targetSpeedRange` → `ClosedRange<Measurement<UnitSpeed>>`.
- **`PaceConverter`** : conversion allure `m:ss/km` ↔ m/s (utilitaire testé, indépendant).

## Mapping WorkoutKit (fonctionnel)

`RunSession.customWorkout(vma:)` →
`CustomWorkout(activity: .running, location: .outdoor, warmup:, blocks:, cooldown:)`
- `SessionStep` (work) → `IntervalStep(.work, goal:, alert: SpeedRangeAlert)` avec plage ±2.5 % VMA.
- `SessionStep` (récup) → `IntervalStep(.recovery, goal:)` sans alerte.
- warmup/cooldown → `WorkoutStep(goal:)`.
- Injection via `WorkoutScheduler.shared.schedule(_:at:)`. ✅ Ce socle est réutilisable.

## Tensions avec le case study

### ⚠️ 1. Produit : *picker* vs *compiler*
Le case study décrit un **compilateur** : l'athlète *compile* un protocole et **édite** ses intervalles (répétitions par stepper, allure par sheet §12, `[DRAFT]` → `COMMIT`). Le code actuel est un **sélecteur** de 24 presets figés, non éditables. → refonte du flux, mais `RunSession/Block/Step` restent la bonne représentation d'un protocole.

### ⚠️ 2. Taxonomie des filières
Actuel : 6 catégories (`recovery, endurance, threshold, vo2max, race, hills`).
Case study : 5 tags thermiques **`[VMA] [SEUIL] [TEMPO] [FARTLEK] [RECUP]`**.
Divergences : `FARTLEK` absent du code ; `endurance/race/hills` hors nomenclature case study ; `vo2max` ≈ `VMA`.

### ⚠️ 3. Zones physiologiques (OPERATOR §08)
Le case study dérive **Z1–Z5** de la VMA (Z5 ≤3:29 … Z1 ≥5:01). Le code n'a pas de notion de zones nommées — seulement des `%VMA` bruts. La sheet d'allure doit afficher la zone en direct.

### ⚠️ 4. Persistance : inexistante
Aucune persistance (`AUCUNE` détectée). Or `OPERATOR` (VMA, unités), `LOGS` (historique), `CONSOLE` (TX MODE, haptics, target) et les protocoles compilés **exigent** un stockage.

### ⚠️ 5. Statut & TX MODE
Pas de machine à états `[PAYLOAD READY]→[TX…]→[SYNCED]/[FAULT]`, ni de compteur d'injections (bascule RITUAL→FAST à la 10ᵉ), ni de réglage `TX MODE`.

### ⚠️ 6. Design : voir `data-model` n'est pas concerné, mais l'UI actuelle (cyan `#00FFFF`, `.ultraThinMaterial`, radii 20/16/12, ombres) ne mappe aucun token. Détail dans l'audit / `design-tokens.md`.

## Questions ouvertes ❓

1. **Compiler vs catalogue** : garde-t-on les 24 presets comme **templates de départ** (que l'utilisateur clone puis édite), ou vise-t-on la compilation vierge pure ? *(recommandation : templates → édition, meilleur onboarding)*
2. **Persistance** : **SwiftData** (modèle riche, protocoles + logs) ou `@AppStorage`/JSON (réglages simples + fichiers) ? *(recommandation : SwiftData pour protocoles & logs, `@AppStorage` pour CONSOLE)*
3. **Nomenclature** : on adopte strictement `[VMA][SEUIL][TEMPO][FARTLEK][RECUP]` et on remappe `endurance/race/hills` dessus (ex. sortie longue → `TEMPO`/`RECUP`, côtes → `VMA`) ? Que deviennent les séances hors nomenclature ?
4. **VMA** : saisie manuelle uniquement (OPERATOR), ou test guidé (demi-Cooper/VAMEVAL) plus tard ?
5. **watchOS** : cible watchOS différée ? L'injection WorkoutKit fonctionne depuis iOS seul ; le case study veut une empreinte watch minimale (QUAD complication). *(recommandation : différer, non bloquant pour le cœur)*
6. **Zones** : les seuils Z1–Z5 du case study (Z5 ≤3:29 @ VMA 17.2) sont-ils une table fixe en %VMA à formaliser dans `VMACalculator` ?
