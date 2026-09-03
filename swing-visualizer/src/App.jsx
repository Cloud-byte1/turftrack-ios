import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { golfMatClient } from './ble/GolfMatClient.js'
import { golfMatSerialClient } from './serial/GolfMatSerialClient.js'
import { xiaoSerialClient } from './xiao/XiaoSerialClient.js'
import { radarSerialClient } from './radar/RadarSerialClient.js'
import { mergeRadarIntoSwing } from './radar/radarPacket.js'
import { generateRandomSwing, pickBelowAverageSimParams, simulateSwing, SWING_PRESETS } from './engine/SwingSimulator.js'
import { buildSessionSummary, strikeMetrics } from './engine/sessionSummary.js'
import SwingVisualizer3D from './components/SwingVisualizer3D.jsx'

const initialSessions = [
  { id: 1, club: '7 Iron', distance: '168 yds', score: 92, swings: 24, when: 'Today, 2:42 PM', tone: 'great' },
  { id: 2, club: 'Driver', distance: '274 yds', score: 84, swings: 38, when: 'Sunday, 10:18 AM', tone: 'good' },
  { id: 3, club: 'PW', distance: '126 yds', score: 78, swings: 18, when: 'Friday, 4:06 PM', tone: 'warm' },
]

const zeroSwing = {
  label: 'Zeroed', zeroed: true, impact_quality: 0, impact_zone: -1,
  fsr_peaks: [0, 0, 0, 0, 0, 0], heel_pressure_pct: 0,
  center_pressure_pct: 0, toe_pressure_pct: 0, estimated_distance_m: 0,
  club_speed_kmh: 0, swing_path_deg: 0, attack_angle_deg: 0,
  direction_label: 'Waiting',
}

