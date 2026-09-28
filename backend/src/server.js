import 'dotenv/config'
import express from 'express'
import cors from 'cors'
import { hasSupabaseConfig } from './supabase.js'
import * as localStore from './store.js'
import * as supabaseStore from './supabaseStore.js'

const store = hasSupabaseConfig() ? supabaseStore : localStore
const storageMode = hasSupabaseConfig() ? 'supabase' : 'local-json'

const app = express()
const PORT = Number(process.env.PORT) || 8787

app.use(cors({ origin: true }))
app.use(express.json({ limit: '2mb' }))

function asyncHandler(fn) {
  return (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next)
}

app.get('/api/health', (_req, res) => {
  res.json({
    ok: true,
    service: 'golf-mat-backend',
    storage: storageMode,
    time: new Date().toISOString(),
  })
})

app.get('/api/sessions', asyncHandler(async (_req, res) => {
  res.json({ sessions: await store.listSessions() })
}))

app.get('/api/sessions/:id', asyncHandler(async (req, res) => {
  const session = await store.getSession(req.params.id)
  if (!session) return res.status(404).json({ error: 'Session not found' })
  return res.json({ session })
}))

app.post('/api/sessions', asyncHandler(async (req, res) => {
  const body = req.body || {}
  if (!body.club && !Array.isArray(body.rawSwings) && !Array.isArray(body.swingSnapshots)) {
    return res.status(400).json({ error: 'Session payload required' })
  }
  const session = await store.createSession(body)
  return res.status(201).json({ session, profile: await store.getProfile() })
}))

app.delete('/api/sessions/:id', asyncHandler(async (req, res) => {
  const removed = await store.deleteSession(req.params.id)
  if (!removed) return res.status(404).json({ error: 'Session not found' })
  return res.json({ ok: true, profile: await store.getProfile() })
}))

app.delete('/api/sessions', asyncHandler(async (_req, res) => {
  await store.clearSessions()
  res.json({ ok: true, profile: await store.getProfile() })
}))

app.get('/api/profile', asyncHandler(async (_req, res) => {
  res.json({ profile: await store.getProfile() })
}))

app.put('/api/profile', asyncHandler(async (req, res) => {
  const profile = await store.updateProfile(req.body || {})
  res.json({ profile })
}))

app.get('/api/clubhouse', asyncHandler(async (_req, res) => {
  res.json({ clubhouse: await store.getClubhouse() })
}))

app.post('/api/clubhouse/challenges/:id/join', asyncHandler(async (req, res) => {
  const challenge = await store.joinChallenge(req.params.id)
  if (!challenge) return res.status(404).json({ error: 'Challenge not found' })
  return res.json({ challenge, clubhouse: await store.getClubhouse() })
}))

app.post('/api/clubhouse/challenges/:id/progress', asyncHandler(async (req, res) => {
  if (typeof store.bumpChallenge !== 'function') {
    return res.status(501).json({ error: 'Challenge progress not available on this store' })
  }
  const challenge = await store.bumpChallenge(req.params.id)
  if (!challenge) return res.status(404).json({ error: 'Challenge not found' })
  return res.json({ challenge, clubhouse: await store.getClubhouse() })
}))

app.post('/api/clubhouse/events/:id/rsvp', asyncHandler(async (req, res) => {
  if (typeof store.rsvpEvent !== 'function') {
    return res.status(501).json({ error: 'Events not available on this store' })
  }
  const event = await store.rsvpEvent(req.params.id)
  if (!event) return res.status(404).json({ error: 'Event not found' })
  return res.json({ event, clubhouse: await store.getClubhouse() })
}))

app.post('/api/clubhouse/feed', asyncHandler(async (req, res) => {
  const post = await store.addFeedPost(req.body || {})
  if (!post) return res.status(400).json({ error: 'Post text required' })
  return res.status(201).json({ post, clubhouse: await store.getClubhouse() })
}))

app.post('/api/clubhouse/feed/:id/like', asyncHandler(async (req, res) => {
  const post = await store.likeFeedPost(req.params.id)
  if (!post) return res.status(404).json({ error: 'Post not found' })
  return res.json({ post })
}))

app.use((err, _req, res, _next) => {
  console.error(err)
  res.status(500).json({ error: err?.message || 'Server error' })
})

app.listen(PORT, '127.0.0.1', () => {
  console.log(`golf-mat backend listening on http://127.0.0.1:${PORT} (${storageMode})`)
})
