import { useEffect, useMemo, useRef, useState } from 'react'
import { Canvas, useFrame } from '@react-three/fiber'
import { Line, OrbitControls } from '@react-three/drei'
import * as THREE from 'three'
import { getPathColor } from '../engine/SwingGrader'
import { buildGolfSwingPath } from '../engine/SwingArc.js'
import { findTopOfSwing } from '../engine/swingPathMeta.js'
import { REFERENCE_SWINGS } from '../data/referenceSwings'

const VIEWPORT_STYLE = {
  width: '100%',
  height: 460,
  background: 'linear-gradient(180deg, #0b1624 0%, #102719 55%, #0f1f14 100%)',
  border: '1px solid #1e293b',
  borderRadius: 16,
  overflow: 'hidden',
  position: 'relative',
}

const TMP = {
  mid: new THREE.Vector3(),
  dir: new THREE.Vector3(),
  up: new THREE.Vector3(0, 1, 0),
  x: new THREE.Vector3(1, 0, 0),
  quat: new THREE.Quaternion(),
  grip: new THREE.Vector3(),
}

const isPathPoint = (point) =>
  Array.isArray(point) &&
  point.length >= 3 &&
  point.slice(0, 3).every((value) => Number.isFinite(Number(value)))

function getValidPathPoints(pathPoints) {
  if (!Array.isArray(pathPoints)) return []
  return pathPoints
    .filter(isPathPoint)
    .map(([x, y, z]) => [Number(x), Number(y), Number(z)])
}

function densifyPath(points, samples = 72) {
  if (points.length < 2) return points.map((p) => new THREE.Vector3(...p))
  const vectors = points.map((p) => new THREE.Vector3(...p))
  const lengths = [0]
  for (let i = 1; i < vectors.length; i += 1) {
    lengths.push(lengths[i - 1] + vectors[i - 1].distanceTo(vectors[i]))
  }
  const total = lengths.at(-1) || 1
  const result = []
  for (let i = 0; i < samples; i += 1) {
    const target = (i / (samples - 1)) * total
    let seg = 1
    while (seg < lengths.length && lengths[seg] < target) seg += 1
    const a = vectors[seg - 1]
    const b = vectors[Math.min(seg, vectors.length - 1)]
    const span = lengths[seg] - lengths[seg - 1] || 1
    const t = THREE.MathUtils.clamp((target - lengths[seg - 1]) / span, 0, 1)
    result.push(a.clone().lerp(b, t))
  }
  return result
}

function clubStyle(club) {
  if (club === 'driver') {
    return {
      shaftLength: 1.05,
      head: [0.16, 0.07, 0.1],
      headColor: '#c4b5a0',
      label: 'Driver',
    }
  }
  if (club === 'wedge') {
    return {
      shaftLength: 0.82,
      head: [0.1, 0.055, 0.05],
      headColor: '#cbd5e1',
      label: 'Wedge',
    }
  }
  return {
    shaftLength: 0.9,
    head: [0.11, 0.05, 0.055],
    headColor: '#e2e8f0',
    label: 'Iron',
  }
}