export default function App() {
  const [club, setClub] = useState('7 Iron')
  const [tab, setTab] = useState('Lab')
  const [swing, setSwing] = useState(zeroSwing)
  const [bleStatus, setBleStatus] = useState(golfMatClient.status)
  const [usbStatus, setUsbStatus] = useState(golfMatSerialClient.status)
  const [xiaoStatus, setXiaoStatus] = useState(xiaoSerialClient.status)
  const [radarStatus, setRadarStatus] = useState(radarSerialClient.status)
  const [armed, setArmed] = useState(false)
  const [isZeroed, setIsZeroed] = useState(false)
  const [calibrating, setCalibrating] = useState(false)
  const [notice, setNotice] = useState('Connect mat ESP and/or radar ESP, or try a demo strike.')
  const [activeSession, setActiveSession] = useState(null)
  const [sessionSwings, setSessionSwings] = useState([])
  const [sessions, setSessions] = useState(initialSessions)
  const [selectedSession, setSelectedSession] = useState(null)
  const [lastReadingAt, setLastReadingAt] = useState(null)
  const [packetCount, setPacketCount] = useState(0)
  const [simBallMph, setSimBallMph] = useState(96)
  const [simClubMph, setSimClubMph] = useState(72)
  const [simAttackDeg, setSimAttackDeg] = useState(-5)
  const [simPathDeg, setSimPathDeg] = useState(3)
  const [simQuality, setSimQuality] = useState(48)
  const [liveTrack, setLiveTrack] = useState({
    tracking: false,
    radar_valid: false,
    ball_speed_mph: null,
    radar_distance_mm: null,
    radar_intra_score: null,
    radar_inter_score: null,
    fsr_peaks: [0, 0, 0, 0, 0, 0],
    updatedAt: null,
    source: null,
  })
  const [trackSimLive, setTrackSimLive] = useState(true)
  const latestRadarRef = useRef(null)

  const acceptSwing = useCallback((incoming) => {
    const nextSwing = mergeRadarIntoSwing(incoming, latestRadarRef.current)
    setLastReadingAt(new Date())
    setPacketCount((count) => count + 1)

    setLiveTrack((previous) => ({
      tracking: true,
      radar_valid: Boolean(nextSwing?.radar_valid) || previous.radar_valid,
      ball_speed_mph: Number.isFinite(nextSwing?.ball_speed_mph)
        ? nextSwing.ball_speed_mph
        : previous.ball_speed_mph,
      radar_distance_mm: Number.isFinite(nextSwing?.radar_distance_mm)
        ? nextSwing.radar_distance_mm
        : previous.radar_distance_mm,
      radar_intra_score: Number.isFinite(nextSwing?.radar_intra_score)
        ? nextSwing.radar_intra_score
        : previous.radar_intra_score,
      radar_inter_score: Number.isFinite(nextSwing?.radar_inter_score)
        ? nextSwing.radar_inter_score
        : previous.radar_inter_score,
      fsr_peaks: Array.isArray(nextSwing?.fsr_peaks) ? [...nextSwing.fsr_peaks] : previous.fsr_peaks,
      updatedAt: new Date(),
      source: nextSwing?.source || previous.source || 'live',
    }))

    if (nextSwing?.preview) {
      setSwing((previous) => ({ ...previous, ...nextSwing, zeroed: false }))
      setNotice('Live tracking… motion / radar update')
      return
    }

    if (nextSwing?.source && !armed && nextSwing.source !== 'simulate') {
      setSwing({ ...nextSwing, zeroed: false })
      setNotice(`${nextSwing.label || 'Live packet'} tracked — initialize swing to record into a session.`)
      return
    }

    setSwing({ ...nextSwing, zeroed: false })
    if (!nextSwing?.preview && activeSession) setSessionSwings((previous) => [...previous, nextSwing])
    if (!nextSwing?.preview) setArmed(false)
    const radarNote = nextSwing?.radar_valid
      ? ` · radar ${Number(nextSwing.ball_speed_mph).toFixed(1)} mph`
      : ''
    setNotice(`${nextSwing.label || 'Strike'} captured${radarNote}.`)
  }, [armed, activeSession])

  const acceptRadar = useCallback((sample) => {
    latestRadarRef.current = sample
    setLastReadingAt(new Date())
    setPacketCount((count) => count + 1)
    setLiveTrack((previous) => ({
      ...previous,
      tracking: true,
      radar_valid: Boolean(sample?.radar_valid),
      ball_speed_mph: Number.isFinite(sample?.ball_speed_mph) ? sample.ball_speed_mph : previous.ball_speed_mph,
      radar_distance_mm: Number.isFinite(sample?.radar_distance_mm) ? sample.radar_distance_mm : previous.radar_distance_mm,
      radar_intra_score: Number.isFinite(sample?.radar_intra_score) ? sample.radar_intra_score : previous.radar_intra_score,
      radar_inter_score: Number.isFinite(sample?.radar_inter_score) ? sample.radar_inter_score : previous.radar_inter_score,
      updatedAt: new Date(),
      source: 'radar',
    }))
    if (sample?.radar_valid) {
      setSwing((previous) => ({
        ...previous,
        zeroed: false,
        ball_speed_mph: sample.ball_speed_mph,
        ball_speed_kmh: sample.ball_speed_kmh,
        radar_distance_mm: sample.radar_distance_mm,
        radar_intra_score: sample.radar_intra_score,
        radar_inter_score: sample.radar_inter_score,
        radar_valid: true,
      }))
      setNotice(`Radar track ${Number(sample.ball_speed_mph).toFixed(1)} mph · ${sample.radar_distance_mm} mm`)
    }
  }, [])

  useEffect(() => {
    const cleanups = [
      golfMatClient.onStatus(setBleStatus),
      golfMatSerialClient.onStatus(setUsbStatus),
      xiaoSerialClient.onStatus(setXiaoStatus),
      radarSerialClient.onStatus(setRadarStatus),
      golfMatClient.onSwing(acceptSwing),
      golfMatSerialClient.onSwing(acceptSwing),
      xiaoSerialClient.onSwing(acceptSwing),
      radarSerialClient.onRadar(acceptRadar),
    ]
    return () => cleanups.forEach((cleanup) => cleanup())
  }, [acceptSwing, acceptRadar])

  /* Actively rebuild a fully populated swing while simulator sliders move. */
  useEffect(() => {
    if (!trackSimLive) return undefined
    const handle = window.setTimeout(() => {
      const preview = simulateSwing({
        ballSpeedMph: simBallMph,
        clubSpeedMph: simClubMph,
        attackAngleDeg: simAttackDeg,
        swingPathDeg: simPathDeg,
        quality: simQuality,
        preview: true,
      })
      setSwing(preview)
      setLiveTrack({
        tracking: true,
        radar_valid: true,
        ball_speed_mph: preview.ball_speed_mph,
        radar_distance_mm: preview.radar_distance_mm,
        radar_intra_score: preview.radar_intra_score,
        fsr_peaks: [...preview.fsr_peaks],
        updatedAt: new Date(),
        source: 'simulate',
      })
      setLastReadingAt(new Date())
    }, 60)
    return () => window.clearTimeout(handle)
  }, [simBallMph, simClubMph, simAttackDeg, simPathDeg, simQuality, trackSimLive])

  const matConnections = [bleStatus, usbStatus, xiaoStatus]
  const matConnected = matConnections.some((status) => status.state === 'connected')
  const radarEspConnected = radarStatus.state === 'connected'
  const connected = matConnected
  const anyLinked = matConnected || radarEspConnected
  const connectionError = [...matConnections, radarStatus].find((status) => status.error)?.error
  const metrics = strikeMetrics(swing)
  const score = metrics.quality
  const carryYards = metrics.carryYds
  const clubSpeed = metrics.clubMph
  const ballSpeed = metrics.ballMph
  const smash = metrics.smash
  const radarSpeed = liveTrack.ball_speed_mph ?? (Number.isFinite(swing?.ball_speed_mph) ? swing.ball_speed_mph : null)
  const radarDist = liveTrack.radar_distance_mm ?? (Number.isFinite(swing?.radar_distance_mm) ? swing.radar_distance_mm : null)
  const radarIntra = liveTrack.radar_intra_score ?? (Number.isFinite(swing?.radar_intra_score) ? swing.radar_intra_score : null)
  const radarValid = Boolean(liveTrack.radar_valid || swing?.radar_valid)
  const impactName = useMemo(() => {
    if (swing?.zeroed) return 'Waiting for strike'
    if ((swing?.impact_zone ?? 2) <= 1) return 'Heel-side contact'
    if ((swing?.impact_zone ?? 2) >= 4) return 'Toe-side contact'
    return 'Centered contact'
  }, [swing])

  const connect = async (kind) => {
    const client = kind === 'ble'
      ? golfMatClient
      : kind === 'usb'
        ? golfMatSerialClient
        : kind === 'radar'
          ? radarSerialClient
          : xiaoSerialClient
    setNotice(
      kind === 'ble'
        ? 'Opening Bluetooth picker for mat ESP…'
        : kind === 'radar'
          ? 'Opening serial picker for radar ESP (pick the other COM port)…'
          : `Opening serial picker for ${kind === 'usb' ? 'mat ESP' : 'XIAO'}…`,
    )
    try {
      await client.connect()
      setTrackSimLive(false)
      if (kind !== 'radar') {
        setArmed(false)
        setIsZeroed(false)
        setSwing(zeroSwing)
      }
      setLiveTrack((previous) => ({ ...previous, tracking: true, source: kind, updatedAt: new Date() }))
      setNotice(
        kind === 'ble'
          ? 'Mat Bluetooth linked — FSR / swing packets active.'
          : kind === 'radar'
            ? 'Radar ESP linked — streaming GMRADAR. Keep mat ESP connected separately.'
            : kind === 'usb'
              ? 'Mat ESP USB linked — FSR / swing packets active.'
              : 'XIAO connected — IMU stream active.',
      )
    }
    catch (error) { setNotice(error?.message || 'Connection was not completed.') }
  }

  const applySimParams = (params, { commit = false, label } = {}) => {
    setSimBallMph(Math.round(params.ballSpeedMph))
    setSimClubMph(Math.round(params.clubSpeedMph))
    setSimAttackDeg(Number(params.attackAngleDeg))
    setSimPathDeg(Number(params.swingPathDeg))
    setSimQuality(Math.round(params.quality))
    setTrackSimLive(true)
    const next = simulateSwing({ ...params, preview: !commit })
    if (label) next.label = label
    setSwing(next)
    setLiveTrack({
      tracking: true,
      radar_valid: true,
      ball_speed_mph: next.ball_speed_mph,
      radar_distance_mm: next.radar_distance_mm,
      radar_intra_score: next.radar_intra_score,
      fsr_peaks: [...next.fsr_peaks],
      updatedAt: new Date(),
      source: 'simulate',
    })
    setLastReadingAt(new Date())
    if (commit) {
      setPacketCount((count) => count + 1)
      if (activeSession) setSessionSwings((previous) => [...previous, next])
    }
    return next
  }

  const randomizeSimControls = () => {
    const params = pickBelowAverageSimParams()
    const next = applySimParams(params, { commit: false })
    setNotice(
      `Randomized below-average swing: ${next.ball_speed_mph} mph ball · ${carryYardsFromSwing(next)} yds · quality ${next.impact_quality}`,
    )
  }

  const runSimulatedSwing = () => {
    const params = pickBelowAverageSimParams()
    const next = applySimParams(params, { commit: true, label: 'Simulated Swing' })
    setNotice(
      `Simulated swing: ${next.ball_speed_mph} mph ball · ${next.attack_angle_deg}° attack · ${next.swing_path_deg}° path · ${carryYardsFromSwing(next)} yds · Q${next.impact_quality}`,
    )
  }

  const disconnectMat = async () => {
    setArmed(false)
    setIsZeroed(false)
    await Promise.all([
      golfMatClient.disconnect(),
      golfMatSerialClient.disconnect(),
      xiaoSerialClient.disconnect(),
    ])
    setNotice(radarEspConnected ? 'Mat disconnected — radar ESP still linked.' : 'Mat disconnected.')
  }

  const disconnectRadar = async () => {
    latestRadarRef.current = null
    await radarSerialClient.disconnect()
    setNotice(matConnected ? 'Radar ESP disconnected — mat still linked.' : 'Radar ESP disconnected.')
  }

  const disconnect = async () => {
    setArmed(false)
    setIsZeroed(false)
    latestRadarRef.current = null
    await Promise.all([
      golfMatClient.disconnect(),
      golfMatSerialClient.disconnect(),
      xiaoSerialClient.disconnect(),
      radarSerialClient.disconnect(),
    ])
    setNotice('All devices disconnected.')
  }

  const zeroMat = async () => {
    if (!activeSession) {
      setNotice('Initialize a session first.')
      return
    }
    setCalibrating(true); setNotice('Keep the mat still while it zeros…')
    try {
      if (golfMatSerialClient.connected) await golfMatSerialClient.calibrate()
      await new Promise((resolve) => window.setTimeout(resolve, golfMatSerialClient.connected ? 2700 : 700))
      setArmed(false)
      setIsZeroed(true)
      setSwing(zeroSwing)
      setLastReadingAt(null)
      setPacketCount(0)
      setNotice('Sensors are at zero. Initialize the swing when you are ready.')
    } catch (error) { setNotice(error?.message || 'Could not zero the mat.') }
    finally { setCalibrating(false) }
  }

  const initializeSwing = () => {
    if (!activeSession) return setNotice('Initialize a session first.')
    if (!connected) return setNotice('Connect a device before initializing the swing.')
    if (!isZeroed) return setNotice('Zero the sensors before initializing the swing.')
    setSwing(zeroSwing)
    setArmed(true)
    setNotice('Swing initialized — ready for one deliberate strike.')
  }

  const zeroReadings = async () => {
    setCalibrating(true)
    setNotice('Zeroing all readings…')
    try {
      if (golfMatSerialClient.connected) {
        await golfMatSerialClient.calibrate()
        await new Promise((resolve) => window.setTimeout(resolve, 2700))
      }
      setSwing(zeroSwing)
      setArmed(false)
      setIsZeroed(true)
      setSessionSwings([])
      setSelectedSession(null)
      setLastReadingAt(null)
      setPacketCount(0)
      setNotice(connected ? 'All readings are zero. Ready for the next swing.' : 'Preview readings cleared to zero.')
    } catch (error) { setNotice(error?.message || 'Could not zero readings.') }
    finally { setCalibrating(false) }
  }

  const demoStrike = () => {
    if (!activeSession || !armed) {
      setNotice('Initialize the session, zero it, then initialize the swing first.')
      return
    }
    const next = generateRandomSwing()
    next.label = 'Demo Strike'; next.source = 'demo'
    setSwing(next)
    if (activeSession) setSessionSwings((previous) => [...previous, next])
    setArmed(false)
    setNotice(activeSession ? 'Demo strike added to this session.' : 'Demo strike captured. Start a session to record it.')
  }

  const showSwingExample = (key) => {
    const preset = key === 'random' ? generateRandomSwing() : { ...SWING_PRESETS[key], fsr_peaks: [...SWING_PRESETS[key].fsr_peaks] }
    if (key === 'heel_strike') {
      preset.fsr_peaks = [30, 26, 18, 15, 10, 8]
      preset.impact_quality = 38
      preset.heel_pressure_pct = 55
      preset.center_pressure_pct = 30
      preset.toe_pressure_pct = 15
    }
    const next = { ...preset, label: key === 'random' ? 'Random Swing' : preset.label, source: 'example' }
    setSwing(next)
    if (activeSession) setSessionSwings((previous) => [...previous, next])
    setNotice(`${next.label} example loaded${activeSession ? ' and added to this session' : ''}.`)
  }

  const startSession = () => {
    setActiveSession({ startedAt: new Date(), club })
    setSwing(zeroSwing)
    setArmed(false)
    setIsZeroed(false)
    setLastReadingAt(null)
    setPacketCount(0)
    setSessionSwings([])
    setSelectedSession(null)
    setTab('Lab')
    setNotice('Session initialized at zero. Connect the mat, then zero the sensors.')
  }

  const endSession = () => {
    if (!activeSession) return
    if (sessionSwings.length) {
      const completed = buildSessionSummary(sessionSwings, { club: activeSession.club, when: 'Just now' })
      setSessions((previous) => [completed, ...previous])
      setSelectedSession(completed)
    }
    setActiveSession(null)
    setArmed(false)
    setIsZeroed(false)
    setSessionSwings([])
    setTab('Sessions')
    window.setTimeout(() => document.querySelector('.recent-section')?.scrollIntoView({ behavior: 'smooth' }), 0)
  }

  const liveSessionSummary = useMemo(
    () => (sessionSwings.length ? buildSessionSummary(sessionSwings, { club: activeSession?.club || club }) : null),
    [sessionSwings, activeSession, club],
  )
  const sessionAverage = liveSessionSummary?.score ?? 0
  const sessionBest = liveSessionSummary?.bestCarryYds ?? 0
  const selectTab = (item) => {
    setTab(item)
    window.setTimeout(() => (item === 'Sessions' ? document.querySelector('.recent-section') : document.querySelector('#top'))?.scrollIntoView({ behavior: 'smooth' }), 0)
  }

  return (
    <main className="app-shell">
      <header className="topbar">
        <a className="brand" href="#top" aria-label="Strike Lab home">
          <span className="brand-mark"><GolfBallIcon /></span>
          <span><b>STRIKE</b> LAB</span>
        </a>
        <nav className="desktop-nav" aria-label="Primary navigation">
          {['Lab', 'Sessions', 'Progress'].map((item) => (
            <button key={item} className={tab === item ? 'active' : ''} onClick={() => selectTab(item)}>{item}</button>
          ))}
        </nav>
        <button className="profile-button" aria-label="Open profile"><span>CM</span><span className="profile-copy"><b>Carmine</b><small>12 day streak</small></span></button>
      </header>

      <div className="page" id="top">
        <section className="welcome-row">
          <div>
            <p className="eyebrow">TUESDAY · JULY 21</p>
            <h1>Good afternoon, Carmine.</h1>
            <p>Ready to dial in your next shot?</p>
          </div>
          <button className={`primary-action ${activeSession ? 'session-live-button' : ''}`} onClick={activeSession ? endSession : startSession}><span>{activeSession ? '■' : '＋'}</span> {activeSession ? 'End session' : 'Start new session'}</button>
        </section>

        {activeSession ? <section className="active-session-card">
          <div><span className="recording-dot" /><div><p className="eyebrow">SESSION IN PROGRESS</p><h2>{activeSession.club} practice</h2></div></div>
          <div className="session-live-stats">
            <span><b>{sessionSwings.length}</b> swings</span>
            <span><b>{sessionAverage || '—'}</b> avg score</span>
            <span><b>{sessionBest || '—'}</b> best yds</span>
            <span><b>{liveSessionSummary?.avgBallMph ?? '—'}</b> avg ball</span>
            <span><b>{liveSessionSummary?.avgSmash ?? '—'}</b> smash</span>
            <span><b>{liveSessionSummary ? `${liveSessionSummary.radarHitPct}%` : '—'}</b> radar</span>
          </div>
          <button onClick={endSession}>Finish & save</button>
        </section> : null}

        <section className="dual-connect">
          <article className={`device-dock ${armed ? 'is-armed' : ''}`}>
            <div className="device-state">
              <span className="device-pulse" />
              <div>
                <p className="eyebrow">MAT ESP · FSR / SWING</p>
                <h2>
                  {armed
                    ? 'Ready for one swing'
                    : !activeSession
                      ? 'Initialize a session'
                      : !matConnected
                        ? 'Connect mat ESP'
                        : !isZeroed
                          ? 'Mat linked · Needs zeroing'
                          : 'Zeroed · Initialize swing'}
                </h2>
                <span>
                  {matConnected
                    ? (bleStatus.state === 'connected'
                      ? 'Bluetooth mat linked'
                      : usbStatus.state === 'connected'
                        ? 'USB mat linked'
                        : 'XIAO linked')
                    : 'Pick mat COM / BLE — radar uses a separate board'}
                </span>
              </div>
            </div>
            <div className="device-actions">
              {!matConnected ? <>
                <button onClick={() => connect('ble')} disabled={!bleStatus.supported || bleStatus.state === 'connecting'}>
                  {bleStatus.state === 'connecting' ? 'Pairing…' : 'Mat BLE'}
                </button>
                <button onClick={() => connect('usb')} disabled={!usbStatus.supported || usbStatus.state === 'connecting'}>
                  {usbStatus.state === 'connecting' ? 'Opening…' : 'Mat USB'}
                </button>
                <button onClick={() => connect('xiao')} disabled={!xiaoStatus.supported || xiaoStatus.state === 'connecting'}>XIAO</button>
              </> : <>
                <button className="activate-button" onClick={zeroMat} disabled={!activeSession || calibrating}>{calibrating ? 'Zeroing…' : isZeroed ? 'Re-zero' : 'Zero sensors'}</button>
                <button className="initialize-button" onClick={initializeSwing} disabled={!activeSession || !isZeroed || armed}>{armed ? 'Armed' : 'Initialize swing'}</button>
                <button onClick={disconnectMat}>Disconnect mat</button>
              </>}
              <button onClick={zeroReadings} disabled={!activeSession || !matConnected || calibrating}>Clear to zero</button>
              <button className="demo-button" onClick={demoStrike} disabled={!activeSession || !armed}>Test swing</button>
            </div>
          </article>

          <article className={`device-dock radar-dock ${radarEspConnected ? 'is-linked' : ''}`}>
            <div className="device-state">
              <span className="device-pulse" />
              <div>
                <p className="eyebrow">RADAR ESP · XM125</p>
                <h2>{radarEspConnected ? 'Radar ESP linked' : 'Connect radar ESP'}</h2>
                <span>
                  {radarEspConnected
                    ? `${radarStatus.sampleCount || 0} GMRADAR samples · pick the other COM port from the mat`
                    : 'Flash radar_esp/radar_stream.ino, then connect this board separately'}
                </span>
              </div>
            </div>
            <div className="device-actions">
              {!radarEspConnected ? (
                <button className="activate-button" onClick={() => connect('radar')} disabled={!radarStatus.supported || radarStatus.state === 'connecting'}>
                  {radarStatus.state === 'connecting' ? 'Opening…' : 'Connect Radar USB'}
                </button>
              ) : (
                <button onClick={disconnectRadar}>Disconnect radar</button>
              )}
              {anyLinked ? <button onClick={disconnect}>Disconnect all</button> : null}
            </div>
          </article>
        </section>

        {(connectionError || notice) ? <p className="dock-notice">{connectionError || notice}</p> : null}

        <RadarTrackPanel
          matLinked={matConnected}
          radarLinked={radarEspConnected}
          tracking={liveTrack.tracking}
          radarValid={radarValid}
          radarSpeed={radarSpeed}
          radarDist={radarDist}
          radarIntra={radarIntra}
          radarStatus={radarStatus}
          updatedAt={liveTrack.updatedAt}
          onConnectRadar={() => connect('radar')}
          onDisconnectRadar={disconnectRadar}
        />

        <SwingSimPanel
          ballMph={simBallMph}
          clubMph={simClubMph}
          attackDeg={simAttackDeg}
          pathDeg={simPathDeg}
          quality={simQuality}
          trackLive={trackSimLive}
          onBallMph={setSimBallMph}
          onClubMph={setSimClubMph}
          onAttackDeg={setSimAttackDeg}
          onPathDeg={setSimPathDeg}
          onQuality={setSimQuality}
          onTrackLive={setTrackSimLive}
          onRandomize={randomizeSimControls}
          onSimulate={runSimulatedSwing}
        />

        <WorkflowSteps activeSession={activeSession} connected={connected} isZeroed={isZeroed} armed={armed} />

        <LiveSensorMonitor
          swing={swing}
          liveTrack={liveTrack}
          connected={anyLinked || liveTrack.tracking}
          armed={armed}
          lastReadingAt={lastReadingAt}
          packetCount={packetCount}
          statuses={{ ble: bleStatus, usb: usbStatus, xiao: xiaoStatus, radar: radarStatus }}
        />

        <section className="hero-grid">
          <article className="hero-card">
            <div className="hero-topline">
              <span className="live-chip"><i /> {liveTrack.tracking ? 'TRACKING' : 'STRIKE LAB'}</span>
              <span className="more">•••</span>
            </div>
            <div className="hero-content">
              <div>
                <p className="hero-kicker">LAST STRIKE</p>
                <div className="hero-number">{carryYards}<span>yds</span></div>
                <h2>{score >= 85 ? 'Pure contact.' : score >= 60 ? 'Solid strike.' : swing?.zeroed ? 'Waiting.' : 'Keep working.'}</h2>
                <p className="hero-note">{impactName} · {swing?.direction_label || 'Straight'} · {ballSpeed} mph ball</p>
              </div>
              <StrikeGraphic />
            </div>
            <div className="metric-row">
              <Metric label="Club speed" value={clubSpeed} unit="mph" />
              <Metric label="Ball speed" value={ballSpeed} unit="mph" />
              <Metric label="Smash" value={smash ?? '—'} unit={smash != null ? 'x' : ''} />
              <Metric label="Attack" value={metrics.attack} unit="°" />
              <Metric label="Path" value={metrics.path} unit="°" />
              <Metric label="Radar" value={radarValid ? 'On' : '—'} unit="" />
            </div>
          </article>

          <article className="score-card">
            <div className="score-heading"><span>STRIKE SUMMARY</span><span className="trend">{score >= 85 ? 'Pure' : score >= 60 ? 'Solid' : 'Work'}</span></div>
            <div className="score-ring" style={{ background: `conic-gradient(#1b9b5e 0 ${score}%,#e8f6ee ${score}% 100%)` }}><div><b>{score}</b><span>{score >= 85 ? 'Excellent' : score >= 60 ? 'Good' : 'Building'}</span></div></div>
            <div className="strike-summary-grid">
              <span><b>{carryYards}</b>carry yds</span>
              <span><b>{ballSpeed}</b>ball mph</span>
              <span><b>{clubSpeed}</b>club mph</span>
              <span><b>{smash ?? '—'}</b>smash</span>
              <span><b>{metrics.attack}°</b>attack</span>
              <span><b>{metrics.path}°</b>path</span>
              <span><b>{metrics.heel}/{metrics.center}/{metrics.toe}</b>H/C/T</span>
              <span><b>{radarValid ? `${Number(radarSpeed ?? 0).toFixed(0)}` : '—'}</b>radar mph</span>
            </div>
            <div className="score-footer"><span>Impact</span><b>{impactName.replace('-side contact','').replace(' contact','')}</b></div>
          </article>
        </section>

        <section className="path-panel">
          <div className="panel-heading">
            <div><p className="eyebrow">3D SWING PATH</p><h2>Tracked club-head arc</h2></div>
            <span className={liveTrack.tracking ? 'heat-live' : ''}>{liveTrack.tracking ? '● Live tracking' : 'Idle'}</span>
          </div>
          <SwingVisualizer3D swing={swing} club={club === 'Driver' ? 'driver' : club === 'PW' ? 'wedge' : 'iron7'} />
        </section>

        <GradePanel swing={swing} />
        <SwingExamples current={swing?.label} onSelect={showSwingExample} />

        <section className="content-grid">
          <article className="panel strike-panel">
            <div className="panel-heading">
              <div><p className="eyebrow">IMPACT ANALYSIS</p><h2>Where you struck it</h2></div>
              <div className="club-picker">
                {['Driver', '7 Iron', 'PW'].map((item) => <button key={item} onClick={() => setClub(item)} className={club === item ? 'active' : ''}>{item}</button>)}
              </div>
            </div>
            <div className="impact-area">
              <div className="club-face">
                <span className="groove g1" /><span className="groove g2" /><span className="groove g3" /><span className="groove g4" /><span className="groove g5" />
                <span className="impact-ripple r3" /><span className="impact-ripple r2" /><span className="impact-ripple r1" /><span className="impact-dot" />
              </div>
              <div className="impact-copy"><span className="success-icon">✓</span><div><b>{impactName}</b><p>{swing?.heel_pressure_pct ?? 0}% heel · {swing?.center_pressure_pct ?? 0}% center · {swing?.toe_pressure_pct ?? 0}% toe</p></div></div>
            </div>
            <PressureHeatmap swing={swing} armed={armed || liveTrack.tracking} />
          </article>

          <article className="panel coach-panel">
            <div className="coach-icon">✦</div>
            <p className="eyebrow">COACH'S NOTE</p>
            <h2>{coachTitle(swing)}</h2>
            <p>{coachCopy(swing, ballSpeed, clubSpeed)}</p>
            <button className="text-action">View full analysis <span>→</span></button>
          </article>
        </section>

        <section className="recent-section">
          <div className="section-heading"><div><p className="eyebrow">YOUR ACTIVITY</p><h2>{tab === 'Sessions' ? 'All sessions' : 'Recent sessions'}</h2></div><button onClick={() => setTab(tab === 'Sessions' ? 'Lab' : 'Sessions')}>{tab === 'Sessions' ? 'Back to lab' : 'View all'} <span>→</span></button></div>
          {selectedSession ? <SessionSummaryDetail session={selectedSession} onClose={() => setSelectedSession(null)} /> : null}
          <div className="session-list">
            {sessions.map((session, index) => (
              <article className="session-row" key={session.id}>
                <span className="club-icon"><ClubIcon /></span>
                <div className="session-name"><b>{session.club} practice</b><span>{session.when} · {session.swings} swings</span></div>
                <div className="session-distance"><b>{session.distance}</b><span>best carry</span></div>
                <span className={`session-score ${session.tone}`}>{session.score}</span>
                <button className="row-arrow" onClick={() => setSelectedSession(session)} aria-label={`View ${session.club} session`}>→</button>
              </article>
            ))}
          </div>
        </section>
      </div>

      <nav className="mobile-nav" aria-label="Mobile navigation">
        {['Lab', 'Sessions', 'Progress'].map((item) => <button key={item} onClick={() => selectTab(item)} className={tab === item ? 'active' : ''}><span>{item === 'Lab' ? '⌂' : item === 'Sessions' ? '◫' : '↗'}</span>{item}</button>)}
      </nav>
    </main>
  )
}

