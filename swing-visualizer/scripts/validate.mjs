import assert from 'node:assert/strict'

import {
  BLE_SWING_PACKET_BYTES,
  decodeGmswingLine,
  decodeSwingNotification,
  parseBleSwingPacket,
} from '../src/ble/packet.js'
import { REFERENCE_SWINGS } from '../src/data/referenceSwings.js'
import { reconstructSwing } from '../src/engine/PathReconstructor.js'
import { getPathColor, gradeSwing } from '../src/engine/SwingGrader.js'
import {
  SWING_PRESET_KEYS,
  SWING_PRESETS,
  generateRandomSwing,
} from '../src/engine/SwingSimulator.js'
import { parseXiaoLine, swingFromXiaoSamples } from '../src/xiao/xiaoSwing.js'

for (const presetKey of SWING_PRESET_KEYS) {
  const swing = SWING_PRESETS[presetKey]
  assert.equal(swing.fsr_peaks.length, 6, `${presetKey} should have six sensors`)
  assert.equal(
    swing.heel_pressure_pct + swing.center_pressure_pct + swing.toe_pressure_pct,
    100,
    `${presetKey} pressure should total 100`,
  )
  assert.ok(swing.path_points.every((point) => point.length === 3 && point.every(Number.isFinite)))
}
assert.equal(
  new Set(SWING_PRESET_KEYS.map((key) => JSON.stringify(SWING_PRESETS[key].path_points))).size,
  SWING_PRESET_KEYS.length,
  'every preset should have a distinct 3D path',
)

const randomA = generateRandomSwing({ seed: 'turftrack-a' })
const randomARepeat = generateRandomSwing({ seed: 'turftrack-a' })
const randomB = generateRandomSwing({ seed: 'turftrack-b' })
assert.deepEqual(randomA, randomARepeat, 'seeded random swings should repeat')
assert.notDeepEqual(randomA, randomB, 'different seeds should produce different swings')
assert.equal(
  randomA.heel_pressure_pct + randomA.center_pressure_pct + randomA.toe_pressure_pct,
  100,
)
assert.ok(Number.isFinite(randomA.ball_speed_mph), 'random swings include ball speed')
assert.ok(randomA.ball_speed_mph < 150, 'random ball speed stays below tour-level')
assert.ok(
  Math.round((randomA.estimated_distance_m || 0) * 1.09361) < 160,
  'random carry should usually sit below a flat 150–160 yd look',
)

const varied = Array.from({ length: 12 }, (_, index) => generateRandomSwing({ seed: `vary-${index}` }))
const carries = new Set(varied.map((swing) => Math.round((swing.estimated_distance_m || 0) * 1.09361)))
const qualities = varied.map((swing) => swing.impact_quality)
assert.ok(carries.size >= 6, 'random carries should vary across seeds')
assert.ok(
  qualities.reduce((sum, value) => sum + value, 0) / qualities.length < 62,
  'random quality should average below mid-pack',
)

const perfectGrade = gradeSwing(SWING_PRESETS.perfect, REFERENCE_SWINGS.iron7)
const heelGrade = gradeSwing(SWING_PRESETS.heel_strike, REFERENCE_SWINGS.iron7)
const thinGrade = gradeSwing(SWING_PRESETS.thin_hit, REFERENCE_SWINGS.iron7)
assert.equal(perfectGrade.overallScore, 100)
assert.equal(perfectGrade.corrections.length, 0)
assert.ok(heelGrade.corrections.length > 0)
assert.equal(thinGrade.impactGrade, 'red')
assert.notEqual(
  getPathColor(3, 8, perfectGrade),
  getPathColor(3, 8, thinGrade),
  'graded swing colors should change with swing quality',
)
assert.equal(getPathColor(7, 8, perfectGrade), '#64748b', 'follow-through should be grey')
assert.equal(getPathColor(2, 8, perfectGrade), '#22c55e', 'pre-impact swing should be green when good')


const imuSamples = Array.from({ length: 10 }, (_, index) => ({
  linearAcceleration: [index < 5 ? 2 : -1, index / 20, 0],
  dt_s: 0.01,
  impact: index === 5,
}))
const reconstruction = reconstructSwing(imuSamples, {
  removeGravity: false,
  zeroVelocityAtEnd: false,
})
assert.equal(reconstruction.pathPoints.length, imuSamples.length)
assert.deepEqual(reconstruction.pathPoints[reconstruction.impactIndex], [0, 0, 0])
assert.ok(reconstruction.pathPoints.flat().every(Number.isFinite))

