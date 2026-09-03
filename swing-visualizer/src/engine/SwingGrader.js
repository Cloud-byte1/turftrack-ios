// Deterministic swing grading. This file has no UI or platform dependencies.

export { REFERENCE_SWINGS } from '../data/referenceSwings.js'

export const GRADE_COLORS = Object.freeze({
  green: '#22c55e',
  yellow: '#eab308',
  orange: '#f97316',
  red: '#ef4444',
})

export const GRADE_SCORES = Object.freeze({
  green: 100,
  yellow: 75,
  orange: 50,
  red: 25,
})

const GRADE_SEVERITY = Object.freeze({ green: 0, yellow: 1, orange: 2, red: 3 })
const METRIC_WEIGHTS = Object.freeze({ attack: 0.3, path: 0.3, speed: 0.2, zone: 0.2 })

const asFiniteNumber = (value) => {
  const numeric = Number(value)
  return Number.isFinite(numeric) ? numeric : null
}

/** Grade one scalar metric against a symmetric tolerance band. */
export function gradeMetric(value, ideal, tolerance) {
  const actualValue = asFiniteNumber(value)
  const idealValue = asFiniteNumber(ideal)
  const toleranceValue = asFiniteNumber(tolerance)

  if (actualValue === null || idealValue === null || toleranceValue === null || toleranceValue < 0) {
    return 'red'
  }

  const difference = Math.abs(actualValue - idealValue)
  if (toleranceValue === 0) return difference === 0 ? 'green' : 'red'
  if (difference <= toleranceValue) return 'green'
  if (difference <= toleranceValue * 2) return 'yellow'
  if (difference <= toleranceValue * 3) return 'orange'
  return 'red'
}

export function scoreForGrade(grade) {
  return GRADE_SCORES[grade] ?? GRADE_SCORES.red
}

export function colorForGrade(grade) {
  return GRADE_COLORS[grade] ?? GRADE_COLORS.red
}

export function overallGradeForScore(score) {
  const numericScore = asFiniteNumber(score) ?? 0
  if (numericScore >= 90) return 'green'
  if (numericScore >= 70) return 'yellow'
  if (numericScore >= 50) return 'orange'
  return 'red'
}

export function gradeImpactQuality(quality) {
  const value = asFiniteNumber(quality) ?? 0
  if (value >= 80) return 'green'
  if (value >= 60) return 'yellow'
  if (value >= 40) return 'orange'
  return 'red'
}

/** Letter grade for a 0–100 strike score. A is best. */
export function letterGradeFromScore(score) {
  const value = asFiniteNumber(score) ?? 0
  if (value >= 90) return 'A'
  if (value >= 80) return 'B'
  if (value >= 70) return 'C'
  if (value >= 55) return 'D'
  return 'F'
}

export function letterGradeColor(letter) {
  switch (letter) {
    case 'A': return '#22c55e'
    case 'B': return '#84cc16'
    case 'C': return '#eab308'
    case 'D': return '#f97316'
    default: return '#ef4444'
  }
}

function worstGrade(...grades) {
  return grades.reduce((worst, grade) => (
    (GRADE_SEVERITY[grade] ?? GRADE_SEVERITY.red) > GRADE_SEVERITY[worst]
      ? grade
      : worst
  ), 'green')
}

function gradeImpactLocation(swing, reference) {
  const actualZone = asFiniteNumber(swing.impact_zone ?? swing.contact_zone_label)
  const idealZone = asFiniteNumber(reference.impactZone)
  if (actualZone === null || idealZone === null) return 'red'

  // Sensors 2 and 3 make up the sweet spot, regardless of which is the nominal
  // reference sensor. Every sensor step away widens the grade by one band.
  const sweetSpotZones = [idealZone, Math.min(5, idealZone + 1)]
  const distance = Math.min(...sweetSpotZones.map((zone) => Math.abs(actualZone - zone)))
  if (distance === 0) return 'green'
  if (distance === 1) return 'yellow'
  if (distance === 2) return 'orange'
  return 'red'
}

export function gradePressureDistribution(swing, reference) {
  const tolerance = reference?.tolerances?.zonePct
  const pressureGrades = [
    gradeMetric(swing?.heel_pressure_pct, reference?.heelPct, tolerance),
    gradeMetric(swing?.center_pressure_pct, reference?.centerPct, tolerance),
    gradeMetric(swing?.toe_pressure_pct, reference?.toePct, tolerance),
  ]
  return worstGrade(...pressureGrades, gradeImpactLocation(swing ?? {}, reference ?? {}))
}