function Metric({ label, value, unit }) {
  return <div className="metric"><span>{label}</span><strong>{value}<small>{unit}</small></strong></div>
}

function carryYardsFromSwing(swing) {
  return Math.round((swing?.estimated_distance_m ?? 0) * 1.09361)
}

function coachTitle(swing) {
  if (swing?.zeroed) return 'Take a swing to coach it.'
  if ((swing?.impact_quality ?? 0) >= 85) return 'Keep that tempo.'
  if (Math.abs(swing?.swing_path_deg ?? 0) > 4) return 'Quiet the path first.'
  if ((swing?.attack_angle_deg ?? 0) < -6) return 'Shallow the attack.'
  return 'Solid building block.'
}

function coachCopy(swing, ballSpeed, clubSpeed) {
  if (swing?.zeroed) {
    return 'Connect the mat ESP and radar ESP (separate COM ports), or use the simulator to populate the lab.'
  }
  const smash = clubSpeed > 0 ? (ballSpeed / clubSpeed).toFixed(2) : '—'
  return `Ball ${ballSpeed} mph · club ${clubSpeed} mph · smash ${smash} · attack ${Number(swing?.attack_angle_deg ?? 0).toFixed(1)}° · path ${Number(swing?.swing_path_deg ?? 0).toFixed(1)}°. Pressure ${swing?.heel_pressure_pct ?? 0}/${swing?.center_pressure_pct ?? 0}/${swing?.toe_pressure_pct ?? 0} heel/center/toe${swing?.radar_valid ? ` · radar locked` : ''}.`
}

