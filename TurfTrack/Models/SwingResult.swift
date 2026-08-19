import Foundation

struct SwingResult: Identifiable, Equatable {
    let id: UUID
    let timestampMs: UInt32
    let receivedAt: Date
    let fsrPeaks: [Int]
    let impactZone: Int
    let impactQuality: Int
    let estimatedDistanceM: Int
    let directionLabel: String
    let heelPressurePct: Int
    let centerPressurePct: Int
    let toePressurePct: Int
    let isZeroed: Bool

    var letterGrade: LetterGrade {
        LetterGrade.from(score: impactQuality)
    }

    static let zeroed = SwingResult(
        id: UUID(),
        timestampMs: 0,
        receivedAt: .distantPast,
        fsrPeaks: [0, 0, 0, 0, 0, 0],
        impactZone: -1,
        impactQuality: 0,
        estimatedDistanceM: 0,
        directionLabel: "Armed",
        heelPressurePct: 0,
        centerPressurePct: 0,
        toePressurePct: 0,
        isZeroed: true
    )

    static func from(packet: SwingPacket) -> SwingResult {
        let direction = StrikeDirection(rawValue: packet.strikeDirection)?.label ?? "Straight"
        return SwingResult(
            id: UUID(),
            timestampMs: packet.timestampMs,
            receivedAt: Date(),
            fsrPeaks: packet.fsrPeaks.map(Int.init),
            impactZone: Int(packet.impactZone),
            impactQuality: Int(packet.impactQuality),
            estimatedDistanceM: Int(packet.estimatedDistanceM),
            directionLabel: direction,
            heelPressurePct: Int(packet.heelPressurePct),
            centerPressurePct: Int(packet.centerPressurePct),
            toePressurePct: Int(packet.toePressurePct),
            isZeroed: false
        )
    }
}

enum LetterGrade: String, CaseIterable {
    case a = "A"
    case b = "B"
    case c = "C"
    case d = "D"
    case f = "F"

    static func from(score: Int) -> LetterGrade {
        switch score {
        case 90...: return .a
        case 80..<90: return .b
        case 70..<80: return .c
        case 55..<70: return .d
        default: return .f
        }
    }

    var colorHex: UInt32 {
        switch self {
        case .a: return 0x22C55E
        case .b: return 0x84CC16
        case .c: return 0xEAB308
        case .d: return 0xF97316
        case .f: return 0xEF4444
        }
    }
}
