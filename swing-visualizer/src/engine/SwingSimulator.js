// Realistic, framework-neutral TurfTrack packets for UI and grading tests.

import { buildGolfSwingPath } from './SwingArc.js'

const clamp = (value, min, max) => Math.min(max, Math.max(min, value))
const finiteOr = (value, fallback) => Number.isFinite(value) ? value : fallback

function deepFreeze(value) {
  if (!value || typeof value !== 'object' || Object.isFrozen(value)) return value
  Object.values(value).forEach(deepFreeze)
  return Object.freeze(value)
}

function copySwing(swing) {
  return {
    ...swing,
    fsr_peaks: [...swing.fsr_peaks],
    path_points: swing.path_points.map((point) => [...point]),
    hand_points: swing.hand_points?.map((point) => [...point]),
    top_of_swing: swing.top_of_swing
      ? { ...swing.top_of_swing, point: [...swing.top_of_swing.point] }
      : undefined,
    follow_through: swing.follow_through
      ? { ...swing.follow_through, point: [...swing.follow_through.point] }
      : undefined,
  }
}

/**
 * Convert arbitrary heel/center/toe weights into integer percentages that are
 * non-negative and always add up to exactly 100.
 */
export function normalizePressurePercentages(values) {
  const input = Array.isArray(values)
    ? values
    : [values?.heelPct ?? values?.heel, values?.centerPct ?? values?.center, values?.toePct ?? values?.toe]
  const sanitized = [0, 1, 2].map((index) => Math.max(0, finiteOr(Number(input[index]), 0)))
  const total = sanitized.reduce((sum, value) => sum + value, 0)
  const normalized = total > 0
    ? sanitized.map((value) => (value / total) * 100)
    : [0, 100, 0]
  const rounded = normalized.map(Math.floor)
  let remainder = 100 - rounded.reduce((sum, value) => sum + value, 0)

  normalized
    .map((value, index) => ({ index, fraction: value - rounded[index] }))
    .sort((a, b) => b.fraction - a.fraction || a.index - b.index)
    .forEach(({ index }) => {
      if (remainder > 0) {
        rounded[index] += 1
        remainder -= 1
      }
    })

  return {
    heelPct: rounded[0],
    centerPct: rounded[1],
    toePct: rounded[2],
  }
}

/** Mulberry32 PRNG. Supplying a seed makes random-swing tests repeatable. */
export function createSeededRandom(seed = Date.now()) {
  let state
  if (typeof seed === 'string') {
    state = 2166136261
    for (let index = 0; index < seed.length; index += 1) {
      state = Math.imul(state ^ seed.charCodeAt(index), 16777619)
    }
  } else {
    state = Number(seed) >>> 0
  }

  return () => {
    state = (state + 0x6D2B79F5) | 0
    let value = Math.imul(state ^ (state >>> 15), 1 | state)
    value ^= value + Math.imul(value ^ (value >>> 7), 61 | value)
    return ((value ^ (value >>> 14)) >>> 0) / 4294967296
  }
}

function withArc(base, arcOptions) {
  const arc = buildGolfSwingPath(arcOptions)
  return {
    ...base,
    path_points: arc.path_points,
    hand_points: arc.hand_points,
    top_of_swing: arc.top_of_swing,
    follow_through: arc.follow_through,
  }
}

