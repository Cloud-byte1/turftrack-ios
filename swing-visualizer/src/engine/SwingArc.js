/**
 * Classic RH golf swing club-head path.
 * +X = target, +Y = up, +Z = toward golfer.
 *
 * Top of backswing and follow-through finish are intentionally different shapes:
 * - Top: high, behind the ball, wrapped over the trail shoulder
 * - Finish: high over the lead shoulder after a low release past impact
 */

const clamp = (value, min, max) => Math.min(max, Math.max(min, value))

function lerp(a, b, t) {
  return a + (b - a) * t
}

function lerp3(a, b, t) {
  return [
    lerp(a[0], b[0], t),
    lerp(a[1], b[1], t),
    lerp(a[2], b[2], t),
  ]
}

function smoothstep(t) {
  const x = clamp(t, 0, 1)
  return x * x * (3 - 2 * x)
}

/**
 * Phase keyframes [phase, x, y, z].
 * Phases: address → top (~0.38) → impact (~0.58) → finish (~1.0)
 */
function headKeyframes(topHeight, finishHeight) {
  const topY = clamp(topHeight, 1.25, 1.95)
  const finishY = clamp(finishHeight, 1.35, 2.05)

  return [
    // Address / start
    [0.00, -0.18, 0.06, 0.14],
    // Takeaway — clubhead moves back and slightly inside
    [0.08, -0.55, 0.28, 0.32],
    // Arm parallel (backswing)
    [0.18, -0.98, 0.72, 0.58],
    // Late backswing — climbing to trail shoulder
    [0.28, -0.72, 1.25, 0.92],
    // TOP — highest, wrapped behind / over trail shoulder (not mirrored finish)
    [0.38, -0.12, topY, 1.18],
    // Transition — club drops into the slot
    [0.46, -0.62, 1.15, 0.78],
    // Delivery — approaching from inside
    [0.52, -0.38, 0.48, 0.32],
    // IMPACT
    [0.58, 0.0, 0.0, 0.0],
    // Release — low and out toward the target (distinct from top)
    [0.66, 0.62, 0.28, -0.28],
    // Mid follow-through — rising past the ball line
    [0.78, 1.05, 0.85, -0.22],
    // Pre-finish — wrapping lead side
    [0.90, 0.72, 1.35, 0.35],
    // FINISH — high over lead shoulder (different pose than top)
    [1.00, 0.22, finishY, 0.95],
  ]
}

function sampleKeyframes(keys, count) {
  const points = []
  for (let i = 0; i < count; i += 1) {
    const phase = i / Math.max(1, count - 1)
    let seg = 1
    while (seg < keys.length && keys[seg][0] < phase) seg += 1
    const a = keys[seg - 1]
    const b = keys[Math.min(seg, keys.length - 1)]
    const span = (b[0] - a[0]) || 1
    const t = smoothstep((phase - a[0]) / span)
    points.push(lerp3(a.slice(1), b.slice(1), t))
  }
  return points
}

function rotateYaw(point, degrees) {
  const rad = (degrees * Math.PI) / 180
  const cos = Math.cos(rad)
  const sin = Math.sin(rad)
  return [
    point[0] * cos - point[2] * sin,
    point[1],
    point[0] * sin + point[2] * cos,
  ]
}

function handFromHead(head, phase) {
  // Hands stay nearer the torso; more extension through release.
  const pivot = [0.02, 1.05, 0.62]
  const extend = phase < 0.58
    ? lerp(0.34, 0.40, phase / 0.58)
    : lerp(0.40, 0.48, (phase - 0.58) / 0.42)
  return [
    lerp(pivot[0], head[0], extend),
    lerp(pivot[1], head[1], extend * 0.85) + (phase > 0.85 ? 0.08 : 0),
    lerp(pivot[2], head[2], extend),
  ]
}

function markerFromPath(path, index, impactIndex) {
  return {
    index,
    impactIndex,
    point: [...path[index]],
    height_m: Number(path[index][1].toFixed(3)),
    progress: index / Math.max(1, path.length - 1),
  }
}

/**
 * @param {object} options
 * @param {number} [options.sampleCount=64]
 * @param {number} [options.swingPathDeg=0]
 * @param {number} [options.attackAngleDeg=-3.5]
 * @param {number} [options.topHeight=1.62]
 * @param {number} [options.finishHeight=1.72]
 * @param {number} [options.quality=90]
 */
export function buildGolfSwingPath(options = {}) {
  const sampleCount = Math.max(32, Math.floor(options.sampleCount ?? 64))
  const swingPathDeg = Number(options.swingPathDeg) || 0
  const attackAngleDeg = Number(options.attackAngleDeg) || -3.5
  const topHeight = Number(options.topHeight) || 1.62
  const finishHeight = Number(options.finishHeight) || Math.max(topHeight + 0.08, 1.72)
  const quality = clamp(Number(options.quality) || 90, 0, 100)

  const keys = headKeyframes(topHeight, finishHeight)
  let headPath = sampleKeyframes(keys, sampleCount)

  const attackRad = (attackAngleDeg * Math.PI) / 180
  headPath = headPath.map((point, index) => {
    const phase = index / Math.max(1, sampleCount - 1)
    const nearImpact = 1 - Math.min(1, Math.abs(phase - 0.58) / 0.18)
    const attackBend = Math.sin(attackRad) * 0.42 * nearImpact * (phase < 0.58 ? 1 : -0.35)
    const warped = rotateYaw(
      [point[0], Math.max(0, point[1] + attackBend), point[2]],
      swingPathDeg * 0.9,
    )
    if (quality >= 92) return warped
    const noise = ((100 - quality) / 100) * 0.035
    const wobble = Math.sin(index * 1.55) * noise
    return [warped[0] + wobble, warped[1], warped[2] - wobble * 0.5]
  })

  const impactIndex = Math.round(0.58 * (sampleCount - 1))
  headPath[impactIndex] = [0, 0, 0]

  const handPath = headPath.map((head, index) => (
    handFromHead(head, index / Math.max(1, sampleCount - 1))
  ))

  // Top = max height on backswing only (before impact).
  let topIndex = 0
  for (let i = 0; i <= impactIndex; i += 1) {
    if (headPath[i][1] >= headPath[topIndex][1]) topIndex = i
  }

  // Follow-through apex = max height after impact (the finish).
  let followIndex = impactIndex
  for (let i = impactIndex; i < headPath.length; i += 1) {
    if (headPath[i][1] >= headPath[followIndex][1]) followIndex = i
  }

  return {
    path_points: headPath,
    hand_points: handPath,
    impactIndex,
    topIndex,
    followIndex,
    top_of_swing: markerFromPath(headPath, topIndex, impactIndex),
    follow_through: markerFromPath(headPath, followIndex, impactIndex),
  }
}

export default buildGolfSwingPath