function RadarTrackPanel({
  matLinked, radarLinked, tracking, radarValid, radarSpeed, radarDist, radarIntra, radarStatus, updatedAt, onConnectRadar, onDisconnectRadar,
}) {
  const linked = radarLinked || (tracking && radarValid)
  return (
    <section className={`radar-panel ${linked ? 'connected' : ''}`}>
      <div className="radar-heading">
        <div>
          <p className="eyebrow">XM125 RADAR · SEPARATE ESP</p>
          <h2>
            {radarLinked
              ? (radarValid ? 'Radar motion locked' : 'Radar ESP streaming')
              : tracking && radarValid
                ? 'Radar values from mat packet / sim'
                : 'Radar ESP not connected'}
          </h2>
          <span>
            {radarValid
              ? `Live ${Number(radarSpeed).toFixed(1)} mph · dist ${radarDist ?? '—'} mm · intra ${radarIntra ?? '—'}${updatedAt ? ` · ${updatedAt.toLocaleTimeString()}` : ''}`
              : radarLinked
                ? 'Waiting for motion above threshold…'
                : matLinked
                  ? 'Mat is linked. Connect Radar USB on the second COM port for ball speed.'
                  : radarStatus?.supported
                    ? 'Flash radar_esp/radar_stream.ino, then Connect Radar USB.'
                    : 'Web Serial needs Chrome/Edge on HTTPS or localhost.'}
          </span>
        </div>
        {!radarLinked ? (
          <button type="button" onClick={onConnectRadar} disabled={!radarStatus?.supported || radarStatus?.state === 'connecting'}>
            {radarStatus?.state === 'connecting' ? 'Opening…' : 'Connect Radar USB'}
          </button>
        ) : (
          <div className="radar-side">
            <div className="radar-stats">
              <span><b>{radarValid ? Number(radarSpeed ?? 0).toFixed(1) : '—'}</b>mph</span>
              <span><b>{radarDist ?? '—'}</b>mm</span>
              <span><b>{radarIntra ?? '—'}</b>intra</span>
            </div>
            <button type="button" className="radar-disconnect" onClick={onDisconnectRadar}>Disconnect</button>
          </div>
        )}
      </div>
    </section>
  )
}