const PRESETS = {
  perfect: withArc({
    label: 'Perfect Strike',
    fsr_peaks: [95, 105, 180, 175, 100, 90],
    impact_quality: 96,
    contact_zone_label: 2,
    impact_zone: 2,
    impact_duration_us: 480,
    heel_pressure_pct: 28,
    center_pressure_pct: 46,
    toe_pressure_pct: 26,
    direction_label: 'Straight',
    estimated_distance_m: 165,
    club_speed_kmh: 132,
    swing_path_deg: 0.3,
    attack_angle_deg: -3.2,
  }, { swingPathDeg: 0.3, attackAngleDeg: -3.2, topHeight: 1.62, finishHeight: 1.78, quality: 96 }),
  heel_strike: withArc({
    label: 'Heel Strike',
    fsr_peaks: [175, 160, 110, 85, 70, 60],
    impact_quality: 58,
    contact_zone_label: 0,
    impact_zone: 0,
    impact_duration_us: 380,
    heel_pressure_pct: 65,
    center_pressure_pct: 25,
    toe_pressure_pct: 10,
    direction_label: 'Left',
    estimated_distance_m: 115,
    club_speed_kmh: 118,
    swing_path_deg: -4.2,
    attack_angle_deg: -5.8,
  }, { swingPathDeg: -4.2, attackAngleDeg: -5.8, topHeight: 1.48, finishHeight: 1.58, quality: 58 }),
  toe_strike: withArc({
    label: 'Toe Strike',
    fsr_peaks: [60, 70, 85, 110, 160, 175],
    impact_quality: 58,
    contact_zone_label: 4,
    impact_zone: 5,
    impact_duration_us: 360,
    heel_pressure_pct: 10,
    center_pressure_pct: 25,
    toe_pressure_pct: 65,
    direction_label: 'Right',
    estimated_distance_m: 110,
    club_speed_kmh: 115,
    swing_path_deg: 4.8,
    attack_angle_deg: -1.5,
  }, { swingPathDeg: 4.8, attackAngleDeg: -1.5, topHeight: 1.55, finishHeight: 1.68, quality: 58 }),
  thin_hit: withArc({
    label: 'Thin Hit',
    fsr_peaks: [80, 85, 90, 88, 82, 78],
    impact_quality: 38,
    contact_zone_label: 2,
    impact_zone: 2,
    impact_duration_us: 200,
    heel_pressure_pct: 32,
    center_pressure_pct: 36,
    toe_pressure_pct: 32,
    direction_label: 'Straight',
    estimated_distance_m: 80,
    club_speed_kmh: 95,
    swing_path_deg: 1.1,
    attack_angle_deg: 2.5,
  }, { swingPathDeg: 1.1, attackAngleDeg: 2.5, topHeight: 1.32, finishHeight: 1.4, quality: 38 }),
}

export const SWING_PRESETS = deepFreeze({ ...PRESETS, random: null })
export const SWING_PRESET_KEYS = Object.freeze(Object.keys(PRESETS))

export function getSwingPreset(key) {
  if (key === 'random') return generateRandomSwing()
  return SWING_PRESETS[key] ? copySwing(SWING_PRESETS[key]) : null
}

function getDirectionLabel(pathDegrees) {
  if (pathDegrees < -3) return 'Left'
  if (pathDegrees > 3) return 'Right'
  if (pathDegrees < -1) return 'Slight Left'
  if (pathDegrees > 1) return 'Slight Right'
  return 'Straight'
}

function makePressureDistribution(zone, quality, random) {
  const dominantRegion = Math.floor(zone / 2)
  const missStrength = 14 + ((100 - quality) / 60) * 30
  const weights = [24, 46, 24].map((base) => base + (random() - 0.5) * 12)
  weights[dominantRegion] += missStrength
  if (dominantRegion !== 1) weights[1] -= missStrength * 0.45
  return normalizePressurePercentages(weights)
}

function makeSensorPeaks(distribution, zone, quality, random) {
  const regionShares = [distribution.heelPct, distribution.centerPct, distribution.toePct]
  const peakScale = 1.4 + quality / 100
  return regionShares.flatMap((share, region) => [0, 1].map((side) => {
    const sensorIndex = region * 2 + side
    const zoneBoost = sensorIndex === zone ? 1.18 : 1
    const noise = 0.9 + random() * 0.2
    return Math.max(1, Math.round(share * peakScale * zoneBoost * noise))
  }))
}

