import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const dataDir = path.resolve(__dirname, '../data')
const storePath = path.join(dataDir, 'app.json')

const defaultProfile = {
  id: 'me',
  displayName: 'Carmine',
  handle: 'carmine',
  initials: 'CM',
  homeClub: 'Strike Lab Range',
  handicap: 14.2,
  preferredClubs: ['7 Iron', 'Driver', 'PW'],
  bio: 'Working the mid-irons and getting radar ball speed honest.',
  location: 'Local range',
  streakDays: 12,
  joinedAt: '2026-03-01T00:00:00.000Z',
  goals: {
    targetHandicap: 10,
    weeklySessions: 4,
    focusClub: '7 Iron',
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

const defaultClubhouse = {
  name: 'Strike Lab Clubhouse',
  tagline: 'Range rats chasing pure contact',
  members: [
    { id: 'm1', name: 'Carmine', handle: 'carmine', initials: 'CM', handicap: 14.2, rank: 1, score: 88, swings: 142, streak: 12, isYou: true },
    { id: 'm2', name: 'Alex R', handle: 'alexr', initials: 'AR', handicap: 9.4, rank: 2, score: 91, swings: 210, streak: 8, isYou: false },
    { id: 'm3', name: 'Jordan K', handle: 'jordank', initials: 'JK', handicap: 18.1, rank: 3, score: 76, swings: 96, streak: 3, isYou: false },
    { id: 'm4', name: 'Sam Lee', handle: 'samlee', initials: 'SL', handicap: 11.0, rank: 4, score: 84, swings: 168, streak: 5, isYou: false },
    { id: 'm5', name: 'Riley P', handle: 'rileyp', initials: 'RP', handicap: 22.6, rank: 5, score: 69, swings: 54, streak: 1, isYou: false },
  ],
  challenges: [
    {
      id: 'ch_center',
      title: 'Center-face week',
      detail: 'Land 12 centered strikes with a 7 iron before Sunday.',
      progress: 5,
      target: 12,
      endsAt: '2026-10-05T23:59:59.000Z',
      joined: true,
      reward: '+3 clubhouse points',
    },
    {
      id: 'ch_ballspeed',
      title: 'Honest ball speed',
      detail: 'Post 8 radar-valid swings over 95 mph.',
      progress: 2,
      target: 8,
      endsAt: '2026-10-05T23:59:59.000Z',
      joined: false,
      reward: 'Radar badge',
    },
  ],
  feed: [
    { id: 'f1', author: 'Alex R', text: 'Dialed a 7i to 148 with quieter path. Who’s next?', when: '2h ago', likes: 4 },
    { id: 'f2', author: 'Strike Lab', text: 'New radar ESP bridge is live — connect mat + radar on separate COM ports.', when: 'Yesterday', likes: 11 },
    { id: 'f3', author: 'Jordan K', text: 'Heel bias day. Clubhouse challenge saving me.', when: '2d ago', likes: 2 },
  ],
  announcements: [
    { id: 'a1', title: 'Tuesday range night', body: 'Open bay 6–8pm. Bring the mat if you want live Strike Lab scoring.' },
    { id: 'a2', title: 'Handicap sync', body: 'Update your profile handicap so the clubhouse board stays honest.' },
  ],
  events: [
    {
      id: 'ev_tuesday',
      title: 'Tuesday range night',
      detail: 'Open bay with live mat + radar scoring. Bring a 7 iron.',
      when: 'Tue 6:00–8:00 PM',
      place: 'Bay 3 · Strike Lab Range',
      attendees: 7,
      rsvped: true,
    },
    {
      id: 'ev_sat',
      title: 'Saturday smash factor clinic',
      detail: 'Radar-only session focused on ball speed and contact quality.',
      when: 'Sat 10:00 AM',
      place: 'Bay 1',
      attendees: 4,
      rsvped: false,
    },
    {
      id: 'ev_league',
      title: 'Clubhouse mini-league tee time',
      detail: 'Nine-hole scramble. Lowest combined path miss wins.',
      when: 'Sun 1:00 PM',
      place: 'Local course',
      attendees: 12,
      rsvped: false,
    },
  ],
  badges: [
    { id: 'b_streak', label: '12-day streak', icon: '🔥', earned: true },
    { id: 'b_radar', label: 'Radar locked', icon: '📡', earned: true },
    { id: 'b_center', label: 'Center face', icon: '◎', earned: false },
    { id: 'b_host', label: 'Range host', icon: '⛳', earned: false },
  ],
}

function emptyStore() {
  return {
    sessions: [],
    profile: { ...defaultProfile, preferredClubs: [...defaultProfile.preferredClubs], goals: { ...defaultProfile.goals }, stats: { ...defaultProfile.stats } },
    clubhouse: structuredClone(defaultClubhouse),
  }
}

function ensureStore() {
  if (!fs.existsSync(dataDir)) fs.mkdirSync(dataDir, { recursive: true })
  if (!fs.existsSync(storePath)) {
    fs.writeFileSync(storePath, JSON.stringify(emptyStore(), null, 2))
  }
}

function readStore() {
  ensureStore()
  try {
    const parsed = JSON.parse(fs.readFileSync(storePath, 'utf8'))
    const base = emptyStore()
    return {
      sessions: Array.isArray(parsed?.sessions) ? parsed.sessions : [],
      profile: { ...base.profile, ...(parsed?.profile || {}) },
      clubhouse: {
        ...base.clubhouse,
        ...(parsed?.clubhouse || {}),
        members: Array.isArray(parsed?.clubhouse?.members) ? parsed.clubhouse.members : base.clubhouse.members,
        challenges: Array.isArray(parsed?.clubhouse?.challenges) ? parsed.clubhouse.challenges : base.clubhouse.challenges,
        feed: Array.isArray(parsed?.clubhouse?.feed) ? parsed.clubhouse.feed : base.clubhouse.feed,
        announcements: Array.isArray(parsed?.clubhouse?.announcements) ? parsed.clubhouse.announcements : base.clubhouse.announcements,
        events: Array.isArray(parsed?.clubhouse?.events) ? parsed.clubhouse.events : base.clubhouse.events,
        badges: Array.isArray(parsed?.clubhouse?.badges) ? parsed.clubhouse.badges : base.clubhouse.badges,
      },
    }
  } catch {
    return emptyStore()
  }
}

function writeStore(store) {
  ensureStore()
  const tmp = `${storePath}.tmp`
  fs.writeFileSync(tmp, JSON.stringify(store, null, 2))
  fs.renameSync(tmp, storePath)
}

function recomputeProfileStats(sessions, profile) {
  const list = Array.isArray(sessions) ? sessions : []
  const scores = list.map((s) => Number(s.score)).filter((n) => Number.isFinite(n) && n > 0)
  const carries = list.map((s) => Number(s.bestCarryYds)).filter((n) => Number.isFinite(n) && n > 0)
  const balls = list.map((s) => Number(s.avgBallMph)).filter((n) => Number.isFinite(n) && n > 0)
  const totalSwings = list.reduce((sum, s) => sum + (Number(s.swings) || 0), 0)
  return {
    ...profile,
    stats: {
      totalSessions: list.length,
      totalSwings,
      bestScore: scores.length ? Math.max(...scores) : null,
      avgScore: scores.length ? Math.round(scores.reduce((a, b) => a + b, 0) / scores.length) : null,
      bestCarryYds: carries.length ? Math.max(...carries) : null,
      avgBallMph: balls.length ? Math.round(balls.reduce((a, b) => a + b, 0) / balls.length) : null,
    },
  }
}

function syncYouOnLeaderboard(store) {
  const you = store.clubhouse.members.find((m) => m.isYou)
  if (!you) return
  you.name = store.profile.displayName
  you.handle = store.profile.handle
  you.initials = store.profile.initials
  you.handicap = store.profile.handicap
  you.score = store.profile.stats.avgScore ?? you.score
  you.swings = store.profile.stats.totalSwings || you.swings
  you.streak = store.profile.streakDays
  store.clubhouse.members = store.clubhouse.members
    .slice()
    .sort((a, b) => (b.score || 0) - (a.score || 0))
    .map((member, index) => ({ ...member, rank: index + 1 }))
}

export function listSessions() {
  return readStore().sessions
    .slice()
    .sort((a, b) => String(b.createdAt || '').localeCompare(String(a.createdAt || '')))
}

export function getSession(id) {
  return readStore().sessions.find((session) => String(session.id) === String(id)) || null
}

export function createSession(payload = {}) {
  const store = readStore()
  const now = new Date().toISOString()
  const session = {
    id: payload.id ?? `sess_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`,
    createdAt: payload.createdAt || now,
    updatedAt: now,
    club: payload.club || '7 Iron',
    when: payload.when || 'Just now',
    distance: payload.distance || '0 yds',
    score: Number(payload.score) || 0,
    swings: Number(payload.swings) || (Array.isArray(payload.swingSnapshots) ? payload.swingSnapshots.length : 0),
    tone: payload.tone || 'warm',
    bestCarryYds: payload.bestCarryYds ?? null,
    avgBallMph: payload.avgBallMph ?? null,
    bestBallMph: payload.bestBallMph ?? null,
    avgClubMph: payload.avgClubMph ?? null,
    avgSmash: payload.avgSmash ?? null,
    radarHitPct: payload.radarHitPct ?? 0,
    avgAttackDeg: payload.avgAttackDeg ?? null,
    avgPathDeg: payload.avgPathDeg ?? null,
    avgHeelPct: payload.avgHeelPct ?? null,
    avgCenterPct: payload.avgCenterPct ?? null,
    avgToePct: payload.avgToePct ?? null,
    centeredPct: payload.centeredPct ?? 0,
    swingSnapshots: Array.isArray(payload.swingSnapshots) ? payload.swingSnapshots : [],
    rawSwings: Array.isArray(payload.rawSwings) ? payload.rawSwings : [],
  }
  store.sessions.unshift(session)
  store.profile = recomputeProfileStats(store.sessions, store.profile)
  store.profile.streakDays = Math.max(1, Number(store.profile.streakDays) || 1)
  syncYouOnLeaderboard(store)
  writeStore(store)
  return session
}

export function deleteSession(id) {
  const store = readStore()
  const before = store.sessions.length
  store.sessions = store.sessions.filter((session) => String(session.id) !== String(id))
  if (store.sessions.length === before) return false
  store.profile = recomputeProfileStats(store.sessions, store.profile)
  syncYouOnLeaderboard(store)
  writeStore(store)
  return true
}

export function clearSessions() {
  const store = readStore()
  store.sessions = []
  store.profile = recomputeProfileStats([], store.profile)
  syncYouOnLeaderboard(store)
  writeStore(store)
}

export function getProfile() {
  const store = readStore()
  return recomputeProfileStats(store.sessions, store.profile)
}

export function updateProfile(patch = {}) {
  const store = readStore()
  const next = {
    ...store.profile,
    ...patch,
    id: 'me',
    goals: { ...store.profile.goals, ...(patch.goals || {}) },
    preferredClubs: Array.isArray(patch.preferredClubs)
      ? patch.preferredClubs
      : store.profile.preferredClubs,
  }
  if (next.displayName) {
    const parts = String(next.displayName).trim().split(/\s+/)
    next.initials = (parts[0]?.[0] || 'C') + (parts[1]?.[0] || parts[0]?.[1] || 'M')
    next.initials = next.initials.toUpperCase()
  }
  store.profile = recomputeProfileStats(store.sessions, next)
  syncYouOnLeaderboard(store)
  writeStore(store)
  return store.profile
}

export function getClubhouse() {
  const store = readStore()
  store.profile = recomputeProfileStats(store.sessions, store.profile)
  syncYouOnLeaderboard(store)
  return {
    ...store.clubhouse,
    you: store.clubhouse.members.find((m) => m.isYou) || null,
    profile: store.profile,
  }
}

export function joinChallenge(challengeId) {
  const store = readStore()
  const challenge = store.clubhouse.challenges.find((c) => c.id === challengeId)
  if (!challenge) return null
  challenge.joined = true
  writeStore(store)
  return challenge
}

export function bumpChallenge(challengeId) {
  const store = readStore()
  const challenge = store.clubhouse.challenges.find((c) => c.id === challengeId)
  if (!challenge) return null
  challenge.joined = true
  challenge.progress = Math.min(challenge.target || 1, (challenge.progress || 0) + 1)
  writeStore(store)
  return challenge
}

export function rsvpEvent(eventId) {
  const store = readStore()
  const event = (store.clubhouse.events || []).find((item) => item.id === eventId)
  if (!event) return null
  if (!event.rsvped) {
    event.rsvped = true
    event.attendees = (event.attendees || 0) + 1
  }
  writeStore(store)
  return event
}

export function addFeedPost({ author, text }) {
  const store = readStore()
  const post = {
    id: `f_${Date.now()}`,
    author: author || store.profile.displayName,
    text: String(text || '').trim(),
    when: 'Just now',
    likes: 0,
  }
  if (!post.text) return null
  store.clubhouse.feed.unshift(post)
  store.clubhouse.feed = store.clubhouse.feed.slice(0, 40)
  writeStore(store)
  return post
}

export function likeFeedPost(postId) {
  const store = readStore()
  const post = store.clubhouse.feed.find((p) => p.id === postId)
  if (!post) return null
  post.likes = (post.likes || 0) + 1
  writeStore(store)
  return post
}
