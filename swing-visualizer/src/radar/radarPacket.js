/**
 * Radar bridge stream from a dedicated ESP32 + XM125.
 * Line format:
 *   GMRADAR,<timestamp_ms>,<speed_mph>,<dist_mm>,<intra>,<inter>,<valid>
 */

export function parseGmradarLine(line) {
  const trimmed = String(line ?? '').trim()
  const match = /^GMRADAR,([^,]+),([^,]+),([^,]+),([^,]+),([^,]+),([^,]+)$/i.exec(trimmed)
  if (!match) return null

  const timestamp_ms = Number(match[1])
  const speed_mph = Number(match[2])
  const distance_mm = Number(match[3])
  const intra_score = Number(match[4])
  const inter_score = Number(match[5])
  const valid = Number(match[6]) === 1

  return {
    source: 'radar',
    preview: true,
    label: 'Radar Track',
    timestamp_ms: Number.isFinite(timestamp_ms) ? timestamp_ms : Date.now(),
    ball_speed_mph: Number.isFinite(speed_mph) ? speed_mph : 0,
    ball_speed_kmh: Number.isFinite(speed_mph) ? speed_mph * 1.60934 : 0,
    radar_distance_mm: Number.isFinite(distance_mm) ? Math.round(distance_mm) : 0,
    radar_intra_score: Number.isFinite(intra_score) ? Math.round(intra_score) : 0,
    radar_inter_score: Number.isFinite(inter_score) ? Math.round(inter_score) : 0,
    radar_valid: valid && Number.isFinite(speed_mph) && speed_mph > 0,
  }
}

/** Merge latest radar sample onto a mat swing within a time window. */
export function mergeRadarIntoSwing(swing, radarSample, windowMs = 500) {
  if (!swing || !radarSample?.radar_valid) return swing
  const swingTs = Number(swing.timestamp_ms ?? 0)
  const radarTs = Number(radarSample.timestamp_ms ?? 0)
  if (swingTs && radarTs && Math.abs(swingTs - radarTs) > windowMs) {
    return swing
  }
  return {
    ...swing,
    ball_speed_mph: radarSample.ball_speed_mph,
    ball_speed_kmh: radarSample.ball_speed_kmh,
    radar_distance_mm: radarSample.radar_distance_mm,
    radar_intra_score: radarSample.radar_intra_score,
    radar_inter_score: radarSample.radar_inter_score,
    radar_valid: true,
  }
}
