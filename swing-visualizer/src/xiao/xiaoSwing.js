import { reconstructSwing } from '../engine/PathReconstructor.js'
import { buildGolfSwingPath } from '../engine/SwingArc.js'
import { normalizePressurePercentages } from '../engine/SwingSimulator.js'

const MAX_SAMPLES = 400 // ~4s at 100 Hz

function clamp(value, min, max) {
  return Math.min(max, Math.max(min, value))
}

function magnitude(sample) {
  const ax = sample.ax ?? 0
  const ay = sample.ay ?? 0
  const az = sample.az ?? 0
  return Math.hypot(ax, ay, az)
}

/**
 * Build a visualizer swing object from buffered XIAO IMU samples.
 */
export function swingFromXiaoSamples(samples, options = {}) {
  if (!Array.isArray(samples) || samples.length < 5) {
    throw new Error('Need at least 5 IMU samples for a XIAO swing')
  }

  const reconstruction = reconstructSwing(samples, {
    sampleRateHz: options.sampleRateHz ?? 100,
    accelerationUnit: 'g',
    gyroUnit: 'deg/s',
    removeGravity: true,
    anchorAtImpact: true,
    outputScale: options.outputScale ?? 1.2,
  })

  const impactIndex = reconstruction.impactIndex >= 0
    ? reconstruction.impactIndex
    : Math.floor(samples.length / 2)
  const impactSample = samples[impactIndex] ?? samples[Math.floor(samples.length / 2)]
  const peakG = Math.max(...samples.map(magnitude))
  const quality = clamp(Math.round((peakG - 1) * 28), 20, 100)

  // Rough path angle from lateral displacement around impact.
  const path = reconstruction.path_points
  const pre = path[Math.max(0, impactIndex - 2)] ?? path[0]
  const post = path[Math.min(path.length - 1, impactIndex + 2)] ?? path.at(-1)
  const swingPathDeg = Number(
    (Math.atan2((post?.[2] ?? 0) - (pre?.[2] ?? 0), Math.max(0.05, (post?.[0] ?? 0) - (pre?.[0] ?? 0)))
      * (180 / Math.PI)).toFixed(2),
  )
  const attackAngleDeg = Number(
    (Math.atan2((post?.[1] ?? 0) - (pre?.[1] ?? 0), Math.max(0.05, Math.abs((post?.[0] ?? 0) - (pre?.[0] ?? 0))))
      * (180 / Math.PI)).toFixed(2),
  )

  const pressure = normalizePressurePercentages({ heel: 30, center: 40, toe: 30 })
  const clubSpeed = clamp(Math.round(70 + peakG * 18), 60, 180)
  const arc = buildGolfSwingPath({
    sampleCount: 56,
    swingPathDeg,
    attackAngleDeg,
    topHeight: 1.2 + Math.min(0.5, peakG * 0.12),
    quality,
  })

  return {
    label: 'Live XIAO Swing',
    source: 'xiao',
    timestamp_ms: impactSample.timestamp_ms ?? Date.now(),
    fsr_peaks: [80, 85, 120, 118, 82, 78],
    impact_quality: quality,
    contact_zone_label: 2,
    impact_zone: 2,
    impact_duration_us: 400,
    heel_pressure_pct: pressure.heelPct,
    center_pressure_pct: pressure.centerPct,
    toe_pressure_pct: pressure.toePct,
    direction_label: Math.abs(swingPathDeg) < 2
      ? 'Straight'
      : swingPathDeg < 0
        ? 'Left'
        : 'Right',
    estimated_distance_m: Math.round(50 + quality * 1.4),
    club_speed_kmh: clubSpeed,
    swing_path_deg: swingPathDeg,
    attack_angle_deg: attackAngleDeg,
    path_points: arc.path_points,
    hand_points: arc.hand_points,
    top_of_swing: arc.top_of_swing,
    follow_through: arc.follow_through,
    raw: {
      sampleCount: samples.length,
      peakG,
      impactIndex,
      durationSeconds: reconstruction.durationSeconds,
    },
  }
}

export function parseXiaoLine(line) {
  const trimmed = String(line ?? '').trim()
  if (!trimmed) return null

  if (trimmed.startsWith('GMREADY')) {
    return { type: 'ready', raw: trimmed }
  }
  if (trimmed.startsWith('GMERR')) {
    return { type: 'error', message: trimmed, raw: trimmed }
  }
  if (trimmed.startsWith('GMIMPACT')) {
    const parts = trimmed.split(',')
    return {
      type: 'impact',
      timestamp_ms: Number(parts[1]) || Date.now(),
      raw: trimmed,
    }
  }
  if (trimmed.startsWith('GMIMU')) {
    const parts = trimmed.split(',')
    if (parts.length < 8) return null
    const sample = {
      timestamp_ms: Number(parts[1]),
      ax: Number(parts[2]),
      ay: Number(parts[3]),
      az: Number(parts[4]),
      gx: Number(parts[5]),
      gy: Number(parts[6]),
      gz: Number(parts[7]),
      acceleration_unit: 'g',
      gyro_unit: 'deg/s',
    }
    if (![sample.ax, sample.ay, sample.az, sample.gx, sample.gy, sample.gz]
      .every(Number.isFinite)) {
      return null
    }
    return { type: 'imu', sample, raw: trimmed }
  }
  return null
}

/**
 * Ring-buffer helper used by the serial client.
 */
export class XiaoImuBuffer {
  constructor(limit = MAX_SAMPLES) {
    this.limit = limit
    this.samples = []
  }

  push(sample) {
    this.samples.push(sample)
    if (this.samples.length > this.limit) {
      this.samples.splice(0, this.samples.length - this.limit)
    }
  }

  /** Window around impact timestamp (ms), default 1.2s before / 0.6s after. */
  windowAround(timestampMs, beforeMs = 1200, afterMs = 600) {
    const start = timestampMs - beforeMs
    const end = timestampMs + afterMs
    const window = this.samples.filter((sample) => (
      sample.timestamp_ms >= start && sample.timestamp_ms <= end
    ))
    return window.length >= 5 ? window : [...this.samples]
  }

  clear() {
    this.samples = []
  }
}