function SessionSummaryDetail({ session, onClose }) {
  const snaps = session.swingSnapshots || []
  return (
    <div className="session-detail rich">
      <div className="session-detail-head">
        <div>
          <p className="eyebrow">SESSION SUMMARY</p>
          <h3>{session.club} practice</h3>
          <p>{session.when} · {session.swings} swings</p>
        </div>
        <button onClick={onClose}>Close</button>
      </div>
      <div className="summary-stats">
        <span><b>{session.score}</b>avg score</span>
        <span><b>{session.distance}</b>best carry</span>
        <span><b>{session.avgBallMph ?? '—'}</b>avg ball</span>
        <span><b>{session.bestBallMph ?? '—'}</b>best ball</span>
        <span><b>{session.avgClubMph ?? '—'}</b>avg club</span>
        <span><b>{session.avgSmash ?? '—'}</b>smash</span>
        <span><b>{session.radarHitPct ?? 0}%</b>radar hits</span>
        <span><b>{session.avgAttackDeg ?? '—'}°</b>attack</span>
        <span><b>{session.avgPathDeg ?? '—'}°</b>path</span>
        <span><b>{session.centeredPct ?? 0}%</b>centered</span>
        <span><b>{session.avgHeelPct ?? '—'}/{session.avgCenterPct ?? '—'}/{session.avgToePct ?? '—'}</b>H/C/T</span>
      </div>
      {snaps.length ? (
        <div className="summary-swings">
          <p className="eyebrow">RECENT STRIKES</p>
          <div className="summary-swing-list">
            {snaps.map((item) => (
              <div key={item.n} className="summary-swing-row">
                <b>#{item.n}</b>
                <span>{item.score} pts</span>
                <span>{item.carryYds} yds</span>
                <span>{item.ballMph} mph ball</span>
                <span>{item.smash ?? '—'} smash</span>
                <span>{item.attack ?? '—'}° / {item.path ?? '—'}°</span>
                <span>{item.radar ? 'radar' : 'no radar'}</span>
              </div>
            ))}
          </div>
        </div>
      ) : null}
    </div>
  )
}

