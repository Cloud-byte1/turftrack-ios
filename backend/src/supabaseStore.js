import { getSupabase } from './supabase.js'

/** Calls an app_store_lockdown.sql function; runs `legacy` if that script has not been applied. */
async function rpcOr(name, args, legacy) {
  const sb = getSupabase()
  const { data, error } = await sb.rpc(name, args)
  if (error) {
    if (error.code === 'PGRST202' || /Could not find the function/i.test(error.message || '')) return legacy()
    throw error
  }
  return Array.isArray(data) ? data[0] ?? null : data
}

function mapChallengeRow(data) {
  if (!data) return null
  return {
    id: data.id,
    title: data.title,
    detail: data.detail,
    progress: data.progress,
    target: data.target,
    joined: data.joined,
    reward: data.reward,
  }
}

function mapFeedRow(data) {
  if (!data) return null
  return { id: data.id, author: data.author, text: data.text, when: data.when_label, likes: data.likes }
}

const FALLBACK_EVENTS = [
  {
    id: 'ev_tuesday',
    title: 'Tuesday range night',
    detail: 'Open bay with live mat + radar scoring.',
    when: 'Tue 6:00–8:00 PM',
    place: 'Bay 3 · Strike Lab Range',
    attendees: 7,
    rsvped: true,
  },
  {
    id: 'ev_sat',
    title: 'Saturday smash factor clinic',
    detail: 'Radar-only session focused on ball speed.',
    when: 'Sat 10:00 AM',
    place: 'Bay 1',
    attendees: 4,
    rsvped: false,
  },
]

function mapSessionRow(row) {
  if (!row) return null
  return {
    id: row.id,
    createdAt: row.created_at,
    club: row.club,
    when: row.when_label || 'Just now',
    distance: row.distance,
    score: row.score,
    swings: row.swings,
    tone: row.tone,
    bestCarryYds: row.best_carry_yds,
    avgBallMph: row.avg_ball_mph,
    bestBallMph: row.best_ball_mph,
    avgClubMph: row.avg_club_mph,
    avgSmash: row.avg_smash,
    radarHitPct: row.radar_hit_pct,
    avgAttackDeg: row.avg_attack_deg,
    avgPathDeg: row.avg_path_deg,
    avgHeelPct: row.avg_heel_pct,
    avgCenterPct: row.avg_center_pct,
    avgToePct: row.avg_toe_pct,
    centeredPct: row.centered_pct,
    swingSnapshots: row.swing_snapshots || [],
    rawSwings: row.raw_swings || [],
  }
}

function mapProfileRow(row) {
  if (!row) return null
  return {
    id: row.id,
    displayName: row.display_name,
    handle: row.handle,
    initials: row.initials,
    homeClub: row.home_club,
    handicap: Number(row.handicap),
    preferredClubs: row.preferred_clubs || [],
    bio: row.bio || '',
    location: row.location || '',
    streakDays: row.streak_days || 0,
    goals: {
      targetHandicap: Number(row.target_handicap),
      weeklySessions: row.weekly_sessions,
      focusClub: row.focus_club,
    },
    stats: {
      totalSessions: 0,
      totalSwings: 0,
      bestScore: null,
      avgScore: null,
      bestCarryYds: null,
      avgBallMph: null,
    },
  }
}

async function withSessionStats(profile) {
  if (!profile) return profile
  const sb = getSupabase()
  const { data: sessions } = await sb.from('sessions').select('score, swings, best_carry_yds, avg_ball_mph')
  const list = sessions || []
  const scores = list.map((s) => Number(s.score)).filter((n) => n > 0)
  const carries = list.map((s) => Number(s.best_carry_yds)).filter((n) => n > 0)
  const balls = list.map((s) => Number(s.avg_ball_mph)).filter((n) => n > 0)
  return {
    ...profile,
    stats: {
      totalSessions: list.length,
      totalSwings: list.reduce((sum, s) => sum + (Number(s.swings) || 0), 0),
      bestScore: scores.length ? Math.max(...scores) : null,
      avgScore: scores.length ? Math.round(scores.reduce((a, b) => a + b, 0) / scores.length) : null,
      bestCarryYds: carries.length ? Math.max(...carries) : null,
      avgBallMph: balls.length ? Math.round(balls.reduce((a, b) => a + b, 0) / balls.length) : null,
    },
  }
}

export async function listSessions() {
  const sb = getSupabase()
  const { data, error } = await sb.from('sessions').select('*').order('created_at', { ascending: false })
  if (error) throw error
  return (data || []).map(mapSessionRow)
}

