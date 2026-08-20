import Foundation

struct SIMD3Point: Equatable {
    var x: Double
    var y: Double
    var z: Double

    var array: [Double] { [x, y, z] }
}

struct SwingResult: Identifiable, Equatable {
    let id: UUID
    var label: String
    var source: String
    var isZeroed: Bool
    var preview: Bool
    var timestampMs: UInt32
    var receivedAt: Date
    var fsrPeaks: [Int]
    var impactZone: Int
    var impactQuality: Int
    var estimatedDistanceM: Int
    var directionLabel: String
    var heelPressurePct: Int
    var centerPressurePct: Int
    var toePressurePct: Int
    var clubSpeedMph: Double
    var ballSpeedMph: Double
    var attackAngleDeg: Double
    var swingPathDeg: Double
    var radarValid: Bool
    var radarDistanceMm: Int?
    var radarIntraScore: Int?
    var pathPoints: [SIMD3Point]

    var clubSpeedKmh: Int { Int((clubSpeedMph * 1.60934).rounded()) }
    var carryYards: Int { Int((Double(estimatedDistanceM) * 1.09361).rounded()) }
    var smash: Double? {
        guard clubSpeedMph > 0, ballSpeedMph > 0 else { return nil }
        return (ballSpeedMph / clubSpeedMph * 100).rounded() / 100
    }

    var letterGrade: LetterGrade { LetterGrade.from(score: impactQuality) }

    var impactName: String {
        if isZeroed { return "Waiting for strike" }
        if impactZone <= 1 { return "Heel-side contact" }
        if impactZone >= 4 { return "Toe-side contact" }
        return "Centered contact"
    }

    static let zeroed = SwingResult(
        id: UUID(),
        label: "Zeroed",
        source: "idle",
        isZeroed: true,
        preview: false,
        timestampMs: 0,
        receivedAt: .distantPast,
        fsrPeaks: [0, 0, 0, 0, 0, 0],
        impactZone: -1,
        impactQuality: 0,
        estimatedDistanceM: 0,
        directionLabel: "Waiting",
        heelPressurePct: 0,
        centerPressurePct: 0,
        toePressurePct: 0,
        clubSpeedMph: 0,
        ballSpeedMph: 0,
        attackAngleDeg: 0,
        swingPathDeg: 0,
        radarValid: false,
        radarDistanceMm: nil,
        radarIntraScore: nil,
        pathPoints: SwingArc.build(quality: 40, pathDeg: 0, attackDeg: -3)
    )

    static func from(packet: SwingPacket) -> SwingResult {
        let quality = Int(packet.impactQuality)
        let yawDeg = Double(packet.yawDeg10) / 10
        let pathDeg = directionPathDegrees(packet.strikeDirection, yawDeg)
        let attack = estimateAttack(accelZ: Double(packet.accelZMg), quality: quality)
        let radarMph = packet.radarValid == 1 ? Double(packet.radarSpeedMph10) / 10 : nil
        let ball = radarMph ?? estimateBall(distanceM: Int(packet.estimatedDistanceM), quality: quality)
        let club = estimateClub(distanceM: Int(packet.estimatedDistanceM), quality: quality, ballMph: radarMph)
        let direction = StrikeDirection(rawValue: packet.strikeDirection)?.label ?? "Straight"
        let zone = min(5, max(0, Int(packet.impactZone)))

        return SwingResult(
            id: UUID(),
            label: "Live Strike",
            source: "ble",
            isZeroed: false,
            preview: false,
            timestampMs: packet.timestampMs,
            receivedAt: Date(),
            fsrPeaks: packet.fsrPeaks.map(Int.init),
            impactZone: zone,
            impactQuality: quality,
            estimatedDistanceM: Int(packet.estimatedDistanceM),
            directionLabel: direction,
            heelPressurePct: Int(packet.heelPressurePct),
            centerPressurePct: Int(packet.centerPressurePct),
            toePressurePct: Int(packet.toePressurePct),
            clubSpeedMph: club,
            ballSpeedMph: ball,
            attackAngleDeg: attack,
            swingPathDeg: pathDeg,
            radarValid: packet.radarValid == 1,
            radarDistanceMm: packet.radarValid == 1 ? Int(packet.radarDistanceMm) : nil,
            radarIntraScore: packet.radarValid == 1 ? Int(packet.radarIntraScore) : nil,
            pathPoints: SwingArc.build(quality: quality, pathDeg: pathDeg, attackDeg: attack)
        )
    }
}

enum LetterGrade: String {
    case a = "A", b = "B", c = "C", d = "D", f = "F"

    static func from(score: Int) -> LetterGrade {
        switch score {
        case 93...: return .a
        case 85..<93: return .b
        case 72..<85: return .c
        case 60..<72: return .d
        default: return .f
        }
    }

    var color: UInt32 {
        switch self {
        case .a: return 0x22C55E
        case .b: return 0x84CC16
        case .c: return 0xEAB308
        case .d: return 0xF97316
        case .f: return 0xEF4444
        }
    }
}

private func clamp(_ value: Double, _ minV: Double, _ maxV: Double) -> Double {
    min(maxV, max(minV, value))
}

private func directionPathDegrees(_ direction: UInt8, _ yawDeg: Double) -> Double {
    if abs(yawDeg) > 0.15 { return clamp(yawDeg, -12, 12) }
    switch direction {
    case 1, 4: return -4.5
    case 2, 3: return 4.5
    default: return 0.2
    }
}

private func estimateAttack(accelZ: Double, quality: Int) -> Double {
    if abs(accelZ) > 50 {
        return clamp(-accelZ / 400, -8, 4)
    }
    return clamp(-4.5 + (Double(quality) / 100) * 2.5, -7, 3)
}

private func estimateClub(distanceM: Int, quality: Int, ballMph: Double?) -> Double {
    if let ballMph, ballMph > 1 {
        return clamp(ballMph / 1.35, 40, 130)
    }
    if distanceM > 0 {
        return clamp(55 + Double(distanceM) * 0.34, 40, 130)
    }
    return 48 + Double(quality) * 0.45
}

private func estimateBall(distanceM: Int, quality: Int) -> Double {
    let club = estimateClub(distanceM: distanceM, quality: quality, ballMph: nil)
    return club * 1.32
}
