import Foundation

struct FairLieUser: Equatable, Codable {
    var name: String
    var username: String
    var bio: String
    var city: String
    var strikeScore: Int
    var streakWeeks: Int
    var strikeXp: Int
    var level: String
    var handicap: Double
    var sessions: Int
    var bestClubScore: Int
    var bag: [String]

    var initials: String {
        let parts = name.split(separator: " ").prefix(2)
        return parts.map { String($0.prefix(1)).uppercased() }.joined()
    }

    /// 10 XP per saved swing, a new level every 500 XP.
    var levelNumber: Int { 1 + strikeXp / 500 }
    var xpIntoLevel: Int { strikeXp % 500 }

    static let guest = FairLieUser.starter(name: "Guest")

    static func starter(name: String) -> FairLieUser {
        FairLieUser(
            name: name,
            username: "@\(slug(name))",
            bio: "",
            city: "",
            strikeScore: 0,
            streakWeeks: 0,
            strikeXp: 0,
            level: "Beginner",
            handicap: 0,
            sessions: 0,
            bestClubScore: 0,
            bag: ["Driver", "7 Iron", "Pitching Wedge"]
        )
    }

    private static func slug(_ name: String) -> String {
        let trimmed = name.lowercased().filter { $0.isLetter || $0.isNumber || $0 == " " }
        return trimmed.split(separator: " ").joined(separator: "_").prefix(18).description
    }
}

struct TrophyBadge: Identifiable {
    let id: String
    let title: String
    let earned: Bool
}

enum FairLieCatalog {
    static let clubs = ["Driver", "5 Wood", "7 Iron", "Pitching Wedge", "Sand Wedge"]

    /// Trophies earned from the golfer's own saved sessions.
    static func badges(for sessions: [PracticeSession]) -> [TrophyBadge] {
        let insights = PracticeInsights(sessions: sessions)
        return [
            .init(id: "first-session", title: "First Session", earned: !sessions.isEmpty),
            .init(id: "fifty-swings", title: "50 Swings Logged", earned: insights.totalSwings >= 50),
            .init(id: "centered-ten", title: "10 Centered Strikes", earned: insights.centeredStrikes >= 10),
            .init(id: "avg-80", title: "80+ Session Average", earned: sessions.contains { $0.score >= 80 }),
            .init(id: "radar", title: "Radar-Measured Session", earned: sessions.contains { $0.radarHitPct > 0 }),
            .init(id: "ten-sessions", title: "10 Sessions", earned: sessions.count >= 10),
        ]
    }
}