/** Club-only replay — head on swing arc, grip on hand arc (real shaft orientation). */
function AnimatedClub({ pathPoints, handPoints, playing, club }) {
  const denseHead = useMemo(() => densifyPath(pathPoints, 96), [pathPoints])
  const denseHands = useMemo(() => {
    if (handPoints?.length >= 2) return densifyPath(handPoints, 96)
    // Fallback: grip trails toward a fixed torso pivot.
    return denseHead.map((tip) => {
      const pivot = new THREE.Vector3(0.05, 1.02, 0.58)
      return pivot.clone().lerp(tip, 0.38)
    })
  }, [handPoints, denseHead])
  const style = useMemo(() => clubStyle(club), [club])
  const progress = useRef(0)
  const shaft = useRef()
  const head = useRef()
  const grip = useRef()

  useEffect(() => {
    progress.current = 0
  }, [denseHead])

  useFrame((_, delta) => {
    if (!denseHead.length) return
    if (playing) {
      // Ease through top & finish so those poses read clearly.
      const p = progress.current
      let rate = 0.38
      if (p > 0.32 && p < 0.44) rate = 0.16 // hold the top
      if (p > 0.86) rate = 0.22 // settle into finish
      progress.current = (progress.current + delta * rate) % 1
    }

    const index = Math.min(
      denseHead.length - 1,
      Math.floor(progress.current * (denseHead.length - 1)),
    )
    const tip = denseHead[index]
    const hands = denseHands[Math.min(index, denseHands.length - 1)]

    TMP.grip.copy(hands)
    TMP.dir.copy(tip).sub(TMP.grip)
    const length = Math.max(0.2, TMP.dir.length())
    TMP.mid.copy(TMP.grip).add(tip).multiplyScalar(0.5)
    TMP.quat.setFromUnitVectors(TMP.up, TMP.dir.normalize())

    if (shaft.current) {
      shaft.current.position.copy(TMP.mid)
      shaft.current.quaternion.copy(TMP.quat)
      shaft.current.scale.set(1, length, 1)
    }
    if (grip.current) {
      grip.current.position.copy(TMP.grip)
      grip.current.quaternion.copy(TMP.quat)
    }
    if (head.current) {
      head.current.position.copy(tip)
      const faceDir = new THREE.Vector3().subVectors(tip, hands).normalize()
      TMP.quat.setFromUnitVectors(TMP.x, faceDir)
      head.current.quaternion.copy(TMP.quat)
    }
  })

  return (
    <group>
      <mesh ref={shaft} castShadow>
        <cylinderGeometry args={[0.011, 0.014, 1, 8]} />
        <meshStandardMaterial color="#94a3b8" metalness={0.75} roughness={0.22} />
      </mesh>
      <mesh ref={grip} castShadow>
        <cylinderGeometry args={[0.02, 0.018, 0.14, 8]} />
        <meshStandardMaterial color="#1e293b" roughness={0.85} />
      </mesh>
      <mesh ref={head} castShadow>
        <boxGeometry args={style.head} />
        <meshStandardMaterial
          color={style.headColor}
          metalness={0.85}
          roughness={0.2}
        />
      </mesh>
    </group>
  )
}

function TopOfSwingMarker({ top }) {
  if (!top?.point) return null
  return (
    <group position={top.point}>
      <mesh>
        <sphereGeometry args={[0.06, 16, 16]} />
        <meshStandardMaterial
          color="#38bdf8"
          emissive="#0ea5e9"
          emissiveIntensity={0.75}
        />
      </mesh>
      <mesh position={[0, 0.18, 0]}>
        <coneGeometry args={[0.045, 0.11, 8]} />
        <meshStandardMaterial color="#38bdf8" />
      </mesh>
    </group>
  )
}

function FollowThroughMarker({ follow }) {
  if (!follow?.point) return null
  return (
    <group position={follow.point}>
      <mesh>
        <sphereGeometry args={[0.055, 16, 16]} />
        <meshStandardMaterial
          color="#fbbf24"
          emissive="#f59e0b"
          emissiveIntensity={0.65}
        />
      </mesh>
      <mesh position={[0, 0.17, 0]}>
        <coneGeometry args={[0.04, 0.1, 8]} />
        <meshStandardMaterial color="#fbbf24" />
      </mesh>
    </group>
  )
}

function ImpactMarker() {
  const markerRef = useRef(null)
  useFrame(({ clock }) => {
    if (!markerRef.current) return
    markerRef.current.scale.setScalar(1 + Math.sin(clock.elapsedTime * 4) * 0.12)
  })
  return (
    <mesh ref={markerRef} position={[0, 0.03, 0]}>
      <sphereGeometry args={[0.038, 18, 18]} />
      <meshStandardMaterial color="#fff" emissive="#fff" emissiveIntensity={0.45} />
    </mesh>
  )
}

