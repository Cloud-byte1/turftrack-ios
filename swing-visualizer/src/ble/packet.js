/**
 * Decoder for the packed GolfMat BLE swing notify payload
 * (components/comms/ble.h — ble_swing_packet_t).
 */

import { normalizePressurePercentages } from '../engine/SwingSimulator.js'
import { buildGolfSwingPath } from '../engine/SwingArc.js'

export const GOLFMAT_SERVICE_UUID = 0xab12
export const GOLFMAT_SWING_UUID = 0xab13
export const GOLFMAT_DEVICE_NAME = 'GolfMat'
export const BLE_SWING_PACKET_BYTES = 52

const DIRECTION_LABELS = Object.freeze({
  0: 'Straight',
  1: 'Left',
  2: 'Right',
  3: 'Push',
  4: 'Pull',
})

const clamp = (value, min, max) => Math.min(max, Math.max(min, value))

function readU16(view, offset) {
  return view.getUint16(offset, true)
}

function readI16(view, offset) {
  return view.getInt16(offset, true)
}

function directionPathDegrees(direction, yawDeg) {
  if (Number.isFinite(yawDeg) && Math.abs(yawDeg) > 0.15) {
    return clamp(yawDeg, -12, 12)
  }
  switch (direction) {
    case 1:
    case 4:
      return -4.5
    case 2:
    case 3:
      return 4.5
    default:
      return 0.2
  }
}

function estimateAttackAngle(accelZMg, quality) {
  if (Number.isFinite(accelZMg) && Math.abs(accelZMg) > 50) {
    // Negative z (into the ball) → steeper attack.
    return clamp(-accelZMg / 400, -8, 4)
  }
  return clamp(-4.5 + (quality / 100) * 2.5, -7, 3)
}

function estimateClubSpeed(distanceM, quality, gyroMdps, ballSpeedKmh) {
  if (Number.isFinite(ballSpeedKmh) && ballSpeedKmh > 1) {
    return Math.round(clamp(ballSpeedKmh, 60, 250))
  }
  const gyroMag = Math.hypot(gyroMdps[0], gyroMdps[1], gyroMdps[2]) / 1000
  if (gyroMag > 0.3) {
    return Math.round(clamp(70 + gyroMag * 8, 60, 180))
  }
  if (distanceM > 0) {
    return Math.round(clamp(55 + distanceM * 0.55, 60, 180))
  }
  return Math.round(78 + quality * 0.72)
}

function synthesizePath(quality, pathDegrees, attackDegrees) {
  return buildGolfSwingPath({
    sampleCount: 56,
    swingPathDeg: pathDegrees,
    attackAngleDeg: attackDegrees,
    topHeight: 1.25 + (quality / 100) * 0.4,
    quality,
  })
}

/**
 * Parse a raw GATT notification into the structured packet fields.
 * @param {ArrayBuffer|ArrayBufferView} buffer
 */
export function parseBleSwingPacket(buffer) {
  const bytes = buffer instanceof ArrayBuffer
    ? new Uint8Array(buffer)
    : new Uint8Array(buffer.buffer, buffer.byteOffset, buffer.byteLength)

  if (bytes.byteLength < BLE_SWING_PACKET_BYTES) {
    throw new Error(
      `GolfMat packet too short: got ${bytes.byteLength}, need ${BLE_SWING_PACKET_BYTES}`,
    )
  }

  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength)
  const fsrPeaks = Array.from({ length: 6 }, (_, index) => readU16(view, 4 + index * 2))

  return {
    timestamp_ms: view.getUint32(0, true),
    fsr_peaks: fsrPeaks,
    impact_duration_us: readU16(view, 16),
    impact_zone: view.getUint8(18),
    impact_quality: view.getUint8(19),
    contact_zone_label: view.getUint8(20),
    estimated_distance_m: readU16(view, 21),
    consistency_hint: view.getUint8(23),
    flags: view.getUint8(24),
    accel_x_mg: readI16(view, 25),
    accel_y_mg: readI16(view, 27),
    accel_z_mg: readI16(view, 29),
    gyro_x_mdps: readI16(view, 31),
    gyro_y_mdps: readI16(view, 33),
    gyro_z_mdps: readI16(view, 35),
    yaw_deg10: readI16(view, 37),
    strike_zone: view.getUint8(39),
    strike_direction: view.getUint8(40),
    heel_pressure_pct: view.getUint8(41),
    center_pressure_pct: view.getUint8(42),
    toe_pressure_pct: view.getUint8(43),
    direction_penalty: view.getUint8(44),
    radar_speed_mph10: readI16(view, 45),
    radar_distance_mm: readI16(view, 47),
    radar_intra_score: readU16(view, 49),
    radar_valid: view.getUint8(51),
  }
}