const packet = new ArrayBuffer(BLE_SWING_PACKET_BYTES)
const view = new DataView(packet)
view.setUint32(0, 123456, true)
;[120, 130, 200, 190, 110, 100].forEach((peak, index) => {
  view.setUint16(4 + index * 2, peak, true)
})
view.setUint16(16, 450, true)
view.setUint8(18, 2)
view.setUint8(19, 92)
view.setUint8(20, 2)
view.setUint16(21, 170, true)
view.setUint8(23, 48)
view.setUint8(24, 0)
view.setInt16(25, 100, true)
view.setInt16(27, -50, true)
view.setInt16(29, -800, true)
view.setInt16(31, 1200, true)
view.setInt16(33, -400, true)
view.setInt16(35, 300, true)
view.setInt16(37, -15, true)
view.setUint8(39, 2)
view.setUint8(40, 0)
view.setUint8(41, 28)
view.setUint8(42, 46)
view.setUint8(43, 26)
view.setUint8(44, 0)
view.setInt16(45, 875, true)  // 87.5 mph
view.setInt16(47, 1200, true) // 1200 mm
view.setUint16(49, 4200, true) // intra score
view.setUint8(51, 1)

const parsed = parseBleSwingPacket(packet)
assert.equal(parsed.timestamp_ms, 123456)
assert.deepEqual(parsed.fsr_peaks, [120, 130, 200, 190, 110, 100])
assert.equal(parsed.impact_quality, 92)
assert.equal(parsed.yaw_deg10, -15)
assert.equal(parsed.radar_speed_mph10, 875)
assert.equal(parsed.radar_distance_mm, 1200)
assert.equal(parsed.radar_intra_score, 4200)
assert.equal(parsed.radar_valid, 1)

const liveSwing = decodeSwingNotification(packet)
const liveGrade = gradeSwing(liveSwing, REFERENCE_SWINGS.iron7)
assert.equal(liveSwing.label, 'Live Swing')
assert.equal(liveSwing.source, 'ble')

const hex = [...new Uint8Array(packet)].map((b) => b.toString(16).padStart(2, '0')).join('')
const usbSwing = decodeGmswingLine(`GMSWING ${hex}`, { source: 'usb' })
assert.equal(usbSwing.source, 'usb')
assert.equal(usbSwing.impact_quality, 92)
assert.equal(
  liveSwing.heel_pressure_pct + liveSwing.center_pressure_pct + liveSwing.toe_pressure_pct,
  100,
)
assert.ok(liveGrade.overallScore > 0)
assert.ok(liveSwing.path_points.length >= 5)

const xiaoSamples = Array.from({ length: 40 }, (_, index) => ({
  timestamp_ms: index * 10,
  ax: index === 20 ? 3.2 : 0.05,
  ay: index === 20 ? -0.4 : 0.02,
  az: index === 20 ? 0.8 : 1.0,
  gx: index < 20 ? 40 : -20,
  gy: 5,
  gz: index < 20 ? -10 : 8,
  acceleration_unit: 'g',
  gyro_unit: 'deg/s',
}))
const xiaoSwing = swingFromXiaoSamples(xiaoSamples)
assert.equal(xiaoSwing.source, 'xiao')
assert.ok(xiaoSwing.path_points.length >= 5)
assert.equal(parseXiaoLine('GMIMPACT,123').type, 'impact')
assert.equal(parseXiaoLine('GMIMU,1,0.1,0.2,0.3,1,2,3').type, 'imu')

import { mergeRadarIntoSwing, parseGmradarLine } from '../src/radar/radarPacket.js'
import { buildSessionSummary } from '../src/engine/sessionSummary.js'

const radarSample = parseGmradarLine('GMRADAR,1000,112.5,820,2400,100,1')
assert.equal(radarSample.radar_valid, true)
assert.equal(radarSample.ball_speed_mph, 112.5)
assert.equal(radarSample.radar_distance_mm, 820)

const merged = mergeRadarIntoSwing(
  { timestamp_ms: 1050, impact_quality: 80, ball_speed_mph: 0, radar_valid: false },
  radarSample,
  500,
)
assert.equal(merged.radar_valid, true)
assert.equal(merged.ball_speed_mph, 112.5)

const summary = buildSessionSummary([
  { impact_quality: 90, estimated_distance_m: 140, ball_speed_mph: 120, club_speed_mph: 88, attack_angle_deg: -3, swing_path_deg: 1, heel_pressure_pct: 20, center_pressure_pct: 60, toe_pressure_pct: 20, impact_zone: 2, radar_valid: true },
  { impact_quality: 70, estimated_distance_m: 120, ball_speed_mph: 100, club_speed_mph: 80, attack_angle_deg: -5, swing_path_deg: -2, heel_pressure_pct: 40, center_pressure_pct: 40, toe_pressure_pct: 20, impact_zone: 1, radar_valid: false },
], { club: '7 Iron' })
assert.equal(summary.swings, 2)
assert.equal(summary.score, 80)
assert.equal(summary.radarHitPct, 50)
assert.ok(summary.avgSmash > 1)

console.log('Validated presets, grading, BLE/USB packets, XIAO IMU, and dual radar merge.')
