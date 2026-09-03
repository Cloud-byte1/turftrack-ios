/**
 * Framework-neutral inertial path reconstruction.
 *
 * Raw accelerometer values are rotated into world space, gravity is removed,
 * acceleration is filtered and integrated twice, and the resulting path is
 * anchored to the detected impact sample. For best results, provide sensor
 * quaternions and a short stationary lead-in before the backswing.
 */

export const STANDARD_GRAVITY_MPS2 = 9.80665

const DEFAULT_OPTIONS = Object.freeze({
  sampleRateHz: 100,
  accelerationUnit: 'auto',
  gyroUnit: 'auto',
  removeGravity: true,
  gravitySamples: 8,
  calibrationSamples: 0,
  smoothingFactor: 0.4,
  accelerationDeadband: 0.08,
  zeroVelocityAtEnd: true,
  anchorAtImpact: true,
  outputScale: 1,
})

const clamp = (value, min, max) => Math.min(max, Math.max(min, value))
const finite = (value) => {
  const numeric = Number(value)
  return Number.isFinite(numeric) ? numeric : null
}
const add = (a, b) => [a[0] + b[0], a[1] + b[1], a[2] + b[2]]
const subtract = (a, b) => [a[0] - b[0], a[1] - b[1], a[2] - b[2]]
const scale = (vector, amount) => vector.map((value) => value * amount)
const magnitude = (vector) => Math.hypot(vector[0], vector[1], vector[2])
const average = (vectors) => vectors.length === 0
  ? [0, 0, 0]
  : scale(vectors.reduce(add, [0, 0, 0]), 1 / vectors.length)

function toVector3(value) {
  if (Array.isArray(value) || ArrayBuffer.isView(value)) {
    const result = [finite(value[0]), finite(value[1]), finite(value[2])]
    return result.every((entry) => entry !== null) ? result : null
  }
  if (value && typeof value === 'object') {
    const result = [finite(value.x), finite(value.y), finite(value.z)]
    return result.every((entry) => entry !== null) ? result : null
  }
  return null
}

function vectorFromFields(sample, fieldGroups) {
  for (const fields of fieldGroups) {
    const vector = fields.map((field) => finite(sample?.[field]))
    if (vector.every((value) => value !== null)) return vector
  }
  return null
}

function readAcceleration(sample) {
  if (Array.isArray(sample) || ArrayBuffer.isView(sample)) {
    return { vector: toVector3(sample) ?? [0, 0, 0], isLinear: true, unit: null }
  }

  const linearKeys = ['linearAcceleration', 'linear_acceleration', 'linearAccel', 'linear_accel']
  for (const key of linearKeys) {
    const vector = toVector3(sample?.[key])
    if (vector) return { vector, isLinear: true, unit: sample?.acceleration_unit ?? sample?.accel_unit }
  }
  const linearFields = vectorFromFields(sample, [
    ['linear_ax', 'linear_ay', 'linear_az'],
    ['linear_accel_x', 'linear_accel_y', 'linear_accel_z'],
  ])
  if (linearFields) {
    return { vector: linearFields, isLinear: true, unit: sample?.acceleration_unit ?? sample?.accel_unit }
  }

  for (const key of ['acceleration', 'accelerometer', 'accel']) {
    const vector = toVector3(sample?.[key])
    if (vector) return { vector, isLinear: false, unit: sample?.acceleration_unit ?? sample?.accel_unit }
  }
  const rawFields = vectorFromFields(sample, [
    ['ax', 'ay', 'az'],
    ['accel_x', 'accel_y', 'accel_z'],
    ['acceleration_x', 'acceleration_y', 'acceleration_z'],
  ])
  return {
    vector: rawFields ?? [0, 0, 0],
    isLinear: false,
    unit: sample?.acceleration_unit ?? sample?.accel_unit,
  }
}

function readGyroscope(sample) {
  for (const key of ['gyroscope', 'gyro', 'angularVelocity', 'angular_velocity']) {
    const vector = toVector3(sample?.[key])
    if (vector) return { vector, unit: sample?.gyro_unit ?? sample?.gyroscope_unit }
  }
  return {
    vector: vectorFromFields(sample, [
      ['gx', 'gy', 'gz'],
      ['gyro_x', 'gyro_y', 'gyro_z'],
    ]) ?? [0, 0, 0],
    unit: sample?.gyro_unit ?? sample?.gyroscope_unit,
  }
}

