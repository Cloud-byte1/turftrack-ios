import { useEffect, useState } from 'react'
import { letterGradeColor, letterGradeFromScore } from '../engine/SwingGrader'

const SENSOR_LABELS = ['S0', 'S1', 'S2', 'S3', 'S4', 'S5']
const PAD_GRID = [
  [0, 1],
  [2, 3],
  [4, 5],
]

const DIRECTION_STYLES = {
  Straight: { arrow: '↑', className: 'text-green-400' },
  Left: { arrow: '↖', className: 'text-red-400' },
  Right: { arrow: '↗', className: 'text-red-400' },
  'Slight Left': { arrow: '↑↖', className: 'text-yellow-400' },
  'Slight Right': { arrow: '↑↗', className: 'text-yellow-400' },
  Push: { arrow: '↗', className: 'text-orange-400' },
  Pull: { arrow: '↖', className: 'text-orange-400' },
}

const DEFAULT_DIRECTION = { arrow: '↑', className: 'text-slate-300' }

/** Resting turf pad — always dark until a strike paints white. */
function restingPadStyle() {
  return {
    background: 'linear-gradient(160deg, rgba(34,197,94,0.16) 0%, rgba(21,128,61,0.42) 100%)',
    boxShadow: 'inset 0 0 0 1px rgba(255,255,255,0.06)',
    color: '#86efac',
  }
}

/**
 * Struck pad: white opacity scales with how hard that sensor was hit.
 * 0 → invisible white (turf only), 1 → solid white.
 */
function struckPadStyle(value, maxValue, isImpact) {
  const intensity = Math.max(0, value) / Math.max(maxValue, 1)
  const whiteOpacity = Math.max(0.12, Math.min(1, intensity * intensity * 0.35 + intensity * 0.65))
  return {
    background: `linear-gradient(160deg,
      rgba(34,197,94,0.2) 0%,
      rgba(21,128,61,0.45) 40%,
      rgba(255,255,255,${whiteOpacity}) 100%)`,
    boxShadow: isImpact
      ? `inset 0 0 0 2px rgba(255,255,255,${0.55 + whiteOpacity * 0.4}), 0 0 ${10 + whiteOpacity * 16}px rgba(255,255,255,${0.25 + whiteOpacity * 0.4})`
      : `inset 0 0 0 1px rgba(255,255,255,${0.12 + whiteOpacity * 0.35})`,
    color: whiteOpacity > 0.55 ? '#0f172a' : '#ecfdf5',
  }
}

