import Foundation

public enum ClubType: String, Codable, CaseIterable, Identifiable {
    case driver
    case wood3
    case hybrid
    case iron4
    case iron5
    case iron6
    case iron7
    case iron8
    case iron9
    case pitchingWedge
    case sandWedge
    case putter

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .driver: return "Driver"
        case .wood3: return "3 Wood"
        case .hybrid: return "Hybrid"
        case .iron4: return "4 Iron"
        case .iron5: return "5 Iron"
        case .iron6: return "6 Iron"
        case .iron7: return "7 Iron"
        case .iron8: return "8 Iron"
        case .iron9: return "9 Iron"
        case .pitchingWedge: return "PW"
        case .sandWedge: return "SW"
        case .putter: return "Putter"
        }
    }

    /// Reference swing used for grading this club. Falls back to iron/driver
    /// defaults from the spec; other clubs interpolate a reasonable midpoint.
    public var referenceSwing: ReferenceSwing {
        switch self {
        case .driver:
            return .driverDefault
        case .wood3, .hybrid:
            var ref = ReferenceSwing.driverDefault
            ref.attackAngleDeg = 0.0
            ref.clubSpeedKmh = 145.0
            return ref
        case .iron4, .iron5, .iron6:
            var ref = ReferenceSwing.ironDefault
            ref.clubSpeedKmh = 140.0
            return ref
        case .iron7, .iron8, .iron9:
            return .ironDefault
        case .pitchingWedge, .sandWedge:
            var ref = ReferenceSwing.ironDefault
            ref.attackAngleDeg = -5.0
            ref.clubSpeedKmh = 105.0
            return ref
        case .putter:
            var ref = ReferenceSwing.ironDefault
            ref.attackAngleDeg = 0.0
            ref.clubSpeedKmh = 8.0
            ref.speedTolerance = 4.0
            return ref
        }
    }
}