function SwingSimPanel({
  ballMph, clubMph, attackDeg, pathDeg, quality, trackLive,
  onBallMph, onClubMph, onAttackDeg, onPathDeg, onQuality, onTrackLive, onRandomize, onSimulate,
}) {
  return (
    <section className="sim-panel">
      <div className="sim-heading">
        <div>
          <p className="eyebrow">SWING SIMULATOR</p>
          <h2>Below-average mid-handicap swings</h2>
          <span>
            {trackLive
              ? 'Live track on — Randomize / Simulate picks a new missy swing each time (not a fixed 150 yd shot).'
              : 'Randomize for a fresh below-average strike, or nudge the sliders yourself.'}
          </span>
        </div>
        <div className="sim-actions">
          <label className="sim-toggle">
            <input type="checkbox" checked={trackLive} onChange={(e) => onTrackLive(e.target.checked)} />
            Live track
          </label>
          <button type="button" className="sim-random" onClick={onRandomize}>Randomize</button>
          <button type="button" className="sim-run" onClick={onSimulate}>Simulate swing</button>
        </div>
      </div>
      <div className="sim-grid">
        <label>
          <span>Ball speed <b>{ballMph} mph</b></span>
          <input type="range" min="50" max="180" value={ballMph} onChange={(e) => onBallMph(Number(e.target.value))} />
        </label>
        <label>
          <span>Club speed <b>{clubMph} mph</b></span>
          <input type="range" min="40" max="130" value={clubMph} onChange={(e) => onClubMph(Number(e.target.value))} />
        </label>
        <label>
          <span>Attack angle <b>{attackDeg}°</b></span>
          <input type="range" min="-12" max="8" step="0.5" value={attackDeg} onChange={(e) => onAttackDeg(Number(e.target.value))} />
        </label>
        <label>
          <span>Swing path <b>{pathDeg}°</b></span>
          <input type="range" min="-12" max="12" step="0.5" value={pathDeg} onChange={(e) => onPathDeg(Number(e.target.value))} />
        </label>
        <label>
          <span>Impact quality <b>{quality}</b></span>
          <input type="range" min="20" max="100" value={quality} onChange={(e) => onQuality(Number(e.target.value))} />
        </label>
      </div>
    </section>
  )
}