function makePath(quality, pathDegrees, attackDegrees) {
  const arc = buildGolfSwingPath({
    sampleCount: 56,
    swingPathDeg: pathDegrees,
    attackAngleDeg: attackDegrees,
    topHeight: 1.25 + (quality / 100) * 0.4,
    quality,
  })
  return arc
}

function resolveRng(options = {}) {
  if (typeof options.rng === 'function') return options.rng
  if (options.seed !== undefined) return createSeededRandom(options.seed)
  return Math.random
}

/**
 * Mid/high-handicap style params — mostly below average, always different.
 * Typical 7i: ~70 mph club, ~95 mph ball, ~110–135 yds (not tour 150+).
 */
export function pickBelowAverageSimParams(options = {}) {
  const normalizedOptions = typeof options === 'function' ? { rng: options } : options
  const random = resolveRng(normalizedOptions)

  /* Quality skewed low: common band ~28–58, occasional up to ~72. */
  let quality
  if (Number.isFinite(Number(normalizedOptions.quality))) {
    quality = clamp(Math.round(Number(normalizedOptions.quality)), 1, 100)
  } else {
    const roll = random()
    if (roll < 0.55) quality = Math.round(24 + random() * 28)      /* weak */
    else if (roll < 0.88) quality = Math.round(48 + random() * 14) /* middling */
    else quality = Math.round(58 + random() * 14)                  /* decent day */
  }

  const clubSpeedMph = Number((56 + random() * 22 + quality * 0.18).toFixed(1))
  const smash = 1.08 + random() * 0.2 + (quality / 100) * 0.1
  const ballSpeedMph = Number(clamp(clubSpeedMph * smash, 55, 145).toFixed(1))

  /* Path / attack miss more often when quality is poor. */
  const missScale = 4.5 + ((100 - quality) / 100) * 7
  const swingPathDeg = Number(((random() - 0.5) * missScale).toFixed(1))
  const attackAngleDeg = Number((-9 + random() * 12).toFixed(1))

  /* Prefer heel/toe/thin zones over pure center. */
  let impactZone
  if (Number.isFinite(Number(normalizedOptions.impactZone))) {
    impactZone = clamp(Math.round(Number(normalizedOptions.impactZone)), 0, 5)
  } else if (random() < 0.28) {
    impactZone = random() < 0.5 ? 2 : 3
  } else {
    impactZone = clamp(Math.floor(random() * 6), 0, 5)
  }

  return {
    ballSpeedMph,
    clubSpeedMph,
    attackAngleDeg,
    swingPathDeg,
    quality,
    impactZone,
  }
}

/**
 * Generate a new simulated BLE swing packet.
 *
 * Options may include `{ seed, rng, quality }`. Pass a seed in tests for
 * deterministic output; omit it in the UI for a fresh result on every click.
 * Defaults are below-average mid-handicap swings that vary each call.
 */
export function generateRandomSwing(options = {}) {
  const normalizedOptions = typeof options === 'function' ? { rng: options } : options
  const random = resolveRng(normalizedOptions)
  const params = pickBelowAverageSimParams(normalizedOptions)
  const deterministic = normalizedOptions.seed !== undefined
    || typeof normalizedOptions.rng === 'function'
  const swing = simulateSwing({
    ...params,
    preview: false,
    rng: random,
    deterministic,
  })
  const { deterministic: _det, ...packet } = swing

  return {
    ...packet,
    label: 'Random Swing',
    source: normalizedOptions.source || 'random',
    timestamp_ms: deterministic ? 0 : swing.timestamp_ms,
  }
}

/**
 * Build a swing from explicit velocity / angle / ball-speed controls.
 *
 * @param {{
 *   ballSpeedMph?: number,
 *   clubSpeedMph?: number,
 *   attackAngleDeg?: number,
 *   swingPathDeg?: number,
 *   quality?: number,
 *   impactZone?: number,
 *   rng?: () => number,
 *   deterministic?: boolean,
 * }} options
 */