/**
 * Convert a parsed BLE packet into the swing object the visualizer expects.
 */
export function packetToSwing(packet, options = {}) {
  const source = options.source ?? 'ble'
  const quality = clamp(packet.impact_quality ?? 0, 0, 100)
  const yawDeg = (packet.yaw_deg10 ?? 0) / 10
  const swingPathDeg = Number(
    directionPathDegrees(packet.strike_direction, yawDeg).toFixed(2),
  )
  const attackAngleDeg = Number(
    estimateAttackAngle(packet.accel_z_mg, quality).toFixed(2),
  )
  const pressure = normalizePressurePercentages({
    heel: packet.heel_pressure_pct,
    center: packet.center_pressure_pct,
    toe: packet.toe_pressure_pct,
  })
  const ballSpeedMph = packet.radar_valid
    ? (packet.radar_speed_mph10 ?? 0) / 10
    : null
  const ballSpeedKmh = Number.isFinite(ballSpeedMph) ? ballSpeedMph * 1.60934 : null
  const clubSpeed = estimateClubSpeed(
    packet.estimated_distance_m,
    quality,
    [packet.gyro_x_mdps, packet.gyro_y_mdps, packet.gyro_z_mdps],
    ballSpeedKmh,
  )
  const directionLabel = DIRECTION_LABELS[packet.strike_direction] ?? 'Straight'
  const zone = clamp(packet.impact_zone ?? packet.strike_zone ?? 2, 0, 5)
  const arc = synthesizePath(quality, swingPathDeg, attackAngleDeg)

  return {
    label: source === 'usb' ? 'Live USB Swing' : 'Live Swing',
    source,
    timestamp_ms: packet.timestamp_ms,
    fsr_peaks: [...packet.fsr_peaks],
    impact_quality: quality,
    contact_zone_label: packet.contact_zone_label ?? packet.strike_zone ?? 2,
    impact_zone: zone,
    impact_duration_us: packet.impact_duration_us,
    heel_pressure_pct: pressure.heelPct,
    center_pressure_pct: pressure.centerPct,
    toe_pressure_pct: pressure.toePct,
    direction_label: directionLabel,
    estimated_distance_m: packet.estimated_distance_m,
    club_speed_kmh: clubSpeed,
    ball_speed_mph: ballSpeedMph,
    ball_speed_kmh: ballSpeedKmh,
    radar_distance_mm: packet.radar_valid ? packet.radar_distance_mm : null,
    radar_intra_score: packet.radar_valid ? packet.radar_intra_score : null,
    radar_valid: Boolean(packet.radar_valid),
    swing_path_deg: swingPathDeg,
    attack_angle_deg: attackAngleDeg,
    path_points: arc.path_points,
    hand_points: arc.hand_points,
    top_of_swing: arc.top_of_swing,
    follow_through: arc.follow_through,
    raw: packet,
  }
}

export function decodeSwingNotification(buffer, options) {
  return packetToSwing(parseBleSwingPacket(buffer), options)
}

/** Parse a USB/UART line: `GMSWING <hex>` */
export function decodeGmswingLine(line, options = { source: 'usb' }) {
  const trimmed = String(line ?? '').trim()
  const match = /^GMSWING\s+([0-9A-Fa-f]+)$/.exec(trimmed)
  if (!match) return null

  const hex = match[1]
  if (hex.length < BLE_SWING_PACKET_BYTES * 2 || hex.length % 2 !== 0) {
    throw new Error(`Invalid GMSWING hex length: ${hex.length}`)
  }

  const bytes = new Uint8Array(BLE_SWING_PACKET_BYTES)
  for (let index = 0; index < BLE_SWING_PACKET_BYTES; index += 1) {
    bytes[index] = Number.parseInt(hex.slice(index * 2, index * 2 + 2), 16)
  }
  return decodeSwingNotification(bytes, options)
}

