//
// mapper.mjs — re-validation stricte du payload LANE 04 puis traduction vers
// le format workout de la Garmin Training API.
//
// Mêmes bornes que `ProtocolValidator` côté iOS : le relais ne fait pas plus
// confiance au téléphone que l'app ne fait confiance à son UI. Toute dérive
// (store corrompu, client bricolé) est rejetée ici en 422, jamais poussée
// vers la montre.
//
// Module autonome (aucun import de config) → testable sans environnement.
//

export const LIMITS = {
  vma: [8, 25],
  intensity: [40, 150],
  maxBlocks: 16,
  maxStepsPerBlock: 16,
  iterations: [1, 20],
  timeGoal: [5, 3600],          // secondes
  distanceGoal: [50, 20000],    // mètres
  maxNameLength: 80
}

/// Tolérance d'allure : ±2.5 points de % VMA — miroir de
/// `VMACalculator.tolerancePercent` pour que la fourchette Garmin soit
/// identique à celle du chemin WorkoutKit.
export const PACE_TOLERANCE_PERCENT = 2.5

const INTENSITY_BY_ROLE = {
  'WARM-UP': 'WARMUP',
  'WORK': 'INTERVAL',
  'RECOVERY': 'RECOVERY',
  'COOL-DOWN': 'COOLDOWN'
}

export class PayloadError extends Error {}

function check(condition, message) {
  if (!condition) throw new PayloadError(message)
}

function finiteIn(value, [low, high]) {
  return Number.isFinite(value) && value >= low && value <= high
}

export function validatePayload(payload) {
  check(payload && typeof payload === 'object', 'payload manquant')
  check(finiteIn(payload.vma, LIMITS.vma), 'VMA hors plage sûre')

  const name = typeof payload.name === 'string' ? payload.name.trim() : ''
  check(name.length > 0 && name.length <= LIMITS.maxNameLength, 'nom de protocole invalide')
  check(!/\p{Cc}/u.test(payload.name), 'nom de protocole invalide')

  check(
    typeof payload.scheduledDate === 'string' &&
      /^\d{4}-\d{2}-\d{2}$/.test(payload.scheduledDate) &&
      !Number.isNaN(Date.parse(payload.scheduledDate)),
    'date de planification invalide'
  )

  check(
    Array.isArray(payload.blocks) &&
      payload.blocks.length > 0 &&
      payload.blocks.length <= LIMITS.maxBlocks,
    'structure de protocole invalide'
  )

  for (const block of payload.blocks) {
    check(Number.isInteger(block.iterations) && finiteIn(block.iterations, LIMITS.iterations),
      'nombre de répétitions invalide')
    check(
      Array.isArray(block.steps) &&
        block.steps.length > 0 &&
        block.steps.length <= LIMITS.maxStepsPerBlock,
      'nombre de pas invalide'
    )
    for (const step of block.steps) {
      check(step.role in INTENSITY_BY_ROLE, 'rôle de pas invalide')
      check(step.goalKind === 'TIME' || step.goalKind === 'DISTANCE', 'objectif de pas invalide')
      const goalRange = step.goalKind === 'TIME' ? LIMITS.timeGoal : LIMITS.distanceGoal
      check(finiteIn(step.goalValue, goalRange), 'objectif de pas invalide')
      check(finiteIn(step.percentVMA, LIMITS.intensity), 'intensité hors plage sûre')
      check(typeof step.targetsPace === 'boolean', "cible d'allure invalide")
    }
  }

  return { ...payload, name }
}

/// Vitesse (m/s) à un % de VMA (km/h) — miroir de `VMACalculator.speed`.
export function speedMS(vma, percent) {
  return (vma * (percent / 100)) / 3.6
}

function round3(value) {
  return Math.round(value * 1000) / 1000
}

function workoutStep(step, vma, stepOrder) {
  const base = {
    type: 'WorkoutStep',
    stepOrder,
    intensity: INTENSITY_BY_ROLE[step.role],
    description: `${Math.round(step.percentVMA)} % VMA`,
    durationType: step.goalKind, // TIME (s) / DISTANCE (m) — unités Garmin natives
    durationValue: step.goalValue
  }
  if (!step.targetsPace) return { ...base, targetType: 'OPEN' }
  return {
    ...base,
    targetType: 'SPEED',
    targetValueLow: round3(speedMS(vma, Math.max(0, step.percentVMA - PACE_TOLERANCE_PERCENT))),
    targetValueHigh: round3(speedMS(vma, step.percentVMA + PACE_TOLERANCE_PERCENT))
  }
}

/// Payload LANE 04 validé → workout Garmin. Un bloc répété devient un
/// WorkoutRepeatStep (stepOrder du répéteur avant ceux de ses pas), un bloc
/// simple est déplié à plat — même structure que `WorkoutBuilder` côté iOS.
export function toGarminWorkout(rawPayload) {
  const payload = validatePayload(rawPayload)
  let order = 0
  const steps = []

  for (const block of payload.blocks) {
    if (block.iterations > 1) {
      steps.push({
        type: 'WorkoutRepeatStep',
        stepOrder: ++order,
        repeatType: 'REPEAT_UNTIL_STEPS_CMPLT',
        repeatValue: block.iterations,
        steps: block.steps.map((step) => workoutStep(step, payload.vma, ++order))
      })
    } else {
      for (const step of block.steps) steps.push(workoutStep(step, payload.vma, ++order))
    }
  }

  return {
    workoutName: payload.name,
    description: `LANE 04 — ${payload.discipline} — VMA ${payload.vma.toFixed(1)} KM/H`,
    sport: 'RUNNING',
    steps
  }
}
