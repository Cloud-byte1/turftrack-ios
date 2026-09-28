import Combine
import Foundation

/// Supabase-backed sessions, profile, and Clubhouse. With no `Config/Supabase.plist`
/// the app keeps working on local sample data and `isConfigured` stays false.
@MainActor
final class CloudSync: ObservableObject {
    enum Status: Equatable {
        case offline
        case syncing
        case synced(Date)
        case failed(String)
    }

    @Published private(set) var status: Status = .offline
    @Published private(set) var sessions: [PracticeSession] = []
    @Published private(set) var members: [ClubMember] = []
    @Published private(set) var challenges: [ClubChallenge] = []
    @Published private(set) var feed: [FeedPost] = []
    @Published private(set) var announcements: [Announcement] = []
    @Published private(set) var stats = CloudProfileStats()

    private let client: SupabaseREST?

    init(config: SupabaseConfig? = SupabaseConfig.load()) {
        client = config.map { SupabaseREST(config: $0) }
    }

    var isConfigured: Bool { client != nil }

    var statusLabel: String {
        switch status {
        case .offline: return isConfigured ? "Not synced yet" : "Offline · sample data (add Config/Supabase.plist)"
        case .syncing: return "Syncing with Supabase…"
        case .synced(let date): return "Synced \(CloudDates.label(for: date).lowercased())"
        case .failed(let message): return "Sync failed · \(message)"
        }
    }

    func refresh() async {
        guard let client else { return }
        status = .syncing
        do {
            async let sessionRows: [SessionRow] = client.select("sessions", [URLQueryItem(name: "order", value: "created_at.desc")])
            async let memberRows: [ClubMember] = client.select("clubhouse_members", [URLQueryItem(name: "order", value: "rank.asc")])
            async let challengeRows: [ClubChallenge] = client.select("clubhouse_challenges")
            async let feedRows: [FeedPost] = client.select("clubhouse_feed", [URLQueryItem(name: "order", value: "created_at.desc")])
            async let announcementRows: [Announcement] = client.select("clubhouse_announcements", [URLQueryItem(name: "order", value: "created_at.desc")])

            sessions = try await sessionRows.map(\.practiceSession)
            members = try await memberRows
            challenges = try await challengeRows.sorted { ($0.joined ?? false) && !($1.joined ?? false) }
            feed = try await feedRows
            announcements = try await announcementRows
            stats = CloudProfileStats(sessions: sessions)
            status = .synced(Date())
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    func upload(_ session: PracticeSession) async -> PracticeSession? {
        guard let client else { return nil }
        do {
            let rows: [SessionRow] = try await client.insert("sessions", SessionRow(session))
            guard let saved = rows.first?.practiceSession else { return nil }
            sessions.insert(saved, at: 0)
            stats = CloudProfileStats(sessions: sessions)
            status = .synced(Date())
            return saved
        } catch {
            status = .failed(error.localizedDescription)
            return nil
        }
    }

    /// Mirrors the backend: the first profile row is the golfer, and the `is_you` member tracks it.
    func pushProfile(_ user: FairLieUser) async {
        guard let client else { return }
        do {
            let current: [ProfileRow] = try await client.select("profiles", [
                URLQueryItem(name: "order", value: "created_at.asc"),
                URLQueryItem(name: "limit", value: "1"),
            ])
            let handle = user.username.hasPrefix("@") ? String(user.username.dropFirst()) : user.username
            let patch = ProfileRow(
                displayName: user.name,
                handle: handle,
                initials: user.initials,
                handicap: user.handicap,
                preferredClubs: user.bag,
                bio: user.bio,
                location: user.city,
                streakDays: user.streakWeeks * 7,
                updatedAt: ISO8601DateFormatter().string(from: Date())
            )
            if let id = current.first?.id {
                let _: [ProfileRow] = try await client.update("profiles", where: [URLQueryItem(name: "id", value: "eq.\(id)")], patch)
            } else {
                let _: [ProfileRow] = try await client.insert("profiles", patch)
            }
            let member = MemberRow(name: user.name, handle: handle, initials: user.initials, handicap: user.handicap, streak: user.streakWeeks * 7)
            let updated: [ClubMember] = try await client.update(
                "clubhouse_members",
                where: [URLQueryItem(name: "is_you", value: "eq.true")],
                member
            )
            if !updated.isEmpty {
                members = try await client.select("clubhouse_members", [URLQueryItem(name: "order", value: "rank.asc")])
            }
            status = .synced(Date())
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    func join(_ challenge: ClubChallenge) async {
        await patch(challenge, ChallengePatch(joined: true, progress: nil))
    }

    func logProgress(_ challenge: ClubChallenge) async {
        let next = min(max(1, challenge.target ?? 1), (challenge.progress ?? 0) + 1)
        await patch(challenge, ChallengePatch(joined: true, progress: next))
    }

    func post(author: String, text: String) async -> Bool {
        let body = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let client, !body.isEmpty else { return false }
        do {
            let rows: [FeedPost] = try await client.insert("clubhouse_feed", NewFeedPost(author: author, text: body))
            feed.insert(contentsOf: rows, at: 0)
            return true
        } catch {
            status = .failed(error.localizedDescription)
            return false
        }
    }

    func like(_ post: FeedPost) async {
        guard let client else { return }
        do {
            let rows: [FeedPost] = try await client.update(
                "clubhouse_feed",
                where: [URLQueryItem(name: "id", value: "eq.\(post.id)")],
                LikesPatch(likes: (post.likes ?? 0) + 1)
            )
            if let updated = rows.first, let index = feed.firstIndex(where: { $0.id == updated.id }) {
                feed[index] = updated
            }
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    private func patch(_ challenge: ClubChallenge, _ body: ChallengePatch) async {
        guard let client else { return }
        do {
            let rows: [ClubChallenge] = try await client.update(
                "clubhouse_challenges",
                where: [URLQueryItem(name: "id", value: "eq.\(challenge.id)")],
                body
            )
            if let updated = rows.first, let index = challenges.firstIndex(where: { $0.id == updated.id }) {
                challenges[index] = updated
            }
        } catch {
            status = .failed(error.localizedDescription)
        }
    }
}