function SwingPath({ pathPoints, grade, impactProgress = 0.58 }) {
  const safeGrade = grade?.attackGrade ? grade : { attackGrade: 'green' }
  const segments = useMemo(
    () =>
      pathPoints.slice(1).map((end, index) => ({
        start: pathPoints[index],
        end,
        color: getPathColor(index + 1, pathPoints.length, safeGrade, impactProgress),
      })),
    [pathPoints, safeGrade.attackGrade, impactProgress],
  )

  return (
    <group>
      {segments.map((segment, index) => (
        <Line
          key={index}
          points={[segment.start, segment.end]}
          color={segment.color}
          lineWidth={3}
          transparent
          opacity={0.85}
        />
      ))}
      <ImpactMarker />
    </group>
  )
}

function ReferencePath({ club }) {
  const reference = REFERENCE_SWINGS[club] ?? REFERENCE_SWINGS.iron7
  const points = useMemo(() => (
    buildGolfSwingPath({
      sampleCount: 48,
      swingPathDeg: reference?.swingPathDeg ?? 0,
      attackAngleDeg: reference?.attackAngleDeg ?? -3.5,
      topHeight: 1.5,
      quality: 100,
    }).path_points
  ), [reference])

  return (
    <Line
      points={points}
      color="#ffffff"
      lineWidth={1}
      dashed
      dashSize={0.07}
      gapSize={0.055}
      opacity={0.28}
      transparent
      depthWrite={false}
    />
  )
}

function SceneEnvironment() {
  return (
    <group>
      <mesh position={[0, -0.02, 0]} rotation={[-Math.PI / 2, 0, 0]} receiveShadow>
        <circleGeometry args={[3.4, 48]} />
        <meshStandardMaterial color="#1a4d2e" roughness={0.95} />
      </mesh>
      <mesh position={[0, -0.015, 0]} rotation={[-Math.PI / 2, 0, 0]} receiveShadow>
        <planeGeometry args={[2.2, 1.3]} />
        <meshStandardMaterial color="#2f6b3c" roughness={0.9} />
      </mesh>
      <gridHelper args={[5, 16, '#3d6b4a', '#244a31']} position={[0, -0.01, 0]} />
      <Line
        points={[[-1.9, 0.01, 0], [2.1, 0.01, 0]]}
        color="#86efac"
        lineWidth={1.5}
        dashed
        dashSize={0.1}
        gapSize={0.06}
        opacity={0.75}
        transparent
      />
      <mesh position={[0, 0.035, 0]} castShadow>
        <sphereGeometry args={[0.035, 18, 18]} />
        <meshStandardMaterial color="#f8fafc" roughness={0.35} />
      </mesh>
    </group>
  )
}

function EmptyVisualizer({ hasSwing }) {
  return (
    <div
      style={{
        ...VIEWPORT_STYLE,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        textAlign: 'center',
        padding: 24,
        boxSizing: 'border-box',
      }}
    >
      <div>
        <div style={{ color: '#cbd5e1', fontSize: 16, fontWeight: 600 }}>
          {hasSwing ? 'No swing path samples available' : 'Choose a swing to visualize'}
        </div>
        <div style={{ color: '#64748b', fontSize: 13, marginTop: 6 }}>
          Select a preset or connect live hardware to replay the club path.
        </div>
      </div>
    </div>
  )
}