export async function getSession(id) {
  const sb = getSupabase()
  const { data, error } = await sb.from('sessions').select('*').eq('id', id).maybeSingle()
  if (error) throw error
  return mapSessionRow(data)
}

export async function createSession(payload = {}) {
  const sb = getSupabase()
  const row = {
    club: payload.club || '7 Iron',
    when_label: payload.when || 'Just now',
    distance: payload.distance || '0 yds',
    score: Number(payload.score) || 0,
    swings: Number(payload.swings) || 0,
    tone: payload.tone || 'warm',
    best_carry_yds: payload.bestCarryYds ?? null,
    avg_ball_mph: payload.avgBallMph ?? null,
    best_ball_mph: payload.bestBallMph ?? null,
    avg_club_mph: payload.avgClubMph ?? null,
    avg_smash: payload.avgSmash ?? null,
    radar_hit_pct: payload.radarHitPct ?? 0,
    avg_attack_deg: payload.avgAttackDeg ?? null,
    avg_path_deg: payload.avgPathDeg ?? null,
    avg_heel_pct: payload.avgHeelPct ?? null,
    avg_center_pct: payload.avgCenterPct ?? null,
    avg_toe_pct: payload.avgToePct ?? null,
    centered_pct: payload.centeredPct ?? 0,
    swing_snapshots: payload.swingSnapshots || [],
    raw_swings: payload.rawSwings || [],
  }
  const { data, error } = await sb.from('sessions').insert(row).select('*').single()
  if (error) throw error
  return mapSessionRow(data)
}

export async function deleteSession(id) {
  const sb = getSupabase()
  const { error, count } = await sb.from('sessions').delete({ count: 'exact' }).eq('id', id)
  if (error) throw error
  return (count || 0) > 0
}

export async function clearSessions() {
  const sb = getSupabase()
  const { error } = await sb.from('sessions').delete().neq('id', '00000000-0000-0000-0000-000000000000')
  if (error) throw error
}

export async function getProfile() {
  const sb = getSupabase()
  const { data, error } = await sb.from('profiles').select('*').order('created_at', { ascending: true }).limit(1).maybeSingle()
  if (error) throw error
  return withSessionStats(mapProfileRow(data))
}

export async function updateProfile(patch = {}) {
  const sb = getSupabase()
  const current = await getProfile()
  if (!current?.id) throw new Error('No profile row — run schema.sql seed first')

  const displayName = patch.displayName ?? current.displayName
  const parts = String(displayName).trim().split(/\s+/)
  const initials = ((parts[0]?.[0] || 'C') + (parts[1]?.[0] || parts[0]?.[1] || 'M')).toUpperCase()

  const row = {
    display_name: displayName,
    handle: patch.handle ?? current.handle,
    initials,
    home_club: patch.homeClub ?? current.homeClub,
    handicap: patch.handicap ?? current.handicap,
    preferred_clubs: patch.preferredClubs ?? current.preferredClubs,
    bio: patch.bio ?? current.bio,
    location: patch.location ?? current.location,
    streak_days: patch.streakDays ?? current.streakDays,
    target_handicap: patch.goals?.targetHandicap ?? current.goals.targetHandicap,
    weekly_sessions: patch.goals?.weeklySessions ?? current.goals.weeklySessions,
    focus_club: patch.goals?.focusClub ?? current.goals.focusClub,
    updated_at: new Date().toISOString(),
  }

  const data = await rpcOr('update_profile', {
    p_display_name: row.display_name,
    p_handle: row.handle,
    p_handicap: row.handicap,
    p_bio: row.bio,
    p_location: row.location,
    p_preferred_clubs: row.preferred_clubs,
    p_streak_days: row.streak_days,
  }, async () => {
    const { data: updated, error } = await sb.from('profiles').update(row).eq('id', current.id).select('*').single()
    if (error) throw error
    await sb.from('clubhouse_members').update({
      name: row.display_name,
      handle: row.handle,
      initials: row.initials,
      handicap: row.handicap,
      streak: row.streak_days,
    }).eq('is_you', true)
    return updated
  })

  return withSessionStats(mapProfileRow(data))
}

