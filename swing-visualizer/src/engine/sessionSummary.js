function yardsFromSwing(swing) {
  return Math.round((swing?.estimated_distance_m ?? 0) * 1.09361)
}

function clubMphFromSwing(swing) {
  if (Number.isFinite(swing?.club_speed_mph)) return swing.club_speed_mph
  return (swing?.club_speed_kmh ?? 0) * 0.621371
}

function ballMphFromSwing(swing) {
  if (Number.isFinite(swing?.ball_speed_mph)) return swing.ball_speed_mph
  const club = clubMphFromSwing(swing)
  return club > 0 ? club * 1.37 : 0
}

function smashFromSwing(swing) {
  const club = clubMphFromSwing(swing)
  const ball = ballMphFromSwing(swing)
  if (club <= 0 || ball <= 0) return null
  return ball / club
}

function avg(values) {
  if (!values.length) return null
  return values.reduce((sum, value) => sum + value, 0) / values.length
}

/** Build a rich session summary from captured swings. */
export function buildSessionSummary(swings, { club = '7 Iron', when = 'Just now' } = {}) {
  const list = Array.isArray(swings) ? swings.filter(Boolean) : []
  const scores = list.map((item) => Number(item.impact_quality) || 0)
  const carries = list.map(yardsFromSwing)
  const ballSpeeds = list.map(ballMphFromSwing).filter((value) => value > 0)
  const clubSpeeds = list.map(clubMphFromSwing).filter((value) => value > 0)
  const smashes = list.map(smashFromSwing).filter((value) => Number.isFinite(value))
  const attacks = list.map((item) => Number(item.attack_angle_deg)).filter(Number.isFinite)
  const paths = list.map((item) => Number(item.swing_path_deg)).filter(Number.isFinite)
  const heels = list.map((item) => Number(item.heel_pressure_pct)).filter(Number.isFinite)
  const centers = list.map((item) => Number(item.center_pressure_pct)).filter(Number.isFinite)
  const toes = list.map((item) => Number(item.toe_pressure_pct)).filter(Number.isFinite)
  const radarHits = list.filter((item) => item.radar_valid).length
  const centered = list.filter((item) => {
    const zone = Number(item.impact_zone)
    return Number.isFinite(zone) && zone >= 2 && zone <= 3
  }).length

  const average = scores.length ? Math.round(avg(scores)) : 0
  const bestCarry = carries.length ? Math.max(...carries) : 0

  return {
    id: Date.now(),
    club,
    distance: `${bestCarry} yds`,
    score: average,
    swings: list.length,
    when,
    tone: average >= 85 ? 'great' : average >= 65 ? 'good' : 'warm',
    bestCarryYds: bestCarry,
    avgBallMph: ballSpeeds.length ? Math.round(avg(ballSpeeds)) : null,
    bestBallMph: ballSpeeds.length ? Math.round(Math.max(...ballSpeeds)) : null,
    avgClubMph: clubSpeeds.length ? Math.round(avg(clubSpeeds)) : null,
    avgSmash: smashes.length ? Number(avg(smashes).toFixed(2)) : null,
    radarHitPct: list.length ? Math.round((radarHits / list.length) * 100) : 0,
    avgAttackDeg: attacks.length ? Number(avg(attacks).toFixed(1)) : null,
    avgPathDeg: paths.length ? Number(avg(paths).toFixed(1)) : null,
    avgHeelPct: heels.length ? Math.round(avg(heels)) : null,
    avgCenterPct: centers.length ? Math.round(avg(centers)) : null,
    avgToePct: toes.length ? Math.round(avg(toes)) : null,
    centeredPct: list.length ? Math.round((centered / list.length) * 100) : 0,
    swingSnapshots: list.slice(-8).map((item, index) => ({
      n: list.length - Math.min(list.length, 8) + index + 1,
      score: Math.round(item.impact_quality || 0),
      carryYds: yardsFromSwing(item),
      ballMph: Math.round(ballMphFromSwing(item)),
      clubMph: Math.round(clubMphFromSwing(item)),
      smash: smashFromSwing(item) != null ? Number(smashFromSwing(item).toFixed(2)) : null,
      attack: Number.isFinite(item.attack_angle_deg) ? Number(item.attack_angle_deg).toFixed(1) : null,
      path: Number.isFinite(item.swing_path_deg) ? Number(item.swing_path_deg).toFixed(1) : null,
      radar: Boolean(item.radar_valid),
      zone: Number.isFinite(item.impact_zone) ? item.impact_zone : null,
      heel: item.heel_pressure_pct ?? null,
      center: item.center_pressure_pct ?? null,
      toe: item.toe_pressure_pct ?? null,
    })),
  }
}

export function strikeMetrics(swing) {
  const clubMph = Math.round(clubMphFromSwing(swing))
  const ballMph = Math.round(ballMphFromSwing(swing))
  const smash = smashFromSwing(swing)
  return {
    clubMph,
    ballMph,
    smash: smash != null ? Number(smash.toFixed(2)) : null,
    carryYds: yardsFromSwing(swing),
    attack: Number.isFinite(swing?.attack_angle_deg) ? Number(swing.attack_angle_deg).toFixed(1) : '0.0',
    path: Number.isFinite(swing?.swing_path_deg) ? Number(swing.swing_path_deg).toFixed(1) : '0.0',
    quality: Math.round(swing?.impact_quality ?? 0),
    heel: swing?.heel_pressure_pct ?? 0,
    center: swing?.center_pressure_pct ?? 0,
    toe: swing?.toe_pressure_pct ?? 0,
    radarValid: Boolean(swing?.radar_valid),
    radarDist: Number.isFinite(swing?.radar_distance_mm) ? swing.radar_distance_mm : null,
    radarIntra: Number.isFinite(swing?.radar_intra_score) ? swing.radar_intra_score : null,
  }
}