function WorkflowSteps({ activeSession, connected, isZeroed, armed }) {
  const steps = [
    { label: 'Session', done: Boolean(activeSession), active: !activeSession },
    { label: 'Connect', done: connected, active: activeSession && !connected },
    { label: 'Zero', done: isZeroed, active: connected && !isZeroed },
    { label: 'Initialize swing', done: armed, active: isZeroed && !armed },
    { label: 'Strike', done: false, active: armed },
  ]
  return <section className="workflow-steps" aria-label="Session setup progress">
    {steps.map((step, index) => <div key={step.label} className={`${step.done ? 'done' : ''} ${step.active ? 'active' : ''}`}><i>{step.done ? '✓' : index + 1}</i><span>{step.label}</span></div>)}
  </section>
}

function PressureHeatmap({ swing, armed }) {
  const values = Array.from({ length: 6 }, (_, index) => Number(swing?.fsr_peaks?.[index]) || 0)
  const max = 180
  const impact = Number(swing?.impact_zone ?? -1)
  return <div className="heatmap-block">
    <div className="heatmap-heading"><div><p className="eyebrow">LIVE PRESSURE MAP</p><h3>Six-sensor strike heat</h3></div><span className={armed ? 'heat-live' : ''}>{armed ? '● Live · waiting for strike' : 'Latest strike'}</span></div>
    <div className="heatmap-wrap">
      <span className="heat-side heel-label">HEEL</span>
      <div className="heat-grid" role="img" aria-label="Six sensor pressure heat map from heel to toe">
        {values.map((value, index) => {
          const intensity = Math.min(1, value / max)
          const hue = 55 - intensity * 50
          const light = 93 - intensity * 43
          return <div key={index} className={`heat-cell ${index === impact ? 'impact-cell' : ''}`} style={{ background: value === 0 ? '#dfe9e3' : `hsl(${hue} 88% ${light}%)`, boxShadow: index === impact ? `0 0 ${18 + intensity * 20}px hsla(${hue} 90% 48% / .38)` : 'none' }} aria-label={`Sensor ${index + 1}, pressure ${value}`} title={`S${index + 1}`}>
            <small>S{index + 1}</small>
          </div>
        })}
      </div>
      <span className="heat-side toe-label">TOE</span>
    </div>
    <div className="heat-legend"><span>Low pressure</span><i /><span>Peak pressure</span></div>
  </div>
}