export async function getClubhouse() {
  const sb = getSupabase()
  const [members, challenges, feed, announcements, events, profile] = await Promise.all([
    sb.from('clubhouse_members').select('*').order('rank', { ascending: true }),
    sb.from('clubhouse_challenges').select('*'),
    sb.from('clubhouse_feed').select('*').order('created_at', { ascending: false }),
    sb.from('clubhouse_announcements').select('*').order('created_at', { ascending: false }),
    sb.from('clubhouse_events').select('*').order('created_at', { ascending: true }),
    getProfile(),
  ])

  if (members.error) throw members.error
  if (challenges.error) throw challenges.error
  if (feed.error) throw feed.error
  if (announcements.error) throw announcements.error

  const mappedMembers = (members.data || []).map((m) => ({
    id: m.id,
    name: m.name,
    handle: m.handle,
    initials: m.initials,
    handicap: Number(m.handicap),
    rank: m.rank,
    score: m.score,
    swings: m.swings,
    streak: m.streak,
    isYou: Boolean(m.is_you),
  }))

  return {
    name: 'Strike Lab Clubhouse',
    tagline: 'Range rats chasing pure contact',
    members: mappedMembers,
    challenges: (challenges.data || []).map((c) => ({
      id: c.id,
      title: c.title,
      detail: c.detail,
      progress: c.progress,
      target: c.target,
      endsAt: c.ends_at,
      joined: c.joined,
      reward: c.reward,
    })),
    feed: (feed.data || []).map((p) => ({
      id: p.id,
      author: p.author,
      text: p.text,
      when: p.when_label,
      likes: p.likes,
    })),
    announcements: (announcements.data || []).map((a) => ({
      id: a.id,
      title: a.title,
      body: a.body,
    })),
    events: !events.error && events.data?.length
      ? events.data.map((e) => ({
        id: e.id,
        title: e.title,
        detail: e.detail,
        when: e.when_label,
        place: e.place,
        attendees: e.attendees,
        rsvped: e.rsvped,
      }))
      : FALLBACK_EVENTS.map((e) => ({ ...e })),
    badges: [
      { id: 'b_streak', label: '12-day streak', icon: '🔥', earned: true },
      { id: 'b_radar', label: 'Radar locked', icon: '📡', earned: true },
      { id: 'b_center', label: 'Center face', icon: '◎', earned: false },
    ],
    you: mappedMembers.find((m) => m.isYou) || null,
    profile,
  }
}

export async function bumpChallenge(challengeId) {
  const sb = getSupabase()
  const data = await rpcOr('log_challenge_progress', { p_id: challengeId }, async () => {
    const { data: current, error: readError } = await sb
      .from('clubhouse_challenges')
      .select('*')
      .eq('id', challengeId)
      .maybeSingle()
    if (readError) throw readError
    if (!current) return null
    const nextProgress = Math.min(current.target || 1, (current.progress || 0) + 1)
    const { data: updated, error } = await sb
      .from('clubhouse_challenges')
      .update({ joined: true, progress: nextProgress })
      .eq('id', challengeId)
      .select('*')
      .maybeSingle()
    if (error) throw error
    return updated
  })
  return mapChallengeRow(data)
}

export async function rsvpEvent(eventId) {
  const data = await rpcOr('rsvp_event', { p_id: eventId }, async () => {
    const event = FALLBACK_EVENTS.find((item) => item.id === eventId)
    if (!event) return null
    return { ...event, when_label: event.when, rsvped: true, attendees: event.attendees + (event.rsvped ? 0 : 1) }
  })
  if (!data) return null
  return {
    id: data.id,
    title: data.title,
    detail: data.detail,
    when: data.when_label,
    place: data.place,
    attendees: data.attendees,
    rsvped: data.rsvped,
  }
}

export async function joinChallenge(challengeId) {
  const sb = getSupabase()
  const data = await rpcOr('join_challenge', { p_id: challengeId }, async () => {
    const { data: updated, error } = await sb
      .from('clubhouse_challenges')
      .update({ joined: true })
      .eq('id', challengeId)
      .select('*')
      .maybeSingle()
    if (error) throw error
    return updated
  })
  return mapChallengeRow(data)
}

export async function addFeedPost({ author, text }) {
  const sb = getSupabase()
  const body = String(text || '').trim()
  if (!body) return null
  const { data, error } = await sb.from('clubhouse_feed').insert({
    author: author || 'Golfer',
    text: body,
    when_label: 'Just now',
    likes: 0,
  }).select('*').single()
  if (error) throw error
  return {
    id: data.id,
    author: data.author,
    text: data.text,
    when: data.when_label,
    likes: data.likes,
  }
}

export async function likeFeedPost(postId) {
  const sb = getSupabase()
  const data = await rpcOr('like_post', { p_id: postId }, async () => {
    const { data: current, error: readError } = await sb.from('clubhouse_feed').select('*').eq('id', postId).maybeSingle()
    if (readError) throw readError
    if (!current) return null
    const { data: updated, error } = await sb
      .from('clubhouse_feed')
      .update({ likes: (current.likes || 0) + 1 })
      .eq('id', postId)
      .select('*')
      .single()
    if (error) throw error
    return updated
  })
  return mapFeedRow(data)
}
