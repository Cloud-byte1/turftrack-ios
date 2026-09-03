import { letterGradeColor, letterGradeFromScore } from '../engine/SwingGrader'

export default function SessionHistory({ swings = [], grades = [] }) {
  if (swings.length === 0) return null

  const recentSwings = swings.slice(-5)
  const recentGrades = grades.slice(-recentSwings.length)
  const gradeOffset = recentSwings.length - recentGrades.length

  return (
    <section
      className="rounded-xl bg-slate-800 p-4 shadow-lg shadow-slate-950/20"
      aria-labelledby="session-history-heading"
    >
      <h2
        id="session-history-heading"
        className="mb-3 text-xs font-medium uppercase tracking-wider text-slate-500"
      >
        Session history (last {recentSwings.length})
      </h2>

      <ol className="flex gap-2 overflow-x-auto pb-1" aria-label="Recent swings">
        {recentSwings.map((swing, index) => {
          const grade = recentGrades[index - gradeOffset]
          const letter = grade?.strikeLetter
            ?? grade?.letterGrade
            ?? letterGradeFromScore(swing.impact_quality)
          const letterColor = letterGradeColor(letter)
          const opacity = 0.5 + ((index + 1) / recentSwings.length) * 0.5
          const sessionIndex = swings.length - recentSwings.length + index + 1

          return (
            <li
              key={`${sessionIndex}-${swing.label ?? swing.impact_quality}`}
              className="min-w-[84px] flex-1 rounded-lg border-t-2 bg-slate-900 p-2"
              style={{
                borderTopColor: letterColor,
                opacity,
              }}
              aria-label={`Swing ${sessionIndex}: grade ${letter}, quality ${swing.impact_quality}`}
            >
              <p
                className="text-center text-2xl font-black"
                style={{ color: letterColor }}
              >
                {letter}
              </p>
              <p className="truncate text-center text-[10px] text-slate-500">
                {swing.impact_quality} · {swing.direction_label}
              </p>
            </li>
          )
        })}
      </ol>
    </section>
  )
}
