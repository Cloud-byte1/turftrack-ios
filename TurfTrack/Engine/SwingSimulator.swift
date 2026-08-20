import Foundation

enum SwingPreset: String, CaseIterable, Identifiable {
    case perfect, heel, toe, thin, random
    var id: String { rawValue }

    var title: String {
        switch self {
        case .perfect: return "Perfect"
        case .heel: return "Heel"
        case .toe: return "Toe"
        case .thin: return "Thin"
        case .random: return "Random"
        }
    }

    var note: String {
        switch self {
        case .perfect: return "Centered · straight"
        case .heel: return "Pressure left"
        case .toe: return "Pressure right"
        case .thin: return "Low, weak contact"
        case .random: return "Below-avg vary"
        }
    }

    var mark: String {
        switch self {
        case .perfect: return "●"
        case .heel: return "◐"
        case .toe: return "◑"
        case .thin: return "▬"
        case .random: return "✦"
        }
    }
}

enum SwingSimulator {
    static func preset(_ kind: SwingPreset) -> SwingResult {
        switch kind {
        case .perfect:
            return make(
                label: "Perfect Strike",
                peaks: [95, 105, 180, 175, 100, 90],
                quality: 96, zone: 2, heel: 28, center: 46, toe: 26,
                direction: "Straight", meters: 165, club: 82, ball: 112,
                path: 0.3, attack: -3.2
            )
        case .heel:
            return make(
                label: "Heel Strike",
                peaks: [175, 160, 110, 85, 70, 60],
                quality: 58, zone: 0, heel: 65, center: 25, toe: 10,
                direction: "Left", meters: 115, club: 73, ball: 88,
                path: -4.2, attack: -5.8
            )
        case .toe:
            return make(
                label: "Toe Strike",
                peaks: [60, 70, 85, 110, 160, 175],
                quality: 58, zone: 5, heel: 10, center: 25, toe: 65,
                direction: "Right", meters: 110, club: 71, ball: 86,
                path: 4.8, attack: -1.5
            )
        case .thin:
            return make(
                label: "Thin Hit",
                peaks: [80, 85, 90, 88, 82, 78],
                quality: 38, zone: 2, heel: 32, center: 36, toe: 32,
                direction: "Straight", meters: 80, club: 59, ball: 71,
                path: 1.1, attack: 2.5
            )
        case .random:
            return simulate(pickBelowAverage(), label: "Random Swing", commit: true)
        }
    }

    static func pickBelowAverage() -> SimParams {
        let roll = Double.random(in: 0...1)
        let quality: Int
        if roll < 0.55 { quality = Int.random(in: 24...52) }
        else if roll < 0.88 { quality = Int.random(in: 48...62) }
        else { quality = Int.random(in: 58...72) }
        let club = 56 + Double.random(in: 0...22) + Double(quality) * 0.18
        let smash = 1.08 + Double.random(in: 0...0.2) + Double(quality) / 1000
        let ball = min(145, max(55, club * smash))
        let miss = 4.5 + ((100 - Double(quality)) / 100) * 7
        let zone = Double.random(in: 0...1) < 0.28 ? (Bool.random() ? 2 : 3) : Int.random(in: 0...5)
        return SimParams(
            ballMph: ball,
            clubMph: club,
            attack: Double.random(in: -9...3),
            path: Double.random(in: -miss / 2...miss / 2),
            quality: quality,
            zone: zone
        )
    }

    static func simulate(_ params: SimParams, label: String = "Simulated Swing", commit: Bool) -> SwingResult {
        let quality = min(100, max(1, params.quality))
        let zone = min(5, max(0, params.zone))
        let region = zone / 2
        var weights = [24.0, 46.0, 24.0]
        let miss = 14 + ((100 - Double(quality)) / 60) * 30
        weights[region] += miss
        if region != 1 { weights[1] -= miss * 0.45 }
        let total = max(1, weights.reduce(0, +))
        let heel = Int((weights[0] / total * 100).rounded())
        let toe = Int((weights[2] / total * 100).rounded())
        let center = max(0, 100 - heel - toe)
        let peaks = (0..<6).map { index -> Int in
            let share = [heel, center, toe][index / 2]
            let boost = index == zone ? 1.18 : 1.0
            return max(6, Int(Double(share) * (1.15 + Double(quality) / 110) * boost) + (index == zone ? 18 : 0))
        }
        let centered = zone == 2 || zone == 3
        let carryYds = min(210, max(45, Int((
            params.ballMph * (0.92 + Double(quality) / 420)
            + params.attack * 1.4
            - abs(params.path) * 2.4
            + (centered ? 6 : -8)
            + Double.random(in: -5...5)
        ).rounded())))
        let direction: String
        if params.path < -3 { direction = "Left" }
        else if params.path > 3 { direction = "Right" }
        else if params.path < -1 { direction = "Slight Left" }
        else if params.path > 1 { direction = "Slight Right" }
        else { direction = "Straight" }

        return SwingResult(
            id: UUID(),
            label: label,
            source: commit ? "simulate" : "preview",
            isZeroed: false,
            preview: !commit,
            timestampMs: UInt32(Date().timeIntervalSince1970.truncatingRemainder(dividingBy: 4_000_000_000)),
            receivedAt: Date(),
            fsrPeaks: peaks,
            impactZone: zone,
            impactQuality: quality,
            estimatedDistanceM: Int((Double(carryYds) / 1.09361).rounded()),
            directionLabel: direction,
            heelPressurePct: heel,
            centerPressurePct: center,
            toePressurePct: toe,
            clubSpeedMph: params.clubMph,
            ballSpeedMph: params.ballMph,
            attackAngleDeg: params.attack,
            swingPathDeg: params.path,
            radarValid: true,
            radarDistanceMm: Int(520 + abs(params.attack) * 22 + params.ballMph * 1.6),
            radarIntraScore: Int(900 + (params.ballMph / 180) * 7000),
            pathPoints: SwingArc.build(quality: quality, pathDeg: params.path, attackDeg: params.attack)
        )
    }

    private static func make(
        label: String, peaks: [Int], quality: Int, zone: Int,
        heel: Int, center: Int, toe: Int, direction: String,
        meters: Int, club: Double, ball: Double, path: Double, attack: Double
    ) -> SwingResult {
        SwingResult(
            id: UUID(),
            label: label,
            source: "example",
            isZeroed: false,
            preview: false,
            timestampMs: 0,
            receivedAt: Date(),
            fsrPeaks: peaks,
            impactZone: zone,
            impactQuality: quality,
            estimatedDistanceM: meters,
            directionLabel: direction,
            heelPressurePct: heel,
            centerPressurePct: center,
            toePressurePct: toe,
            clubSpeedMph: club,
            ballSpeedMph: ball,
            attackAngleDeg: attack,
            swingPathDeg: path,
            radarValid: true,
            radarDistanceMm: 640,
            radarIntraScore: 2400,
            pathPoints: SwingArc.build(quality: quality, pathDeg: path, attackDeg: attack)
        )
    }
}

struct SimParams {
    var ballMph: Double
    var clubMph: Double
    var attack: Double
    var path: Double
    var quality: Int
    var zone: Int
}
