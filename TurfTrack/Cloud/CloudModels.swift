import Foundation

struct SessionRow: Codable {
    var id: String?
    var club: String
    var whenLabel: String?
    var distance: String?
    var score: Int?
    var swings: Int?
    var tone: String?
    var bestCarryYds: Int?
    var avgBallMph: Double?
    var bestBallMph: Double?
    var avgClubMph: Double?
    var avgSmash: Double?
    var radarHitPct: Int?
    var avgAttackDeg: Double?
    var avgPathDeg: Double?
    var avgHeelPct: Int?
    var avgCenterPct: Int?
    var avgToePct: Int?
    var centeredPct: Int?
    var swingSnapshots: [SessionSnapshot]?
    var createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, club, distance, score, swings, tone
        case whenLabel = "when_label"
        case bestCarryYds = "best_carry_yds"
        case avgBallMph = "avg_ball_mph"
        case bestBallMph = "best_ball_mph"
        case avgClubMph = "avg_club_mph"
        case avgSmash = "avg_smash"
        case radarHitPct = "radar_hit_pct"
        case avgAttackDeg = "avg_attack_deg"
        case avgPathDeg = "avg_path_deg"
        case avgHeelPct = "avg_heel_pct"
        case avgCenterPct = "avg_center_pct"
        case avgToePct = "avg_toe_pct"
        case centeredPct = "centered_pct"
        case swingSnapshots = "swing_snapshots"
        case createdAt = "created_at"
    }

    init(_ session: PracticeSession) {
        club = session.club
        whenLabel = session.when
        distance = session.distance
        score = session.score
        swings = session.swings
        tone = session.tone
        bestCarryYds = session.bestCarryYds
        avgBallMph = session.avgBallMph.map(Double.init)
        bestBallMph = session.bestBallMph.map(Double.init)
        avgClubMph = session.avgClubMph.map(Double.init)
        avgSmash = session.avgSmash
        radarHitPct = session.radarHitPct
        avgAttackDeg = session.avgAttackDeg
        avgPathDeg = session.avgPathDeg
        avgHeelPct = session.avgHeelPct
        avgCenterPct = session.avgCenterPct
        avgToePct = session.avgToePct
        centeredPct = session.centeredPct
        swingSnapshots = session.swingSnapshots
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(String.self, forKey: .id)
        club = try c.decodeIfPresent(String.self, forKey: .club) ?? "7 Iron"
        whenLabel = try c.decodeIfPresent(String.self, forKey: .whenLabel)
        distance = try c.decodeIfPresent(String.self, forKey: .distance)
        score = try c.decodeIfPresent(Int.self, forKey: .score)
        swings = try c.decodeIfPresent(Int.self, forKey: .swings)
        tone = try c.decodeIfPresent(String.self, forKey: .tone)
        bestCarryYds = try c.decodeIfPresent(Int.self, forKey: .bestCarryYds)
        avgBallMph = try c.decodeIfPresent(Double.self, forKey: .avgBallMph)
        bestBallMph = try c.decodeIfPresent(Double.self, forKey: .bestBallMph)
        avgClubMph = try c.decodeIfPresent(Double.self, forKey: .avgClubMph)
        avgSmash = try c.decodeIfPresent(Double.self, forKey: .avgSmash)
        radarHitPct = try c.decodeIfPresent(Int.self, forKey: .radarHitPct)
        avgAttackDeg = try c.decodeIfPresent(Double.self, forKey: .avgAttackDeg)
        avgPathDeg = try c.decodeIfPresent(Double.self, forKey: .avgPathDeg)
        avgHeelPct = try c.decodeIfPresent(Int.self, forKey: .avgHeelPct)
        avgCenterPct = try c.decodeIfPresent(Int.self, forKey: .avgCenterPct)
        avgToePct = try c.decodeIfPresent(Int.self, forKey: .avgToePct)
        centeredPct = try c.decodeIfPresent(Int.self, forKey: .centeredPct)
        swingSnapshots = (try? c.decodeIfPresent([SessionSnapshot].self, forKey: .swingSnapshots)) ?? []
        createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt)
    }

    var practiceSession: PracticeSession {
        let average = score ?? 0
        return PracticeSession(
            id: id.flatMap(UUID.init(uuidString:)) ?? UUID(),
            club: club,
            when: displayWhen,
            swings: swings ?? 0,
            score: average,
            distance: distance ?? "\(bestCarryYds ?? 0) yds",
            tone: tone ?? (average >= 85 ? "great" : average >= 65 ? "good" : "warm"),
            bestCarryYds: bestCarryYds ?? 0,
            avgBallMph: avgBallMph.map { Int($0.rounded()) },
            bestBallMph: bestBallMph.map { Int($0.rounded()) },
            avgClubMph: avgClubMph.map { Int($0.rounded()) },
            avgSmash: avgSmash,
            radarHitPct: radarHitPct ?? 0,
            avgAttackDeg: avgAttackDeg,
            avgPathDeg: avgPathDeg,
            avgHeelPct: avgHeelPct,
            avgCenterPct: avgCenterPct,
            avgToePct: avgToePct,
            centeredPct: centeredPct ?? 0,
            swingSnapshots: swingSnapshots ?? []
        )
    }

    private var displayWhen: String {
        guard let createdAt, let date = CloudDates.parse(createdAt) else { return whenLabel ?? "Earlier" }
        return CloudDates.label(for: date)
    }
}

