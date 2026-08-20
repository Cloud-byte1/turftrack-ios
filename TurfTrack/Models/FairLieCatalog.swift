import Foundation

struct FairLieUser: Equatable {
    var name: String
    var username: String
    var bio: String
    var city: String
    var strikeScore: Int
    var strikeTrend: Int
    var streakWeeks: Int
    var strikeXp: Int
    var level: String
    var levelNumber: Int
    var handicap: Double
    var sessions: Int
    var videos: Int
    var cleanContactPct: Int
    var centerStrikePct: Int
    var consistencyScore: Int
    var fixThisNext: String
    var bestClub: String
    var bestClubScore: Int
    var bag: [String]
    var puttDistanceFt: Int
    var puttsMade: Int
    var puttAttempts: Int
    var lineAccuracy: Int

    var initials: String {
        let parts = name.split(separator: " ").prefix(2)
        return parts.map { String($0.prefix(1)).uppercased() }.joined()
    }

    static let sample = FairLieUser(
        name: "Carmi",
        username: "@carmi_golf",
        bio: "Dialing in center contact one range session at a time.",
        city: "Miami, FL",
        strikeScore: 76,
        strikeTrend: 7,
        streakWeeks: 2,
        strikeXp: 1240,
        level: "Range Regular",
        levelNumber: 2,
        handicap: 12.4,
        sessions: 48,
        videos: 124,
        cleanContactPct: 68,
        centerStrikePct: 54,
        consistencyScore: 71,
        fixThisNext: "Heel contact on irons",
        bestClub: "7 Iron",
        bestClubScore: 84,
        bag: ["Driver", "5 Wood", "7 Iron", "Pitching Wedge", "Sand Wedge"],
        puttDistanceFt: 12,
        puttsMade: 8,
        puttAttempts: 12,
        lineAccuracy: 82
    )

    static func starter(name: String) -> FairLieUser {
        FairLieUser(
            name: name,
            username: "@\(slug(name))_golf",
            bio: "New to fairLie — building my strike.",
            city: "",
            strikeScore: 0,
            strikeTrend: 0,
            streakWeeks: 0,
            strikeXp: 0,
            level: "Beginner",
            levelNumber: 1,
            handicap: 0,
            sessions: 0,
            videos: 0,
            cleanContactPct: 0,
            centerStrikePct: 0,
            consistencyScore: 0,
            fixThisNext: "Start your first session",
            bestClub: "7 Iron",
            bestClubScore: 0,
            bag: ["Driver", "7 Iron", "Pitching Wedge"],
            puttDistanceFt: 10,
            puttsMade: 0,
            puttAttempts: 0,
            lineAccuracy: 0
        )
    }

    private static func slug(_ name: String) -> String {
        let trimmed = name.lowercased().filter { $0.isLetter || $0.isNumber || $0 == " " }
        return trimmed.split(separator: " ").joined(separator: "_").prefix(18).description
    }
}

struct FairLieChallenge: Identifiable {
    let id: String
    let title: String
    let type: String
    let progress: Int
    let total: Int
    let stake: String?
    let participants: Int
    let status: String
}

struct LeaderboardEntry: Identifiable {
    let id: String
    let name: String
    let score: Int
    let verified: Bool
    let skillBracket: String
    var isSelf: Bool
}

struct SocialGolfer: Identifiable {
    let id: String
    let name: String
    let username: String
    let bio: String
    let city: String
    let level: String
    let handicap: Double
    let strikeScore: Int
    let sessions: Int
    let followers: Int
    let following: Int
}

struct TrophyBadge: Identifiable {
    let id: String
    let title: String
    let earned: Bool
}

enum FairLieCatalog {
    static let clubs = ["Driver", "5 Wood", "7 Iron", "Pitching Wedge", "Sand Wedge"]
    static let challengeTypes = [
        "Center Strike", "Consistency", "Club Battle", "Friend Duel", "Ghost Mode",
        "Fairway Finder", "Wedge Ladder", "9-Shot Matrix", "Course Prep", "Clubhouse Tournament",
    ]

