/**
 * Idealized launch and contact values used by the simulator and grader.
 *
 * This module intentionally contains plain JavaScript data only. It can be
 * copied into an Expo project without bringing along any browser or Three.js
 * dependencies.
 */

const createReference = ({
  name,
  attackAngleDeg,
  clubSpeedKmh,
  attackTolerance,
  pathTolerance,
  speedTolerance,
}) => Object.freeze({
  name,
  attackAngleDeg,
  swingPathDeg: 0,
  clubSpeedKmh,
  impactZone: 2,
  heelPct: 28,
  centerPct: 44,
  toePct: 28,
  tolerances: Object.freeze({
    attackAngle: attackTolerance,
    swingPath: pathTolerance,
    clubSpeed: speedTolerance,
    zonePct: 15,
  }),
})

export const REFERENCE_SWINGS = Object.freeze({
  iron7: createReference({
    name: '7 Iron',
    attackAngleDeg: -3.5,
    clubSpeedKmh: 130,
    attackTolerance: 2,
    pathTolerance: 2.5,
    speedTolerance: 20,
  }),
  driver: createReference({
    name: 'Driver',
    attackAngleDeg: 3,
    clubSpeedKmh: 160,
    attackTolerance: 3,
    pathTolerance: 3,
    speedTolerance: 25,
  }),
  wedge: createReference({
    name: 'Wedge',
    attackAngleDeg: -5,
    clubSpeedKmh: 100,
    attackTolerance: 2.5,
    pathTolerance: 3,
    speedTolerance: 15,
  }),
})

export const REFERENCE_CLUB_KEYS = Object.freeze(Object.keys(REFERENCE_SWINGS))

export function getReferenceSwing(clubKey) {
  return REFERENCE_SWINGS[clubKey] ?? null
}

export function isSupportedClub(clubKey) {
  return Object.prototype.hasOwnProperty.call(REFERENCE_SWINGS, clubKey)
}

export default REFERENCE_SWINGS
