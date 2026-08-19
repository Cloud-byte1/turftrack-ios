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
}