function normalizeQuaternion(value) {
  let quaternion = null
  if (Array.isArray(value) || ArrayBuffer.isView(value)) {
    quaternion = [finite(value[0]), finite(value[1]), finite(value[2]), finite(value[3])]
  } else if (value && typeof value === 'object') {
    quaternion = [finite(value.x), finite(value.y), finite(value.z), finite(value.w)]
  }
  if (!quaternion || quaternion.some((entry) => entry === null)) return null
  const length = Math.hypot(...quaternion)
  return length > 1e-9 ? quaternion.map((entry) => entry / length) : null
}

function readQuaternion(sample) {
  for (const key of ['quaternion', 'orientation', 'quat']) {
    const quaternion = normalizeQuaternion(sample?.[key])
    if (quaternion) return quaternion
  }
  return normalizeQuaternion([
    sample?.qx,
    sample?.qy,
    sample?.qz,
    sample?.qw,
  ])
}

function multiplyQuaternions(a, b) {
  const [ax, ay, az, aw] = a
  const [bx, by, bz, bw] = b
  return [
    aw * bx + ax * bw + ay * bz - az * by,
    aw * by - ax * bz + ay * bw + az * bx,
    aw * bz + ax * by - ay * bx + az * bw,
    aw * bw - ax * bx - ay * by - az * bz,
  ]
}

function rotateVector(vector, quaternion) {
  const [qx, qy, qz, qw] = quaternion
  const uv = [
    qy * vector[2] - qz * vector[1],
    qz * vector[0] - qx * vector[2],
    qx * vector[1] - qy * vector[0],
  ]
  const uuv = [
    qy * uv[2] - qz * uv[1],
    qz * uv[0] - qx * uv[2],
    qx * uv[1] - qy * uv[0],
  ]
  return add(vector, add(scale(uv, 2 * qw), scale(uuv, 2)))
}

function normalizedUnit(unit) {
  return String(unit ?? '').toLowerCase().replaceAll(' ', '')
}

function accelerationScale(info, rawMagnitudeMedian, requestedUnit) {
  const unit = normalizedUnit(info.unit || requestedUnit)
  if (['g', 'gravity', 'gravities'].includes(unit)) return STANDARD_GRAVITY_MPS2
  if (['m/s2', 'm/s²', 'mps2', 'ms-2'].includes(unit)) return 1
  if (info.isLinear) return 1
  return rawMagnitudeMedian > 0 && rawMagnitudeMedian < 4 ? STANDARD_GRAVITY_MPS2 : 1
}

function gyroScale(info, requestedUnit) {
  const unit = normalizedUnit(info.unit || requestedUnit)
  if (['deg/s', 'degree/s', 'degrees/s', 'dps'].includes(unit)) return Math.PI / 180
  if (['rad/s', 'radian/s', 'radians/s', 'rps'].includes(unit)) return 1
  return magnitude(info.vector) > 12 ? Math.PI / 180 : 1
}

function integrateOrientation(quaternion, gyroInfo, deltaSeconds, requestedUnit) {
  const angularVelocity = scale(gyroInfo.vector, gyroScale(gyroInfo, requestedUnit))
  const speed = magnitude(angularVelocity)
  if (speed < 1e-9 || deltaSeconds <= 0) return quaternion
  const halfAngle = speed * deltaSeconds * 0.5
  const sine = Math.sin(halfAngle)
  const delta = [
    (angularVelocity[0] / speed) * sine,
    (angularVelocity[1] / speed) * sine,
    (angularVelocity[2] / speed) * sine,
    Math.cos(halfAngle),
  ]
  return normalizeQuaternion(multiplyQuaternions(quaternion, delta)) ?? quaternion
}

function explicitDeltaSeconds(sample) {
  const candidates = [
    ['dt_s', 1], ['delta_s', 1], ['dt_ms', 1e-3], ['delta_ms', 1e-3],
    ['dt_us', 1e-6], ['delta_us', 1e-6],
  ]
  for (const [key, scaleFactor] of candidates) {
    const value = finite(sample?.[key])
    if (value !== null && value > 0) return value * scaleFactor
  }
  const generic = finite(sample?.dt)
  if (generic !== null && generic > 0) return generic >= 1 ? generic * 1e-3 : generic
  return null
}

