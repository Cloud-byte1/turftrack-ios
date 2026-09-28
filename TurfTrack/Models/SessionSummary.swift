import Foundation

struct SessionSnapshot: Identifiable, Equatable, Codable {
    var n: Int
    var score: Int
    var carryYds: Int
    var ballMph: Int
    var clubMph: Int
    var smash: Double?
    var attack: String?
    var path: String?
    var radar: Bool
    var id: Int { n }
}

struct PracticeSession: Identifiable, Equatable, Codable {
    let id: UUID
    var club: String
    var when: String
    var swings: Int
    var score: Int
    var distance: String
    var tone: String
    var bestCarryYds: Int
    var avgBallMph: Int?
    var bestBallMph: Int?
    var avgClubMph: Int?
    var avgSmash: Double?
    var radarHitPct: Int
    var avgAttackDeg: Double?
    var avgPathDeg: Double?
    var avgHeelPct: Int?
    var avgCenterPct: Int?
    var avgToePct: Int?
    var centeredPct: Int
    var swingSnapshots: [SessionSnapshot]
    /// Contains simulator, example, or test swings. Kept on the phone, never uploaded or ranked.
    var isSimulated: Bool = false
}

/// Coaching reads derived only from the golfer's saved sessions.
struct PracticeInsights {
    var totalSwings = 0
    var centeredStrikes = 0
    var centeredPct: Int?
    var consistency: Int?
    var bestClub: (club: String, score: Int)?
    var fixThisNext: String?

    init(sessions: [PracticeSession]) {
        let withSwings = sessions.filter { $0.swings > 0 }
        guard !withSwings.isEmpty else { return }
        totalSwings = withSwings.reduce(0) { $0 + $1.swings }
        centeredStrikes = withSwings.reduce(0) { $0 + Int((Double($1.centeredPct * $1.swings) / 100).rounded()) }
        centeredPct = totalSwings > 0 ? Int((Double(centeredStrikes) / Double(totalSwings) * 100).rounded()) : nil

        let scores = withSwings.flatMap { $0.swingSnapshots.map(\.score) }
        if scores.count >= 3 {
            let mean = Double(scores.reduce(0, +)) / Double(scores.count)
            let variance = scores.reduce(0.0) { $0 + pow(Double($1) - mean, 2) } / Double(scores.count)
            consistency = max(0, min(100, Int((100 - variance.squareRoot() * 2).rounded())))
        }

        let byClub = Dictionary(grouping: withSwings, by: \.club)
        bestClub = byClub
            .map { club, list in (club, list.map(\.score).reduce(0, +) / list.count) }
            .max { $0.1 < $1.1 }
            .map { (club: $0.0, score: $0.1) }

        let heel = average(withSwings.compactMap(\.avgHeelPct))
        let toe = average(withSwings.compactMap(\.avgToePct))
        let attack = average(withSwings.compactMap(\.avgAttackDeg))
        if let centeredPct, centeredPct < 50, let heel, let toe {
            fixThisNext = heel >= toe ? "Heel-side contact" : "Toe-side contact"
        } else if let attack, attack < -6 {
            fixThisNext = "Steep attack angle"
        } else {
            fixThisNext = "Consistency from swing to swing"
        }
    }

    private func average<T: BinaryInteger>(_ values: [T]) -> Double? {
        values.isEmpty ? nil : Double(values.reduce(0, +)) / Double(values.count)
    }

    private func average(_ values: [Double]) -> Double? {
        values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
    }
}

func buildSessionSummary(_ swings: [SwingResult], club: String, when: String = "Just now") -> PracticeSession {
    let scores = swings.map(\.impactQuality)
    let carries = swings.map(\.carryYards)
    let balls = swings.map(\.ballSpeedMph).filter { $0 > 0 }
    let clubs = swings.map(\.clubSpeedMph).filter { $0 > 0 }
    let attacks = swings.map(\.attackAngleDeg)
    let paths = swings.map(\.swingPathDeg)
    let heels = swings.map(\.heelPressurePct)
    let centers = swings.map(\.centerPressurePct)
    let toes = swings.map(\.toePressurePct)
    let radarHits = swings.filter(\.radarValid).count
    let centered = swings.filter { $0.impactZone >= 2 && $0.impactZone <= 3 }.count
    let average = scores.isEmpty ? 0 : Int((Double(scores.reduce(0, +)) / Double(scores.count)).rounded())
    let bestCarry = carries.max() ?? 0
    let snaps = Array(swings.suffix(8).enumerated()).map { offset, item in
        SessionSnapshot(
            n: swings.count - min(swings.count, 8) + offset + 1,
            score: item.impactQuality,
            carryYds: item.carryYards,
            ballMph: Int(item.ballSpeedMph.rounded()),
            clubMph: Int(item.clubSpeedMph.rounded()),
            smash: nil,
            attack: String(format: "%.1f", item.attackAngleDeg),
            path: String(format: "%.1f", item.swingPathDeg),
            radar: item.radarValid
        )
    }
    return PracticeSession(
        id: UUID(),
        club: club,
        when: when,
        swings: swings.count,
        score: average,
        distance: "\(bestCarry) yds",
        tone: average >= 85 ? "great" : average >= 65 ? "good" : "warm",
        bestCarryYds: bestCarry,
        avgBallMph: balls.isEmpty ? nil : Int((balls.reduce(0, +) / Double(balls.count)).rounded()),
        bestBallMph: balls.isEmpty ? nil : Int((balls.max() ?? 0).rounded()),
        avgClubMph: clubs.isEmpty ? nil : Int((clubs.reduce(0, +) / Double(clubs.count)).rounded()),
        avgSmash: nil,
        radarHitPct: swings.isEmpty ? 0 : Int((Double(radarHits) / Double(swings.count) * 100).rounded()),
        avgAttackDeg: attacks.isEmpty ? nil : ((attacks.reduce(0, +) / Double(attacks.count) * 10).rounded() / 10),
        avgPathDeg: paths.isEmpty ? nil : ((paths.reduce(0, +) / Double(paths.count) * 10).rounded() / 10),
        avgHeelPct: heels.isEmpty ? nil : Int((Double(heels.reduce(0, +)) / Double(heels.count)).rounded()),
        avgCenterPct: centers.isEmpty ? nil : Int((Double(centers.reduce(0, +)) / Double(centers.count)).rounded()),
        avgToePct: toes.isEmpty ? nil : Int((Double(toes.reduce(0, +)) / Double(toes.count)).rounded()),
        centeredPct: swings.isEmpty ? 0 : Int((Double(centered) / Double(swings.count) * 100).rounded()),
        swingSnapshots: snaps,
        isSimulated: swings.contains(where: \.isSimulated)
    )
}
