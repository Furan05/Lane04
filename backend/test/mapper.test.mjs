//
// mapper.test.mjs — le mapper est la pièce qui décide de ce qui atteint la
// montre : structure, ordres, fourchettes d'allure, refus des payloads hors
// bornes. `node --test`.
//

import assert from 'node:assert/strict'
import { test } from 'node:test'
import {
  PACE_TOLERANCE_PERCENT,
  PayloadError,
  speedMS,
  toGarminWorkout,
  validatePayload
} from '../src/mapper.mjs'

function payload(overrides = {}) {
  return {
    name: '8 × 30/30',
    scheduledDate: '2026-07-20',
    vma: 16,
    discipline: 'VMA',
    blocks: [
      {
        title: 'WARM-UP',
        iterations: 1,
        steps: [
          { role: 'WARM-UP', goalKind: 'TIME', goalValue: 600, percentVMA: 60, targetsPace: false }
        ]
      },
      {
        title: 'CORPS',
        iterations: 8,
        steps: [
          { role: 'WORK', goalKind: 'TIME', goalValue: 30, percentVMA: 105, targetsPace: true },
          { role: 'RECOVERY', goalKind: 'TIME', goalValue: 30, percentVMA: 55, targetsPace: false }
        ]
      }
    ],
    ...overrides
  }
}

test('mapping nominal : structure, ordres et intensités', () => {
  const workout = toGarminWorkout(payload())

  assert.equal(workout.workoutName, '8 × 30/30')
  assert.equal(workout.sport, 'RUNNING')
  assert.equal(workout.steps.length, 2)

  const [warmup, repeat] = workout.steps
  assert.equal(warmup.type, 'WorkoutStep')
  assert.equal(warmup.stepOrder, 1)
  assert.equal(warmup.intensity, 'WARMUP')
  assert.equal(warmup.durationType, 'TIME')
  assert.equal(warmup.durationValue, 600)
  assert.equal(warmup.targetType, 'OPEN')

  assert.equal(repeat.type, 'WorkoutRepeatStep')
  assert.equal(repeat.stepOrder, 2)
  assert.equal(repeat.repeatValue, 8)
  assert.deepEqual(repeat.steps.map((s) => s.stepOrder), [3, 4])
  assert.deepEqual(repeat.steps.map((s) => s.intensity), ['INTERVAL', 'RECOVERY'])
})

test("fourchette d'allure : ±2.5 points de % VMA en m/s (miroir VMACalculator)", () => {
  const workout = toGarminWorkout(payload())
  const work = workout.steps[1].steps[0]

  assert.equal(work.targetType, 'SPEED')
  const low = speedMS(16, 105 - PACE_TOLERANCE_PERCENT)
  const high = speedMS(16, 105 + PACE_TOLERANCE_PERCENT)
  assert.ok(Math.abs(work.targetValueLow - low) < 0.001)
  assert.ok(Math.abs(work.targetValueHigh - high) < 0.001)
  assert.ok(work.targetValueLow < work.targetValueHigh)
})

test('un bloc simple est déplié à plat, sans répéteur', () => {
  const workout = toGarminWorkout(payload({
    blocks: [{
      title: 'TEMPO',
      iterations: 1,
      steps: [
        { role: 'WORK', goalKind: 'DISTANCE', goalValue: 5000, percentVMA: 80, targetsPace: true }
      ]
    }]
  }))
  assert.equal(workout.steps.length, 1)
  assert.equal(workout.steps[0].type, 'WorkoutStep')
  assert.equal(workout.steps[0].durationType, 'DISTANCE')
  assert.equal(workout.steps[0].durationValue, 5000)
})

test('refus : mêmes bornes que ProtocolValidator', () => {
  const cases = [
    payload({ vma: 7.9 }),
    payload({ vma: Number.NaN }),
    payload({ name: '' }),
    payload({ name: 'x'.repeat(81) }),
    payload({ scheduledDate: '20-07-2026' }),
    payload({ blocks: [] }),
    payload({ blocks: payload().blocks.map((b) => ({ ...b, iterations: 21 })) }),
    payload({
      blocks: [{
        title: 'X',
        iterations: 1,
        steps: [{ role: 'WORK', goalKind: 'TIME', goalValue: 4, percentVMA: 100, targetsPace: false }]
      }]
    }),
    payload({
      blocks: [{
        title: 'X',
        iterations: 1,
        steps: [{ role: 'WORK', goalKind: 'TIME', goalValue: 60, percentVMA: 151, targetsPace: false }]
      }]
    }),
    payload({
      blocks: [{
        title: 'X',
        iterations: 1,
        steps: [{ role: 'SPRINT', goalKind: 'TIME', goalValue: 60, percentVMA: 100, targetsPace: false }]
      }]
    })
  ]
  for (const invalid of cases) {
    assert.throws(() => validatePayload(invalid), PayloadError)
  }
})

test('le nom est normalisé (trim) mais les caractères de contrôle sont refusés', () => {
  assert.equal(validatePayload(payload({ name: '  SEUIL 3 × 8  ' })).name, 'SEUIL 3 × 8')
  assert.throws(() => validatePayload(payload({ name: 'SEUIL\u0000' })), PayloadError)
})
