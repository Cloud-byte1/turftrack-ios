import assert from 'node:assert/strict'

const base = process.env.API_BASE || 'http://127.0.0.1:8787'

async function main() {
  const health = await fetch(`${base}/api/health`).then((res) => res.json())
  assert.equal(health.ok, true)

  const profile = await fetch(`${base}/api/profile`).then((res) => res.json())
  assert.ok(profile.profile?.displayName)

  const updated = await fetch(`${base}/api/profile`, {
    method: 'PUT',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ displayName: 'Carmine Test', handicap: 13.5 }),
  }).then((res) => res.json())
  assert.equal(updated.profile.displayName, 'Carmine Test')

  const clubhouse = await fetch(`${base}/api/clubhouse`).then((res) => res.json())
  assert.ok(Array.isArray(clubhouse.clubhouse?.members))
  assert.ok(Array.isArray(clubhouse.clubhouse?.challenges))

  const joined = await fetch(`${base}/api/clubhouse/challenges/ch_ballspeed/join`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: '{}',
  }).then((res) => res.json())
  assert.equal(joined.challenge.joined, true)

  const posted = await fetch(`${base}/api/clubhouse/feed`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ text: 'Smoke test post', author: 'Carmine Test' }),
  }).then((res) => res.json())
  assert.ok(posted.post?.id)

  const created = await fetch(`${base}/api/sessions`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      club: '7 Iron',
      score: 74,
      swings: 2,
      distance: '132 yds',
      tone: 'good',
      avgBallMph: 98,
      swingSnapshots: [{ n: 1, score: 70, carryYds: 120, ballMph: 95 }],
    }),
  }).then(async (res) => {
    assert.equal(res.status, 201)
    return res.json()
  })
  assert.ok(created.session?.id)
  assert.ok(created.profile)

  await fetch(`${base}/api/sessions/${created.session.id}`, { method: 'DELETE' })
  console.log('Backend smoke test passed (sessions + profile + clubhouse).')
}

main().catch((error) => {
  console.error(error)
  process.exit(1)
})