function timestampDeltaSeconds(current, previous) {
  const candidates = [
    ['timestamp_s', 1], ['time_s', 1], ['timestamp_ms', 1e-3], ['time_ms', 1e-3],
    ['timestamp_us', 1e-6], ['time_us', 1e-6], ['timestamp_ns', 1e-9], ['time_ns', 1e-9],
  ]
  for (const [key, scaleFactor] of candidates) {
    const currentValue = finite(current?.[key])
    const previousValue = finite(previous?.[key])
    if (currentValue !== null && previousValue !== null) {
      return (currentValue - previousValue) * scaleFactor
    }
  }

  const currentValue = finite(current?.timestamp ?? current?.time ?? current?.t)
  const previousValue = finite(previous?.timestamp ?? previous?.time ?? previous?.t)
  if (currentValue === null || previousValue === null) return null
  const difference = currentValue - previousValue
  const absoluteTimestamp = Math.max(Math.abs(currentValue), Math.abs(previousValue))
  if (absoluteTimestamp > 1e14 || Math.abs(difference) > 1000) return difference * 1e-6
  if (absoluteTimestamp > 1e11 || Math.abs(difference) >= 1) return difference * 1e-3
  return difference
}

function buildTimeline(samples, options) {
  const sampleRate = Math.max(1, finite(options.sampleRateHz) ?? DEFAULT_OPTIONS.sampleRateHz)
  const fallbackDelta = 1 / sampleRate
  const maxDelta = Math.max(
    fallbackDelta,
    finite(options.maxDeltaSeconds) ?? Math.max(0.1, fallbackDelta * 5),
  )
  const deltas = samples.map((sample, index) => {
    if (index === 0) return 0
    const measured = explicitDeltaSeconds(sample) ?? timestampDeltaSeconds(sample, samples[index - 1])
    if (!Number.isFinite(measured) || measured <= 0) return fallbackDelta
    return Math.min(measured, maxDelta)
  })
  const times = deltas.reduce((result, delta, index) => {
    result.push(index === 0 ? 0 : result[index - 1] + delta)
    return result
  }, [])
  return { deltas, times }
}

function median(values) {
  if (values.length === 0) return 0
  const sorted = [...values].sort((a, b) => a - b)
  const middle = Math.floor(sorted.length / 2)
  return sorted.length % 2 ? sorted[middle] : (sorted[middle - 1] + sorted[middle]) / 2
}

function explicitImpactIndex(samples) {
  return samples.findIndex((sample) => (
    sample?.impact === true
      || sample?.isImpact === true
      || sample?.is_impact === true
      || sample?.impact_detected === true
      || String(sample?.event ?? '').toLowerCase() === 'impact'
  ))
}

export function detectImpactIndex(samples, accelerations) {
  if (!Array.isArray(samples) || samples.length === 0) return -1
  const markedIndex = explicitImpactIndex(samples)
  if (markedIndex >= 0) return markedIndex

  const vectors = accelerations?.length === samples.length
    ? accelerations
    : samples.map((sample) => readAcceleration(sample).vector)
  const magnitudes = vectors.map(magnitude)
  const maximum = Math.max(...magnitudes)
  const minimum = Math.min(...magnitudes)
  if (maximum - minimum < 1e-6) return Math.floor((samples.length - 1) / 2)
  return magnitudes.indexOf(maximum)
}

function emptyResult() {
  return {
    pathPoints: [],
    path_points: [],
    velocities: [],
    accelerations: [],
    orientations: [],
    timestamps: [],
    impactIndex: -1,
    durationSeconds: 0,
  }
}

/**
 * Reconstruct a swing and retain intermediate values for diagnostics.
 * Quaternions use the common `[x, y, z, w]` order.
 */