export default function StrikeHeatmap({
  swing,
  grade,
  armed = false,
  waiting = false,
  animated = true,
}) {
  const [flash, setFlash] = useState(0)
  const hasStrike = Boolean(swing) && !swing?.zeroed && !waiting

  useEffect(() => {
    if (!hasStrike || !animated) return undefined
    setFlash(1)
    const fade = window.setTimeout(() => setFlash(0), 500)
    return () => window.clearTimeout(fade)
  }, [swing?.timestamp_ms, swing?.label, swing?.impact_zone, hasStrike, animated])

  const sensorValues = hasStrike
    ? Array.from({ length: 6 }, (_, index) => {
      const value = Number(swing.fsr_peaks?.[index])
      return Number.isFinite(value) ? value : 0
    })
    : [0, 0, 0, 0, 0, 0]

  const maxValue = Math.max(...sensorValues, 1)
  const impactZone = hasStrike ? Number(swing.impact_zone) : -1
  const directionLabel = hasStrike ? (swing.direction_label || 'Unknown') : 'Armed'
  const direction = hasStrike
    ? (DIRECTION_STYLES[directionLabel] ?? DEFAULT_DIRECTION)
    : { arrow: '○', className: 'text-slate-400' }

  const letter = hasStrike
    ? (grade?.strikeLetter
      ?? grade?.letterGrade
      ?? letterGradeFromScore(swing?.impact_quality ?? grade?.overallScore ?? 0))
    : null

  return (
    <section
      className="rounded-2xl border border-white/10 bg-[#102418] p-4 shadow-panel"
      aria-labelledby="strike-heatmap-heading"
    >
      <div className="mb-3 flex items-end justify-between gap-3">
        <div>
          <p className="text-[11px] font-semibold uppercase tracking-[0.18em] text-turf-400/90">
            Mat center
          </p>
          <h2 id="strike-heatmap-heading" className="text-sm font-semibold text-white">
            Strike pads
          </h2>
        </div>
        <div className="text-right text-[11px] text-slate-400">
          <div>{waiting || !hasStrike ? 'Zeroed — waiting for strike' : 'White = hit strength'}</div>
          <div className="text-slate-500">Low hit = faint · Solid = bright</div>
        </div>
      </div>

      {letter ? (
        <div className="mb-3 flex items-center justify-center gap-3">
          <span
            className="grid h-14 w-14 place-items-center rounded-2xl border text-3xl font-black"
            style={{
              color: letterGradeColor(letter),
              borderColor: `${letterGradeColor(letter)}55`,
              background: `${letterGradeColor(letter)}18`,
            }}
            aria-label={`Strike grade ${letter}`}
          >
            {letter}
          </span>
          <div className="text-sm text-slate-300">
            <div className="font-semibold text-white">Hit grade</div>
            <div className="text-xs text-slate-400">
              Quality {Math.round(swing?.impact_quality ?? 0)} · A best → F weakest
            </div>
          </div>
        </div>
      ) : (
        <div className="mb-3 rounded-xl border border-white/10 bg-black/20 px-3 py-3 text-center text-xs text-slate-400">
          {armed
            ? 'Calibrated. Pads stay dark at 0 until a full strike.'
            : 'Connect ESP USB and press Calibrate / Zero to arm tracking.'}
        </div>
      )}

      <div
        className="relative overflow-hidden rounded-xl border border-emerald-900/70 bg-[radial-gradient(ellipse_at_center,_rgba(34,197,94,0.18),_rgba(6,30,18,0.95)_70%)] p-3"
        role="img"
        aria-label={hasStrike ? `Mat strike map. Grade ${letter}.` : 'Mat strike map zeroed.'}
      >
        <div
          className="pointer-events-none absolute inset-0 opacity-30"
          style={{
            backgroundImage: 'radial-gradient(rgba(255,255,255,0.08) 0.5px, transparent 0.5px)',
            backgroundSize: '7px 7px',
          }}
          aria-hidden="true"
        />

        <div className="relative grid grid-cols-[auto_1fr_auto] gap-2">
          <div className="flex flex-col justify-between py-1 text-[10px] font-medium uppercase tracking-wider text-emerald-200/50">
            <span>Top</span>
            <span>Mid</span>
            <span>Bot</span>
          </div>

          <div className="grid grid-rows-3 gap-2">
            {PAD_GRID.map((row, rowIndex) => (
              <div key={`row-${rowIndex}`} className="grid grid-cols-2 gap-2">
                {row.map((sensorIndex) => {
                  const value = sensorValues[sensorIndex]
                  const isImpact = sensorIndex === impactZone
                  const style = hasStrike
                    ? struckPadStyle(value, maxValue, isImpact)
                    : restingPadStyle()
                  return (
                    <div
                      key={SENSOR_LABELS[sensorIndex]}
                      className={`relative flex min-h-[3.25rem] items-end justify-between rounded-lg px-2.5 py-2 ${
                        animated ? 'transition-all duration-500' : ''
                      }`}
                      style={style}
                      title={`${SENSOR_LABELS[sensorIndex]}: ${value}`}
                    >
                      <span className="text-[10px] font-semibold opacity-80">
                        {SENSOR_LABELS[sensorIndex]}
                      </span>
                      <span className="text-sm font-bold tabular-nums">
                        {hasStrike ? value : 0}
                      </span>
                      {hasStrike && isImpact ? (
                        <span
                          className="pointer-events-none absolute inset-0 rounded-lg"
                          style={{ background: `rgba(255,255,255,${flash ? 0.45 : 0.18})` }}
                          aria-hidden="true"
                        />
                      ) : null}
                    </div>
                  )
                })}
              </div>
            ))}
          </div>

          <div className="flex flex-col justify-center text-[10px] font-medium text-emerald-200/50">
            <span className="-rotate-90 whitespace-nowrap">Sweet</span>
          </div>
        </div>

        <div className="relative mt-2 flex justify-between px-1 text-[10px] font-semibold uppercase tracking-wider text-emerald-100/60">
          <span>Heel</span>
          <span>Toe</span>
        </div>
      </div>

      <div
        className={`mt-3 text-center text-sm font-semibold ${direction.className}`}
        aria-label={hasStrike ? `Shot direction: ${directionLabel}` : 'Waiting for strike'}
      >
        <span aria-hidden="true">{direction.arrow} </span>
        {hasStrike ? directionLabel : (armed ? 'Waiting for strike' : 'Not armed')}
      </div>
    </section>
  )
}