function LiveSensorMonitor({ swing, liveTrack, connected, armed, lastReadingAt, packetCount, statuses }) {
  const values = Array.from(
    { length: 6 },
    (_, index) => Number(liveTrack?.fsr_peaks?.[index] ?? swing?.fsr_peaks?.[index]) || 0,
  )
  const peak = Math.max(...values)
  const peakIndex = peak > 0 ? values.indexOf(peak) + 1 : 0
  const links = []
  if (statuses.ble?.state === 'connected') links.push('Mat BLE')
  if (statuses.usb?.state === 'connected') links.push('Mat USB')
  if (statuses.xiao?.state === 'connected') links.push('XIAO')
  if (statuses.radar?.state === 'connected') links.push('Radar USB')
  if (liveTrack?.source === 'simulate' && !links.length) links.push('Simulator')
  const source = links.length ? links.join(' + ') : 'No device'
  return <section className={`live-monitor ${connected ? 'connected' : ''}`}>
    <div className="monitor-status">
      <span className="monitor-pulse" />
      <div>
        <p className="eyebrow">LIVE READINGS</p>
        <h2>{connected || links.length ? `${source} · tracking` : 'Waiting for a device'}</h2>
        <small>
          {lastReadingAt
            ? `Last update ${lastReadingAt.toLocaleTimeString()} · ${packetCount} packets`
            : links.length
              ? 'Connected — waiting for sensor data'
              : 'Connect mat ESP + radar ESP (two COM ports), or use the simulator'}
        </small>
      </div>
    </div>
    <div className="live-sensors">{values.map((value, index) => <div key={index} className={index + 1 === peakIndex ? 'peak' : ''}><span>S{index + 1}</span><i><b style={{ width: `${Math.min(100, (value / 180) * 100)}%` }} /></i><strong>{value}</strong></div>)}</div>
    <div className="monitor-meta">
      <span><b>{peak || 0}</b>peak</span>
      <span><b>{peakIndex ? `S${peakIndex}` : '—'}</b>sensor</span>
      <span><b>{liveTrack?.tracking ? 'Tracking' : armed ? 'Armed' : 'Idle'}</b>state</span>
    </div>
  </section>
}

function GradePanel({ swing }) {
  const isZero = Boolean(swing?.zeroed)
  const contact = isZero ? 0 : Math.round(swing?.impact_quality || 0)
  const path = isZero ? 0 : Math.max(0, Math.round(100 - Math.abs(swing?.swing_path_deg || 0) * 9))
  const attack = isZero ? 0 : Math.max(0, Math.round(100 - Math.abs((swing?.attack_angle_deg || 0) + 3) * 12))
  const overall = isZero ? 0 : Math.round((contact * .55) + (path * .25) + (attack * .2))
  const items = [
    { label: 'Overall', value: overall, note: isZero ? 'Waiting' : 'Combined strike grade' },
    { label: 'Contact', value: contact, note: 'Impact quality' },
    { label: 'Swing path', value: path, note: `${isZero ? 0 : swing?.swing_path_deg || 0}° path` },
    { label: 'Attack', value: attack, note: `${isZero ? 0 : swing?.attack_angle_deg || 0}° angle` },
  ]
  return <section className={`grade-panel ${isZero ? 'is-zero' : ''}`}>
    <div className="grade-title"><p className="eyebrow">STRIKE GRADES</p><h2>{isZero ? 'Take a swing to grade it' : 'Your swing report'}</h2></div>
    <div className="grade-grid">{items.map((item) => <div className="grade-item" key={item.label}><span className={`letter-grade grade-${letterFor(item.value).toLowerCase()}`}>{isZero ? '—' : letterFor(item.value)}</span><div><b>{item.label}</b><small>{item.note}</small></div><strong>{item.value}</strong></div>)}</div>
  </section>
}

function SwingExamples({ current, onSelect }) {
  const examples = [
    { key: 'perfect', title: 'Perfect', note: 'Centered · straight', mark: '●' },
    { key: 'heel_strike', title: 'Heel', note: 'Pressure left', mark: '◐' },
    { key: 'toe_strike', title: 'Toe', note: 'Pressure right', mark: '◑' },
    { key: 'thin_hit', title: 'Thin', note: 'Low, weak contact', mark: '▬' },
    { key: 'random', title: 'Random', note: 'Below-avg vary', mark: '✦' },
  ]
  return <section className="swing-examples">
    <div><p className="eyebrow">COMPARE CONTACT</p><h2>What different swings look like</h2><span>Select one to update every reading and the heat map.</span></div>
    <div className="example-grid">{examples.map((example) => <button key={example.key} className={current?.toLowerCase().includes(example.title.toLowerCase()) ? 'active' : ''} onClick={() => onSelect(example.key)}><i>{example.mark}</i><span><b>{example.title}</b><small>{example.note}</small></span></button>)}</div>
  </section>
}

function letterFor(value) {
  if (value >= 93) return 'A'
  if (value >= 85) return 'B'
  if (value >= 72) return 'C'
  if (value >= 60) return 'D'
  return 'F'
}

function GolfBallIcon() {
  return <svg viewBox="0 0 40 40" aria-hidden="true"><circle cx="20" cy="19" r="13" fill="currentColor"/><circle cx="15" cy="14" r="1.2"/><circle cx="21" cy="12" r="1.2"/><circle cx="25" cy="17" r="1.2"/><circle cx="18" cy="20" r="1.2" fill="#1b9b5e"/><path d="M20 32v5M14 37h12" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round"/></svg>
}

function ClubIcon() {
  return <svg viewBox="0 0 32 32" aria-hidden="true"><path d="M21 4 13 23" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round"/><path d="m13 22-5 2c-2 .8-1.2 3.8.9 3.5l7.3-1.2c1.8-.3 2-2.8.3-3.4L13 22Z" fill="currentColor"/></svg>
}

function StrikeGraphic() {
  return <div className="shot-graphic" aria-hidden="true"><span className="shot-line" /><span className="shot-ball" /><span className="shot-target"><i /></span><span className="yard yard-one">84</span><span className="yard yard-two">126</span></div>
}