export function simulateSwing(options = {}) {
  const random = typeof options.rng === 'function' ? options.rng : Math.random
  const ballSpeedMph = clamp(finiteOr(Number(options.ballSpeedMph), 96), 40, 200)
  const clubSpeedMph = clamp(
    finiteOr(Number(options.clubSpeedMph), ballSpeedMph / 1.28),
    40,
    140,
  )
  const attackAngleDeg = clamp(finiteOr(Number(options.attackAngleDeg), -4.5), -12, 8)
  const swingPathDeg = clamp(finiteOr(Number(options.swingPathDeg), 2.5), -12, 12)
  const quality = clamp(Math.round(finiteOr(Number(options.quality), 52)), 1, 100)
  const zone = clamp(Math.round(finiteOr(Number(options.impactZone), 1)), 0, 5)
  const pressure = makePressureDistribution(zone, quality, random)
  const arc = makePath(quality, swingPathDeg, attackAngleDeg)
  const clubSpeedKmh = clubSpeedMph * 1.60934
  const ballSpeedKmh = ballSpeedMph * 1.60934
  /* Carry varies with smash quality, path miss, and attack — not a flat *1.35. */
  const centered = zone === 2 || zone === 3
  const carryYards = clamp(
    Math.round(
      ballSpeedMph * (0.92 + quality / 420)
      + attackAngleDeg * 1.4
      - Math.abs(swingPathDeg) * 2.4
      + (centered ? 6 : -8)
      + (random() - 0.5) * 10,
    ),
    45,
    210,
  )
  const estimatedDistanceM = Math.round(carryYards / 1.09361)
  const peakScale = 1.15 + quality / 110
  const fsrPeaks = makeSensorPeaks(pressure, zone, quality, random)

  return {
    label: 'Simulated Swing',
    source: 'simulate',
    zeroed: false,
    preview: Boolean(options.preview),
    deterministic: Boolean(options.deterministic),
    timestamp_ms: options.deterministic ? 0 : Date.now(),
    fsr_peaks: fsrPeaks.map((value, index) => Math.max(6, Math.round(value * (peakScale / 1.4)) + (index === zone ? 18 : 0))),
    impact_quality: quality,
    contact_zone_label: Math.round((zone / 5) * 4),
    impact_zone: zone,
    impact_duration_us: Math.round(240 + quality * 2.8 + random() * 40),
    heel_pressure_pct: pressure.heelPct,
    center_pressure_pct: pressure.centerPct,
    toe_pressure_pct: pressure.toePct,
    direction_label: getDirectionLabel(swingPathDeg),
    direction_penalty: Math.round(Math.abs(swingPathDeg) * 2.5),
    estimated_distance_m: estimatedDistanceM,
    club_speed_kmh: Math.round(clubSpeedKmh),
    club_speed_mph: Number(clubSpeedMph.toFixed(1)),
    ball_speed_mph: Number(ballSpeedMph.toFixed(1)),
    ball_speed_kmh: Number(ballSpeedKmh.toFixed(1)),
    radar_valid: true,
    radar_distance_mm: Math.round(520 + Math.abs(attackAngleDeg) * 22 + ballSpeedMph * 1.6 + random() * 40),
    radar_intra_score: Math.round(900 + (ballSpeedMph / 180) * 7000 + random() * 400),
    swing_path_deg: Number(swingPathDeg.toFixed(2)),
    attack_angle_deg: Number(attackAngleDeg.toFixed(2)),
    path_points: arc.path_points,
    hand_points: arc.hand_points,
    top_of_swing: arc.top_of_swing,
    follow_through: arc.follow_through,
    consistency_hint: clamp(Math.round(quality * 0.7 + (centered ? 8 : -6)), 0, 100),
    flags: 0x03,
  }
}

export default SWING_PRESETS