export default function SwingVisualizer3D({ swing, grade, club = 'iron7' }) {
  const pathPoints = useMemo(
    () => getValidPathPoints(swing?.path_points),
    [swing?.path_points],
  )
  const topOfSwing = useMemo(
    () => swing?.top_of_swing ?? findTopOfSwing(pathPoints),
    [swing?.top_of_swing, pathPoints],
  )
  const followThrough = swing?.follow_through
  const impactProgress = useMemo(() => {
    if (!pathPoints.length) return 0.58
    if (Number.isFinite(swing?.top_of_swing?.impactIndex)) {
      return swing.top_of_swing.impactIndex / Math.max(1, pathPoints.length - 1)
    }
    // Fallback: nearest point to origin is impact.
    let best = 0
    let bestDist = Infinity
    pathPoints.forEach((point, index) => {
      const dist = Math.hypot(point[0], point[1], point[2])
      if (dist < bestDist) {
        bestDist = dist
        best = index
      }
    })
    return best / Math.max(1, pathPoints.length - 1)
  }, [pathPoints, swing?.top_of_swing?.impactIndex])
  const [playing, setPlaying] = useState(true)
  const style = clubStyle(club)
  const swingKey = `${swing?.timestamp_ms ?? ''}-${swing?.label ?? ''}-${pathPoints.length}`

  useEffect(() => {
    setPlaying(true)
  }, [swingKey])

  if (pathPoints.length < 2) {
    return <EmptyVisualizer hasSwing={Boolean(swing)} />
  }

  return (
    <div style={VIEWPORT_STYLE} aria-label="Club swing path replay">
      <Canvas
        camera={{ position: [2.6, 1.7, 2.9], fov: 44, near: 0.1, far: 50 }}
        dpr={[1, 2]}
        gl={{ antialias: true }}
        shadows
        style={{ background: 'transparent', touchAction: 'none' }}
      >
        <ambientLight intensity={0.7} />
        <hemisphereLight args={['#dbeafe', '#102719', 0.7]} />
        <directionalLight position={[4.5, 7, 3]} intensity={1.35} castShadow />

        <SceneEnvironment />
        <ReferencePath club={club} />
        <SwingPath
          pathPoints={pathPoints}
          grade={grade}
          impactProgress={impactProgress}
        />
        <TopOfSwingMarker top={topOfSwing} />
        <FollowThroughMarker follow={followThrough} />
        <AnimatedClub
          key={swingKey}
          pathPoints={pathPoints}
          handPoints={swing?.hand_points}
          playing={playing}
          club={club}
        />

        <OrbitControls
          makeDefault
          target={[0, 0.55, 0.1]}
          enablePan={false}
          enableDamping
          dampingFactor={0.08}
          minDistance={1.5}
          maxDistance={7}
          minPolarAngle={0.25}
          maxPolarAngle={Math.PI / 2.05}
        />
      </Canvas>

      <div
        style={{
          position: 'absolute',
          left: 14,
          bottom: 12,
          display: 'flex',
          gap: 10,
          alignItems: 'center',
          padding: '6px 9px',
          borderRadius: 8,
          background: 'rgba(15, 23, 42, 0.78)',
          color: '#94a3b8',
          fontSize: 11,
        }}
      >
        <button
          type="button"
          onClick={() => setPlaying((value) => !value)}
          style={{
            border: '1px solid #334155',
            background: '#1e293b',
            color: '#e2e8f0',
            borderRadius: 6,
            padding: '3px 8px',
            cursor: 'pointer',
            fontSize: 11,
          }}
        >
          {playing ? 'Pause' : 'Play'}
        </button>
        <span>{style.label} replay</span>
        <span style={{ color: '#38bdf8' }}>● Top</span>
        <span style={{ color: '#fbbf24' }}>● Finish</span>
      </div>
      <div
        style={{
          position: 'absolute',
          right: 14,
          top: 12,
          display: 'flex',
          gap: 12,
          padding: '6px 9px',
          borderRadius: 8,
          background: 'rgba(15, 23, 42, 0.78)',
          color: '#fbbf24',
          fontSize: 11,
          pointerEvents: 'none',
        }}
      >
        <span>{swing?.label ?? 'Swing'}</span>
        {topOfSwing ? (
          <span style={{ color: '#7dd3fc' }}>
            Top {topOfSwing.height_m.toFixed(2)} m
          </span>
        ) : null}
        {followThrough ? (
          <span style={{ color: '#fcd34d' }}>
            Finish {followThrough.height_m.toFixed(2)} m
          </span>
        ) : null}
      </div>
    </div>
  )
}
