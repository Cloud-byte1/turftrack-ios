const API_BASE = import.meta.env.VITE_API_BASE || ''

async function request(path, options = {}) {
  const response = await fetch(`${API_BASE}${path}`, {
    headers: {
      'content-type': 'application/json',
      ...(options.headers || {}),
    },
    ...options,
  })

  let body = null
  try {
    body = await response.json()
  } catch {
    body = null
  }

  if (!response.ok) {
    const message = body?.error || `API ${response.status}`
    throw new Error(message)
  }
  return body
}

export async function fetchHealth() {
  return request('/api/health')
}

export async function fetchSessions() {
  const data = await request('/api/sessions')
  return Array.isArray(data?.sessions) ? data.sessions : []
}

export async function saveSession(session) {
  const data = await request('/api/sessions', {
    method: 'POST',
    body: JSON.stringify(session),
  })
  return data
}

export async function removeSession(id) {
  return request(`/api/sessions/${encodeURIComponent(id)}`, { method: 'DELETE' })
}

export async function fetchProfile() {
  const data = await request('/api/profile')
  return data.profile
}

export async function saveProfile(profile) {
  const data = await request('/api/profile', {
    method: 'PUT',
    body: JSON.stringify(profile),
  })
  return data.profile
}

export async function fetchClubhouse() {
  const data = await request('/api/clubhouse')
  return data.clubhouse
}

export async function joinChallenge(id) {
  const data = await request(`/api/clubhouse/challenges/${encodeURIComponent(id)}/join`, {
    method: 'POST',
    body: '{}',
  })
  return data
}

export async function bumpChallenge(id) {
  const data = await request(`/api/clubhouse/challenges/${encodeURIComponent(id)}/progress`, {
    method: 'POST',
    body: '{}',
  })
  return data
}

export async function rsvpClubhouseEvent(id) {
  const data = await request(`/api/clubhouse/events/${encodeURIComponent(id)}/rsvp`, {
    method: 'POST',
    body: '{}',
  })
  return data
}

export async function postClubhouseFeed(text, author) {
  const data = await request('/api/clubhouse/feed', {
    method: 'POST',
    body: JSON.stringify({ text, author }),
  })
  return data
}

export async function likeClubhousePost(id) {
  const data = await request(`/api/clubhouse/feed/${encodeURIComponent(id)}/like`, {
    method: 'POST',
    body: '{}',
  })
  return data.post
}
