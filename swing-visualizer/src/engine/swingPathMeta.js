/**
 * Highest point on the backswing (max Y before impact near the origin).
 */
export function findTopOfSwing(pathPoints) {
  if (!Array.isArray(pathPoints) || pathPoints.length === 0) return null

  let impactIndex = 0
  let minDist = Infinity
  pathPoints.forEach((point, index) => {
    if (!Array.isArray(point) || point.length < 3) return
    const distance = Math.hypot(Number(point[0]), Number(point[1]), Number(point[2]))
    if (distance < minDist) {
      minDist = distance
      impactIndex = index
    }
  })

  const backswingEnd = Math.max(1, impactIndex)
  let topIndex = 0
  let maxY = -Infinity
  for (let index = 0; index <= backswingEnd; index += 1) {
    const y = Number(pathPoints[index]?.[1])
    if (Number.isFinite(y) && y >= maxY) {
      maxY = y
      topIndex = index
    }
  }

  if (!Number.isFinite(maxY)) return null

  return {
    index: topIndex,
    impactIndex,
    point: pathPoints[topIndex].map(Number),
    height_m: Number(maxY.toFixed(3)),
    progress: topIndex / Math.max(1, pathPoints.length - 1),
  }
}