function buildCorrections(swing, reference, grades) {
  const corrections = []
  const isPoor = (grade) => grade === 'orange' || grade === 'red'

  if (isPoor(grades.attack)) {
    corrections.push(swing.attack_angle_deg < reference.attackAngleDeg
      ? 'Attack angle too steep — hit down less'
      : 'Attack angle too shallow — hit down more')
  }

  if (isPoor(grades.path)) {
    corrections.push(swing.swing_path_deg < reference.swingPathDeg
      ? 'Swing path outside-in — causes slice/fade'
      : 'Swing path inside-out — causes draw/hook')
  }

  if (isPoor(grades.speed)) {
    corrections.push(swing.club_speed_kmh < reference.clubSpeedKmh
      ? 'Club speed too slow — rotate through the shot'
      : 'Club speed too fast — prioritize centered contact')
  }

  if (isPoor(grades.zone)) {
    const heelMiss = (asFiniteNumber(swing.heel_pressure_pct) ?? 0) - reference.heelPct
    const toeMiss = (asFiniteNumber(swing.toe_pressure_pct) ?? 0) - reference.toePct
    corrections.push(heelMiss > toeMiss && heelMiss > 10
      ? 'Heel strike — move ball position forward slightly'
      : toeMiss > 10
        ? 'Toe strike — stand slightly closer to the ball'
        : 'Off-center contact — keep the club face stable through impact')
  }

  return corrections
}

export function gradeSwing(swing, reference) {
  if (!swing || typeof swing !== 'object') {
    throw new TypeError('gradeSwing requires a swing data object')
  }
  if (!reference || typeof reference !== 'object' || !reference.tolerances) {
    throw new TypeError('gradeSwing requires a reference swing with tolerances')
  }

  const attackGrade = gradeMetric(
    swing.attack_angle_deg,
    reference.attackAngleDeg,
    reference.tolerances.attackAngle,
  )
  const pathGrade = gradeMetric(
    swing.swing_path_deg,
    reference.swingPathDeg,
    reference.tolerances.swingPath,
  )
  const speedGrade = gradeMetric(
    swing.club_speed_kmh,
    reference.clubSpeedKmh,
    reference.tolerances.clubSpeed,
  )
  const zoneGrade = gradePressureDistribution(swing, reference)
  const impactGrade = gradeImpactQuality(swing.impact_quality)
  const grades = { attack: attackGrade, path: pathGrade, speed: speedGrade, zone: zoneGrade }

  const overallScore = Math.round(
    scoreForGrade(attackGrade) * METRIC_WEIGHTS.attack
      + scoreForGrade(pathGrade) * METRIC_WEIGHTS.path
      + scoreForGrade(speedGrade) * METRIC_WEIGHTS.speed
      + scoreForGrade(zoneGrade) * METRIC_WEIGHTS.zone,
  )

  return {
    overallScore,
    overallGrade: overallGradeForScore(overallScore),
    impactGrade,
    impactColor: colorForGrade(impactGrade),
    attackGrade,
    attackColor: colorForGrade(attackGrade),
    pathGrade,
    pathColor: colorForGrade(pathGrade),
    speedGrade,
    speedColor: colorForGrade(speedGrade),
    zoneGrade,
    zoneColor: colorForGrade(zoneGrade),
    corrections: buildCorrections(swing, reference, grades),
    letterGrade: letterGradeFromScore(overallScore),
    strikeLetter: letterGradeFromScore(asFiniteNumber(swing.impact_quality) ?? overallScore),
    metrics: {
      impact: { grade: impactGrade, score: scoreForGrade(impactGrade) },
      attack: { grade: attackGrade, score: scoreForGrade(attackGrade) },
      path: { grade: pathGrade, score: scoreForGrade(pathGrade) },
      speed: { grade: speedGrade, score: scoreForGrade(speedGrade) },
      zone: { grade: zoneGrade, score: scoreForGrade(zoneGrade) },
    },
  }
}

/** Return the display color for one segment of the 3D swing path.
 *  Green/grade color = swing through impact; grey = follow-through.
 */
export function getPathColor(pointIndex, totalPoints, grade, impactProgress = 0.58) {
  const safeTotal = Math.max(1, Math.floor(asFiniteNumber(totalPoints) ?? 1))
  const safeIndex = Math.max(0, Math.floor(asFiniteNumber(pointIndex) ?? 0))
  const progress = safeTotal <= 1 ? 1 : Math.min(1, safeIndex / (safeTotal - 1))
  const split = clampProgress(asFiniteNumber(impactProgress) ?? 0.58)

  // After impact → follow-through (grey)
  if (progress > split) {
    if (progress < split + 0.12) return '#94a3b8'
    return '#64748b'
  }

  // Backswing → impact → graded swing color (green when good)
  const attackGrade = typeof grade === 'string' ? grade : grade?.attackGrade
  return colorForGrade(attackGrade ?? 'green')
}

function clampProgress(value) {
  return Math.min(0.9, Math.max(0.35, value))
}