export function reconstructSwing(samples, userOptions = {}) {
  if (!Array.isArray(samples)) {
    throw new TypeError('reconstructSwing requires an array of IMU samples')
  }
  if (samples.length === 0) return emptyResult()

  const options = { ...DEFAULT_OPTIONS, ...userOptions }
  const { deltas, times } = buildTimeline(samples, options)
  const accelerationInfo = samples.map(readAcceleration)
  const rawMagnitudes = accelerationInfo
    .filter((info) => !info.isLinear)
    .map((info) => magnitude(info.vector))
    .filter((value) => value > 1e-9)
  const rawMagnitudeMedian = median(rawMagnitudes)

  let orientation = normalizeQuaternion(options.initialOrientation) ?? [0, 0, 0, 1]
  const orientations = samples.map((sample, index) => {
    const measured = readQuaternion(sample)
    if (measured) {
      orientation = measured
    } else if (index > 0) {
      orientation = integrateOrientation(
        orientation,
        readGyroscope(samples[index - 1]),
        deltas[index],
        options.gyroUnit,
      )
    }
    return [...orientation]
  })

  const worldAccelerations = accelerationInfo.map((info, index) => {
    const accelerationMps2 = scale(
      info.vector,
      accelerationScale(info, rawMagnitudeMedian, options.accelerationUnit),
    )
    return rotateVector(accelerationMps2, orientations[index])
  })

  let gravityVector = toVector3(options.gravityVector)
  if (!gravityVector && options.removeGravity) {
    const gravitySampleCount = clamp(
      Math.floor(finite(options.gravitySamples) ?? DEFAULT_OPTIONS.gravitySamples),
      1,
      samples.length,
    )
    const candidates = worldAccelerations
      .slice(0, gravitySampleCount)
      .filter((_, index) => !accelerationInfo[index].isLinear)
      .filter((vector) => {
        const length = magnitude(vector)
        return length > STANDARD_GRAVITY_MPS2 * 0.35 && length < STANDARD_GRAVITY_MPS2 * 1.75
      })
    gravityVector = average(candidates)
  }
  gravityVector ??= [0, 0, 0]

  let linearAccelerations = worldAccelerations.map((vector, index) => (
    options.removeGravity && !accelerationInfo[index].isLinear
      ? subtract(vector, gravityVector)
      : vector
  ))

  const calibrationCount = clamp(
    Math.floor(finite(options.calibrationSamples) ?? DEFAULT_OPTIONS.calibrationSamples),
    0,
    samples.length,
  )
  if (calibrationCount > 0) {
    const bias = average(linearAccelerations.slice(0, calibrationCount))
    linearAccelerations = linearAccelerations.map((vector) => subtract(vector, bias))
  }

  const smoothing = clamp(
    finite(options.smoothingFactor) ?? DEFAULT_OPTIONS.smoothingFactor,
    0,
    1,
  )
  const deadband = Math.max(
    0,
    finite(options.accelerationDeadband) ?? DEFAULT_OPTIONS.accelerationDeadband,
  )
  const filteredAccelerations = linearAccelerations.reduce((result, vector, index) => {
    const filtered = index === 0
      ? vector
      : add(scale(vector, smoothing), scale(result[index - 1], 1 - smoothing))
    result.push(magnitude(filtered) < deadband ? [0, 0, 0] : filtered)
    return result
  }, [])

  const initialVelocity = toVector3(options.initialVelocity) ?? [0, 0, 0]
  let velocities = filteredAccelerations.reduce((result, acceleration, index) => {
    if (index === 0) {
      result.push([...initialVelocity])
      return result
    }
    const averageAcceleration = scale(add(filteredAccelerations[index - 1], acceleration), 0.5)
    result.push(add(result[index - 1], scale(averageAcceleration, deltas[index])))
    return result
  }, [])

  if (options.zeroVelocityAtEnd && samples.length > 2 && times.at(-1) > 0) {
    const desiredEndVelocity = toVector3(options.endVelocity) ?? [0, 0, 0]
    const endError = subtract(velocities.at(-1), desiredEndVelocity)
    const duration = times.at(-1)
    velocities = velocities.map((velocity, index) => (
      subtract(velocity, scale(endError, times[index] / duration))
    ))
  }

  const initialPosition = toVector3(options.initialPosition) ?? [0, 0, 0]
  let positions = velocities.reduce((result, velocity, index) => {
    if (index === 0) {
      result.push([...initialPosition])
      return result
    }
    const averageVelocity = scale(add(velocities[index - 1], velocity), 0.5)
    result.push(add(result[index - 1], scale(averageVelocity, deltas[index])))
    return result
  }, [])

  const requestedImpactIndex = finite(options.impactIndex)
  const impactIndex = requestedImpactIndex === null
    ? detectImpactIndex(samples, filteredAccelerations)
    : clamp(Math.round(requestedImpactIndex), 0, samples.length - 1)
  if (options.anchorAtImpact && impactIndex >= 0) {
    const impactPosition = positions[impactIndex]
    positions = positions.map((position) => subtract(position, impactPosition))
  }

  const outputScale = finite(options.outputScale) ?? DEFAULT_OPTIONS.outputScale
  const pathPoints = positions.map((position) => scale(position, outputScale))
  return {
    pathPoints,
    path_points: pathPoints,
    velocities,
    accelerations: filteredAccelerations,
    orientations,
    timestamps: times,
    impactIndex,
    durationSeconds: times.at(-1),
  }
}

/** Convenience API used by visual components that only need `[x, y, z]`. */
export function reconstructPath(samples, options) {
  return reconstructSwing(samples, options).pathPoints
}

export const reconstructPathFromIMU = reconstructPath

export default reconstructPath
