export default function ProfileView({ profile, onSave, saving, apiOnline }) {
  if (!profile) {
    return (
      <section className="hub-panel">
        <p className="eyebrow">PROFILE</p>
        <h2>Loading profile…</h2>
      </section>
    )
  }

  const stats = profile.stats || {}

  return (
    <section className="hub-panel profile-hub">
      <div className="hub-hero">
        <div className="avatar-lg">{profile.initials || 'CM'}</div>
        <div>
          <p className="eyebrow">YOUR PROFILE</p>
          <h2>{profile.displayName}</h2>
          <span>@{profile.handle} · {profile.homeClub}</span>
          <p className="hub-note">{apiOnline ? 'Synced with backend' : 'Local draft — start backend to persist'}</p>
        </div>
      </div>

      <form
        className="profile-form"
        onSubmit={(event) => {
          event.preventDefault()
          const data = new FormData(event.currentTarget)
          onSave({
            displayName: String(data.get('displayName') || '').trim(),
            handle: String(data.get('handle') || '').trim().replace(/^@/, ''),
            homeClub: String(data.get('homeClub') || '').trim(),
            handicap: Number(data.get('handicap')),
            location: String(data.get('location') || '').trim(),
            bio: String(data.get('bio') || '').trim(),
            streakDays: Number(data.get('streakDays')),
            preferredClubs: String(data.get('preferredClubs') || '')
              .split(',')
              .map((item) => item.trim())
              .filter(Boolean),
            goals: {
              targetHandicap: Number(data.get('targetHandicap')),
              weeklySessions: Number(data.get('weeklySessions')),
              focusClub: String(data.get('focusClub') || '').trim(),
            },
          })
        }}
      >
        <div className="form-grid">
          <label>
            <span>Display name</span>
            <input name="displayName" defaultValue={profile.displayName} required />
          </label>
          <label>
            <span>Handle</span>
            <input name="handle" defaultValue={profile.handle} required />
          </label>
          <label>
            <span>Home club</span>
            <input name="homeClub" defaultValue={profile.homeClub} />
          </label>
          <label>
            <span>Handicap</span>
            <input name="handicap" type="number" step="0.1" defaultValue={profile.handicap} />
          </label>
          <label>
            <span>Location</span>
            <input name="location" defaultValue={profile.location} />
          </label>
          <label>
            <span>Streak (days)</span>
            <input name="streakDays" type="number" min="0" defaultValue={profile.streakDays} />
          </label>
          <label className="full">
            <span>Preferred clubs (comma-separated)</span>
            <input name="preferredClubs" defaultValue={(profile.preferredClubs || []).join(', ')} />
          </label>
          <label className="full">
            <span>Bio</span>
            <textarea name="bio" rows={3} defaultValue={profile.bio} />
          </label>
          <label>
            <span>Goal handicap</span>
            <input name="targetHandicap" type="number" step="0.1" defaultValue={profile.goals?.targetHandicap} />
          </label>
          <label>
            <span>Weekly sessions goal</span>
            <input name="weeklySessions" type="number" min="1" defaultValue={profile.goals?.weeklySessions} />
          </label>
          <label>
            <span>Focus club</span>
            <input name="focusClub" defaultValue={profile.goals?.focusClub} />
          </label>
        </div>
        <button type="submit" className="hub-primary" disabled={saving}>
          {saving ? 'Saving…' : 'Save profile'}
        </button>
      </form>

      <div className="summary-stats profile-stats">
        <span><b>{stats.totalSessions ?? 0}</b>sessions</span>
        <span><b>{stats.totalSwings ?? 0}</b>swings</span>
        <span><b>{stats.avgScore ?? '—'}</b>avg score</span>
        <span><b>{stats.bestScore ?? '—'}</b>best score</span>
        <span><b>{stats.bestCarryYds ?? '—'}</b>best carry</span>
        <span><b>{stats.avgBallMph ?? '—'}</b>avg ball</span>
        <span><b>{profile.streakDays ?? 0}</b>day streak</span>
        <span><b>{profile.handicap ?? '—'}</b>handicap</span>
      </div>
    </section>
  )
}
