import { useMemo, useState } from 'react'

const TABS = [
  { id: 'overview', label: 'Overview' },
  { id: 'board', label: 'Leaderboard' },
  { id: 'challenges', label: 'Challenges' },
  { id: 'feed', label: 'Feed' },
  { id: 'events', label: 'Events' },
]

function daysLeft(endsAt) {
  if (!endsAt) return null
  const ms = new Date(endsAt).getTime() - Date.now()
  if (!Number.isFinite(ms)) return null
  return Math.max(0, Math.ceil(ms / (1000 * 60 * 60 * 24)))
}

export default function ClubhouseView({
  clubhouse,
  onJoinChallenge,
  onBumpChallenge,
  onPost,
  onLike,
  onRsvpEvent,
  apiOnline,
}) {
  const [tab, setTab] = useState('overview')
  const [draft, setDraft] = useState('')
  const [posting, setPosting] = useState(false)
  const [selectedMemberId, setSelectedMemberId] = useState(null)

  const members = clubhouse?.members || []
  const challenges = clubhouse?.challenges || []
  const feed = clubhouse?.feed || []
  const announcements = clubhouse?.announcements || []
  const events = clubhouse?.events || []
  const badges = clubhouse?.badges || []
  const you = clubhouse?.you || members.find((m) => m.isYou) || null
  const selectedMember = members.find((m) => m.id === selectedMemberId) || null

  const stats = useMemo(() => {
    const joined = challenges.filter((c) => c.joined).length
    const totalLikes = feed.reduce((sum, post) => sum + (post.likes || 0), 0)
    const avgScore = members.length
      ? Math.round(members.reduce((sum, m) => sum + (m.score || 0), 0) / members.length)
      : 0
    return {
      members: members.length,
      challenges: challenges.length,
      joined,
      posts: feed.length,
      likes: totalLikes,
      avgScore,
      events: events.length,
    }
  }, [members, challenges, feed, events])

  if (!clubhouse) {
    return (
      <section className="hub-panel">
        <p className="eyebrow">CLUBHOUSE</p>
        <h2>Loading clubhouse…</h2>
      </section>
    )
  }

  return (
    <section className="clubhouse-hub">
      <div className="hub-panel clubhouse-hero-card">
        <div className="hub-hero">
          <div>
            <p className="eyebrow">CLUBHOUSE</p>
            <h2>{clubhouse.name}</h2>
            <span>{clubhouse.tagline}</span>
            <p className="hub-note">
              {apiOnline ? 'Live board synced to backend' : 'Local clubhouse — start backend / add Supabase keys to sync'}
            </p>
          </div>
          {you ? (
            <div className="you-chip">
              <b>#{you.rank}</b>
              <span>{you.name} · {you.score} avg · {you.streak}d streak</span>
            </div>
          ) : null}
        </div>

        <div className="clubhouse-stat-strip">
          <span><b>{stats.members}</b>members</span>
          <span><b>{stats.avgScore}</b>board avg</span>
          <span><b>{stats.joined}/{stats.challenges}</b>challenges</span>
          <span><b>{stats.posts}</b>posts</span>
          <span><b>{stats.events}</b>events</span>
          <span><b>{stats.likes}</b>likes</span>
        </div>

        <div className="clubhouse-tabs" role="tablist" aria-label="Clubhouse sections">
          {TABS.map((item) => (
            <button
              key={item.id}
              type="button"
              role="tab"
              aria-selected={tab === item.id}
              className={tab === item.id ? 'active' : ''}
              onClick={() => setTab(item.id)}
            >
              {item.label}
            </button>
          ))}
        </div>
      </div>

      {tab === 'overview' ? (
        <div className="clubhouse-grid overview-grid">
          <article className="hub-panel">
            <div className="panel-heading"><div><p className="eyebrow">YOUR SPOT</p><h2>Season card</h2></div></div>
            {you ? (
              <div className="season-card">
                <div className="season-avatar">{you.initials}</div>
                <div>
                  <b>{you.name}</b>
                  <p>Rank #{you.rank} · HCP {you.handicap}</p>
                  <p>{you.swings} swings logged · {you.streak}-day streak</p>
                </div>
                <strong>{you.score}</strong>
              </div>
            ) : (
              <p className="hub-note">Save a profile to claim your board spot.</p>
            )}
            {badges.length ? (
              <div className="badge-row">
                {badges.map((badge) => (
                  <span key={badge.id} className={`club-badge ${badge.earned ? 'earned' : ''}`}>
                    <b>{badge.icon}</b>
                    {badge.label}
                  </span>
                ))}
              </div>
            ) : null}
          </article>

          <article className="hub-panel">
            <div className="panel-heading"><div><p className="eyebrow">HOT CHALLENGE</p><h2>Keep grinding</h2></div></div>
            {(challenges.find((c) => c.joined) || challenges[0]) ? (() => {
              const challenge = challenges.find((c) => c.joined) || challenges[0]
              const pct = Math.min(100, Math.round(((challenge.progress || 0) / (challenge.target || 1)) * 100))
              const left = daysLeft(challenge.endsAt)
              return (
                <div className="challenge-card featured">
                  <div>
                    <b>{challenge.title}</b>
                    <p>{challenge.detail}</p>
                    <small>{challenge.reward}{left != null ? ` · ${left}d left` : ''}</small>
                  </div>
                  <div className="challenge-meter"><i style={{ width: `${pct}%` }} /></div>
                  <div className="challenge-foot">
                    <span>{challenge.progress}/{challenge.target}</span>
                    <div className="challenge-actions">
                      {!challenge.joined ? (
                        <button type="button" onClick={() => onJoinChallenge(challenge.id)}>Join</button>
                      ) : (
                        <button type="button" onClick={() => onBumpChallenge?.(challenge.id)}>+1 progress</button>
                      )}
                    </div>
                  </div>
                </div>
              )
            })() : <p className="hub-note">No challenges yet.</p>}
          </article>

          <article className="hub-panel">
            <div className="panel-heading"><div><p className="eyebrow">UP NEXT</p><h2>Range events</h2></div></div>
            <div className="event-list compact">
              {events.slice(0, 2).map((event) => (
                <div key={event.id} className="event-card">
                  <div>
                    <b>{event.title}</b>
                    <p>{event.when} · {event.place}</p>
                  </div>
                  <button type="button" onClick={() => onRsvpEvent?.(event.id)}>
                    {event.rsvped ? 'Going' : 'RSVP'}
                  </button>
                </div>
              ))}
              {!events.length ? <p className="hub-note">No events posted.</p> : null}
            </div>
          </article>

          <article className="hub-panel">
            <div className="panel-heading"><div><p className="eyebrow">BULLETIN</p><h2>House notes</h2></div></div>
            <div className="announce-list">
              {announcements.map((item) => (
                <div key={item.id} className="announce-item">
                  <b>{item.title}</b>
                  <p>{item.body}</p>
                </div>
              ))}
            </div>
          </article>
        </div>
      ) : null}

      {tab === 'board' ? (
        <div className="clubhouse-grid board-grid">
          <article className="hub-panel">
            <div className="panel-heading">
              <div><p className="eyebrow">LEADERBOARD</p><h2>This week’s board</h2></div>
            </div>
            <div className="member-list">
              {members.map((member) => (
                <button
                  key={member.id}
                  type="button"
                  className={`member-row ${member.isYou ? 'is-you' : ''} ${selectedMemberId === member.id ? 'selected' : ''}`}
                  onClick={() => setSelectedMemberId(member.id)}
                >
                  <span className="rank">#{member.rank}</span>
                  <span className="avatar-sm">{member.initials}</span>
                  <div>
                    <b>{member.name}{member.isYou ? ' (you)' : ''}</b>
                    <small>HCP {member.handicap} · {member.swings} swings · {member.streak}d streak</small>
                  </div>
                  <strong>{member.score}</strong>
                </button>
              ))}
            </div>
          </article>

          <article className="hub-panel">
            <div className="panel-heading"><div><p className="eyebrow">MEMBER</p><h2>Card detail</h2></div></div>
            {selectedMember ? (
              <div className="member-detail">
                <div className="season-avatar lg">{selectedMember.initials}</div>
                <b>{selectedMember.name}</b>
                <p>@{selectedMember.handle}</p>
                <div className="summary-stats profile-stats">
                  <span><b>#{selectedMember.rank}</b>rank</span>
                  <span><b>{selectedMember.score}</b>avg</span>
                  <span><b>{selectedMember.handicap}</b>hcp</span>
                  <span><b>{selectedMember.swings}</b>swings</span>
                  <span><b>{selectedMember.streak}</b>streak</span>
                </div>
                <p className="hub-note">
                  {selectedMember.isYou
                    ? 'That’s you — finish sessions to climb the board.'
                    : `${selectedMember.name.split(' ')[0]} is ${selectedMember.rank < (you?.rank || 99) ? 'ahead of you' : 'within reach'} this week.`}
                </p>
              </div>
            ) : (
              <p className="hub-note">Tap a member to open their clubhouse card.</p>
            )}
          </article>
        </div>
      ) : null}

      {tab === 'challenges' ? (
        <article className="hub-panel">
          <div className="panel-heading"><div><p className="eyebrow">CHALLENGES</p><h2>Active goals</h2></div></div>
          <div className="challenge-list wide">
            {challenges.map((challenge) => {
              const pct = Math.min(100, Math.round(((challenge.progress || 0) / (challenge.target || 1)) * 100))
              const left = daysLeft(challenge.endsAt)
              return (
                <div key={challenge.id} className={`challenge-card ${challenge.joined ? 'joined' : ''}`}>
                  <div>
                    <b>{challenge.title}</b>
                    <p>{challenge.detail}</p>
                    <small>{challenge.reward}{left != null ? ` · ${left}d left` : ''}</small>
                  </div>
                  <div className="challenge-meter"><i style={{ width: `${pct}%` }} /></div>
                  <div className="challenge-foot">
                    <span>{challenge.progress}/{challenge.target} · {pct}%</span>
                    <div className="challenge-actions">
                      {!challenge.joined ? (
                        <button type="button" onClick={() => onJoinChallenge(challenge.id)}>Join</button>
                      ) : (
                        <>
                          <em>Joined</em>
                          <button type="button" onClick={() => onBumpChallenge?.(challenge.id)}>+1</button>
                        </>
                      )}
                    </div>
                  </div>
                </div>
              )
            })}
          </div>
        </article>
      ) : null}

      {tab === 'feed' ? (
        <article className="hub-panel">
          <div className="panel-heading"><div><p className="eyebrow">BOARD</p><h2>Clubhouse feed</h2></div></div>
          <form
            className="feed-compose"
            onSubmit={async (event) => {
              event.preventDefault()
              if (!draft.trim()) return
              setPosting(true)
              try {
                await onPost(draft.trim())
                setDraft('')
              } finally {
                setPosting(false)
              }
            }}
          >
            <textarea
              value={draft}
              onChange={(event) => setDraft(event.target.value)}
              placeholder="Share a strike note, carry, or radar lock…"
              rows={3}
            />
            <button type="submit" disabled={posting || !draft.trim()}>
              {posting ? 'Posting…' : 'Post to clubhouse'}
            </button>
          </form>
          <div className="feed-list">
            {feed.map((post) => (
              <div key={post.id} className="feed-item">
                <div>
                  <b>{post.author}</b>
                  <small>{post.when}</small>
                </div>
                <p>{post.text}</p>
                <button type="button" className="like-btn" onClick={() => onLike(post.id)}>
                  ♥ {post.likes || 0}
                </button>
              </div>
            ))}
          </div>
        </article>
      ) : null}

      {tab === 'events' ? (
        <div className="clubhouse-grid">
          <article className="hub-panel">
            <div className="panel-heading"><div><p className="eyebrow">EVENTS</p><h2>Range calendar</h2></div></div>
            <div className="event-list">
              {events.map((event) => (
                <div key={event.id} className={`event-card ${event.rsvped ? 'rsvped' : ''}`}>
                  <div>
                    <b>{event.title}</b>
                    <p>{event.detail}</p>
                    <small>{event.when} · {event.place} · {event.attendees || 0} going</small>
                  </div>
                  <button type="button" onClick={() => onRsvpEvent?.(event.id)}>
                    {event.rsvped ? 'Going ✓' : 'RSVP'}
                  </button>
                </div>
              ))}
              {!events.length ? <p className="hub-note">No upcoming events.</p> : null}
            </div>
          </article>
          <article className="hub-panel">
            <div className="panel-heading"><div><p className="eyebrow">BULLETIN</p><h2>Announcements</h2></div></div>
            <div className="announce-list">
              {announcements.map((item) => (
                <div key={item.id} className="announce-item">
                  <b>{item.title}</b>
                  <p>{item.body}</p>
                </div>
              ))}
            </div>
          </article>
        </div>
      ) : null}
    </section>
  )
}