struct ProfileRow: Codable {
    var id: String?
    var displayName: String?
    var handle: String?
    var initials: String?
    var handicap: Double?
    var preferredClubs: [String]?
    var bio: String?
    var location: String?
    var streakDays: Int?
    var updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, handle, initials, handicap, bio, location
        case displayName = "display_name"
        case preferredClubs = "preferred_clubs"
        case streakDays = "streak_days"
        case updatedAt = "updated_at"
    }
}

struct MemberRow: Codable {
    var name: String?
    var handle: String?
    var initials: String?
    var handicap: Double?
    var streak: Int?
}

struct ClubMember: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    var handle: String?
    var initials: String?
    var handicap: Double?
    var rank: Int?
    var score: Int?
    var swings: Int?
    var streak: Int?
    var isYou: Bool?

    enum CodingKeys: String, CodingKey {
        case id, name, handle, initials, handicap, rank, score, swings, streak
        case isYou = "is_you"
    }
}

struct ClubChallenge: Codable, Identifiable, Equatable {
    var id: String
    var title: String
    var detail: String?
    var progress: Int?
    var target: Int?
    var endsAt: String?
    var joined: Bool?
    var reward: String?

    enum CodingKeys: String, CodingKey {
        case id, title, detail, progress, target, joined, reward
        case endsAt = "ends_at"
    }

    var isComplete: Bool { (progress ?? 0) >= max(1, target ?? 1) }
}

struct ChallengePatch: Encodable {
    var joined: Bool
    var progress: Int?
}

struct FeedPost: Codable, Identifiable, Equatable {
    var id: String
    var author: String
    var text: String
    var whenLabel: String?
    var likes: Int?
    var createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, author, text, likes
        case whenLabel = "when_label"
        case createdAt = "created_at"
    }

    var displayWhen: String {
        guard let createdAt, let date = CloudDates.parse(createdAt) else { return whenLabel ?? "" }
        return CloudDates.label(for: date)
    }
}

struct NewFeedPost: Encodable {
    var author: String
    var text: String
    var when_label = "Just now"
    var likes = 0
}

struct LikesPatch: Encodable {
    var likes: Int
}

struct Announcement: Codable, Identifiable, Equatable {
    var id: String
    var title: String
    var body: String
}

struct CloudProfileStats: Equatable {
    var totalSessions = 0
    var totalSwings = 0
    var bestScore: Int?
    var avgScore: Int?
    var bestCarryYds: Int?
    var avgBallMph: Int?

    init(sessions: [PracticeSession] = []) {
        totalSessions = sessions.count
        totalSwings = sessions.reduce(0) { $0 + $1.swings }
        let scores = sessions.map(\.score).filter { $0 > 0 }
        bestScore = scores.max()
        avgScore = scores.isEmpty ? nil : Int((Double(scores.reduce(0, +)) / Double(scores.count)).rounded())
        bestCarryYds = sessions.map(\.bestCarryYds).filter { $0 > 0 }.max()
        let balls = sessions.compactMap(\.avgBallMph).filter { $0 > 0 }
        avgBallMph = balls.isEmpty ? nil : Int((Double(balls.reduce(0, +)) / Double(balls.count)).rounded())
    }
}

enum CloudDates {
    private static let plain = ISO8601DateFormatter()
    private static let relative: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f
    }()
    private static let dayTime: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, h:mm a"
        return f
    }()

    /// Postgres emits microseconds (`.123456+00:00`), which ISO8601DateFormatter rejects.
    static func parse(_ value: String) -> Date? {
        let trimmed = value.replacingOccurrences(of: #"\.\d+"#, with: "", options: .regularExpression)
        return plain.date(from: trimmed)
    }

    static func label(for date: Date) -> String {
        let age = Date().timeIntervalSince(date)
        if age < 60 { return "Just now" }
        if age < 86_400 { return relative.localizedString(for: date, relativeTo: Date()) }
        return dayTime.string(from: date)
    }
}
