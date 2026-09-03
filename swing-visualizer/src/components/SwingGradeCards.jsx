import { letterGradeColor } from '../engine/SwingGrader'

const COLOR_PROGRESS = {
  '#22c55e': 100,
  '#eab308': 66,
  '#f97316': 40,
  '#ef4444': 20,
}

function GradeCard({ title, value, unit, color = '#64748b', correction }) {
  const progress = COLOR_PROGRESS[color] ?? 50

  return (
    <article
      className="min-w-[140px] flex-1 rounded-xl border-t-[3px] bg-slate-800 p-4 shadow-lg shadow-slate-950/20"
      style={{ borderTopColor: color }}
      aria-label={`${title}: ${value} ${unit}`}
    >
      <h3 className="mb-1 text-xs font-medium text-slate-500">{title}</h3>
      <p className="text-[22px] font-bold leading-tight text-white">
        {value ?? '—'}
        <span className="ml-1 text-[13px] font-normal text-slate-400">
          {unit}
        </span>
      </p>

      <div
        className="mt-2 h-1 w-full overflow-hidden rounded-full bg-slate-700"
        role="progressbar"
        aria-label={`${title} grade`}
        aria-valuemin="0"
        aria-valuemax="100"
        aria-valuenow={progress}
      >
        <div
          className="h-full rounded-full transition-[width] duration-500 ease-out"
          style={{ backgroundColor: color, width: `${progress}%` }}
        />
      </div>

      {correction && (
        <p className="mt-2 text-[11px] leading-snug text-slate-400">
          {correction}
        </p>
      )}
    </article>
  )
}

function findCorrection(corrections, terms) {
  return corrections.find((correction) => {
    const normalized = correction.toLowerCase()
    return terms.some((term) => normalized.includes(term))
  })
}

export default function SwingGradeCards({ swing, grade }) {
  if (!swing || !grade || swing.zeroed) return null

  const corrections = Array.isArray(grade.corrections) ? grade.corrections : []
  const letter = grade.strikeLetter ?? grade.letterGrade
  const letterColor = letterGradeColor(letter)

  return (
    <section
      className="flex flex-wrap gap-3"
      aria-label="Swing performance grades"
    >
      <article
        className="flex min-w-[100px] items-center justify-center rounded-xl border bg-slate-800 p-4 shadow-lg shadow-slate-950/20"
        style={{ borderColor: `${letterColor}55` }}
        aria-label={`Hit grade ${letter}`}
      >
        <div className="text-center">
          <p className="text-[11px] font-medium uppercase tracking-wider text-slate-500">
            Hit grade
          </p>
          <p className="text-4xl font-black leading-none" style={{ color: letterColor }}>
            {letter}
          </p>
        </div>
      </article>
      <GradeCard
        title="Impact Quality"
        value={swing.impact_quality}
        unit="/ 100"
        color={grade.impactColor ?? grade.zoneColor}
      />
      <GradeCard
        title="Attack Angle"
        value={Number.isFinite(swing.attack_angle_deg)
          ? swing.attack_angle_deg.toFixed(1)
          : '—'}
        unit="°"
        color={grade.attackColor}
        correction={findCorrection(corrections, [
          'attack',
          'steep',
          'shallow',
        ])}
      />
      <GradeCard
        title="Swing Path"
        value={Number.isFinite(swing.swing_path_deg)
          ? swing.swing_path_deg.toFixed(1)
          : '—'}
        unit="°"
        color={grade.pathColor}
        correction={findCorrection(corrections, [
          'path',
          'slice',
          'fade',
          'hook',
          'draw',
        ])}
      />
      <GradeCard
        title="Club Speed"
        value={swing.club_speed_kmh}
        unit="km/h"
        color={grade.speedColor}
      />
      <GradeCard
        title="Distance"
        value={swing.estimated_distance_m}
        unit="m"
        color="#22c55e"
      />
    </section>
  )
}