    static let challenges: [FairLieChallenge] = [
        .init(id: "center-streak", title: "Center Strike Streak", type: "Center Strike", progress: 6, total: 20, stake: nil, participants: 1, status: "active"),
        .init(id: "club-battle-7i", title: "7 Iron Club Battle", type: "Club Battle", progress: 0, total: 15, stake: "50 XP · Bragging rights", participants: 4, status: "active"),
        .init(id: "ghost-duel", title: "Ghost Mode — Beat your best", type: "Ghost Mode", progress: 12, total: 20, stake: nil, participants: 1, status: "active"),
        .init(id: "fairway-finder", title: "Fairway Finder", type: "Fairway Finder", progress: 5, total: 7, stake: nil, participants: 8, status: "upcoming"),
    ]

    static let badges: [TrophyBadge] = [
        .init(id: "first-center", title: "First Center Strike", earned: true),
        .init(id: "clean-ten", title: "10 Clean Contacts", earned: true),
        .init(id: "no-fat", title: "No Fat Session", earned: false),
        .init(id: "7i-mastery", title: "7-Iron Mastery", earned: false),
        .init(id: "ghost-slayer", title: "Ghost Slayer", earned: false),
    ]

    static let friends: [SocialGolfer] = [
        .init(id: "jordan", name: "Jordan", username: "@jordan_irons", bio: "Scratch chaser. 7-iron enthusiast.", city: "Orlando, FL", level: "Shot Shaper", handicap: 4.2, strikeScore: 91, sessions: 112, followers: 412, following: 3),
        .init(id: "priya", name: "Priya", username: "@priya_wedges", bio: "Wedge matrix every Thursday.", city: "Tampa, FL", level: "Ball Striker", handicap: 9.1, strikeScore: 74, sessions: 67, followers: 203, following: 2),
        .init(id: "sam", name: "Sam", username: "@sam_drives", bio: "Fairway finder mode.", city: "Fort Lauderdale, FL", level: "Range Regular", handicap: 15.3, strikeScore: 68, sessions: 34, followers: 89, following: 3),
        .init(id: "devon", name: "Devon", username: "@devon_range", bio: "New to the mat. Learning fast.", city: "Miami, FL", level: "Beginner", handicap: 22, strikeScore: 61, sessions: 18, followers: 34, following: 2),
    ]

    static func leaderboard(scope: String, selfName: String) -> [LeaderboardEntry] {
        let friends: [LeaderboardEntry] = [
            .init(id: "f1", name: "Jordan", score: 91, verified: true, skillBracket: "Advanced", isSelf: false),
            .init(id: "f2", name: selfName, score: 76, verified: true, skillBracket: "Intermediate", isSelf: true),
            .init(id: "f3", name: "Priya", score: 74, verified: true, skillBracket: "Intermediate", isSelf: false),
            .init(id: "f4", name: "Sam", score: 68, verified: false, skillBracket: "Intermediate", isSelf: false),
            .init(id: "f5", name: "Devon", score: 61, verified: true, skillBracket: "Beginner", isSelf: false),
        ]
        let club: [LeaderboardEntry] = [
            .init(id: "c1", name: "Weekend Foursome · Alex", score: 95, verified: true, skillBracket: "Advanced", isSelf: false),
            .init(id: "c2", name: "Weekend Foursome · Riley", score: 88, verified: true, skillBracket: "Advanced", isSelf: false),
            .init(id: "c3", name: selfName, score: 76, verified: true, skillBracket: "Intermediate", isSelf: true),
            .init(id: "c4", name: "Range Regulars · Kai", score: 72, verified: false, skillBracket: "Intermediate", isSelf: false),
            .init(id: "c5", name: "Range Regulars · Noor", score: 59, verified: true, skillBracket: "Beginner", isSelf: false),
        ]
        return scope == "clubhouse" ? club : friends
    }
}
