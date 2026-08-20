import Foundation

struct SessionSnapshot: Identifiable, Equatable {
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

struct PracticeSession: Identifiable, Equatable {
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

    static let samples: [PracticeSession] = [
        buildSessionSummary(
            [
                SwingSimulator.preset(.perfect),
                SwingSimulator.preset(.heel),
                SwingSimulator.preset(.toe),
            ],
            club: "7 Iron",
            when: "Today, 2:42 PM"
        ),
        buildSessionSummary(
            [SwingSimulator.preset(.perfect), SwingSimulator.preset(.thin)],
            club: "Driver",
            when: "Sunday, 10:18 AM"
        ),
        buildSessionSummary(
            [SwingSimulator.preset(.thin), SwingSimulator.preset(.heel)],
            club: "PW",
            when: "Friday, 4:06 PM"
        ),
    ]
}

func buildSessionSummary(_ swings: [SwingResult], club: String, when: String = "Just now") -> PracticeSession {
    let scores = swings.map(\.impactQuality)
    let carries = swings.map(\.carryYards)
    let balls = swings.map(\.ballSpeedMph).filter { $0 > 0 }
    let clubs = swings.map(\.clubSpeedMph).filter { $0 > 0 }
    let smashes = swings.compactMap(\.smash)
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
            smash: item.smash,
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
        avgSmash: smashes.isEmpty ? nil : ((smashes.reduce(0, +) / Double(smashes.count) * 100).rounded() / 100),
        radarHitPct: swings.isEmpty ? 0 : Int((Double(radarHits) / Double(swings.count) * 100).rounded()),
        avgAttackDeg: attacks.isEmpty ? nil : ((attacks.reduce(0, +) / Double(attacks.count) * 10).rounded() / 10),
        avgPathDeg: paths.isEmpty ? nil : ((paths.reduce(0, +) / Double(paths.count) * 10).rounded() / 10),
        avgHeelPct: heels.isEmpty ? nil : Int((Double(heels.reduce(0, +)) / Double(heels.count)).rounded()),
        avgCenterPct: centers.isEmpty ? nil : Int((Double(centers.reduce(0, +)) / Double(centers.count)).rounded()),
        avgToePct: toes.isEmpty ? nil : Int((Double(toes.reduce(0, +)) / Double(toes.count)).rounded()),
        centeredPct: swings.isEmpty ? 0 : Int((Double(centered) / Double(swings.count) * 100).rounded()),
        swingSnapshots: snaps
    )
}
