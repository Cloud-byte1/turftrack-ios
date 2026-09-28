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
    @Published private(set) var events: [ClubEvent] = ClubEvent.fallback
    @Published private(set) var stats = CloudProfileStats()
    @Published private(set) var hiddenPostIDs: Set<String>
    @Published private(set) var blockedAuthors: Set<String>

    private let client: SupabaseREST?
    private static let hiddenKey = "fairlie.hiddenPosts"
    private static let blockedKey = "fairlie.blockedAuthors"

    init(config: SupabaseConfig? = SupabaseConfig.load()) {
        client = config.map { SupabaseREST(config: $0) }
        let defaults = UserDefaults.standard
        hiddenPostIDs = Set(defaults.stringArray(forKey: Self.hiddenKey) ?? [])
        blockedAuthors = Set(defaults.stringArray(forKey: Self.blockedKey) ?? [])
    }

    var isConfigured: Bool { client != nil }

    /// Feed minus anything this user reported or whose author they blocked (App Review 1.2).
    var visibleFeed: [FeedPost] {
        feed.filter { !hiddenPostIDs.contains($0.id) && !blockedAuthors.contains($0.author) }
    }

    func hide(_ post: FeedPost) {
        hiddenPostIDs.insert(post.id)
        UserDefaults.standard.set(Array(hiddenPostIDs), forKey: Self.hiddenKey)
    }

    func block(author: String) {
        blockedAuthors.insert(author)
        UserDefaults.standard.set(Array(blockedAuthors), forKey: Self.blockedKey)
    }

    func unblockAll() {
        blockedAuthors = []
        hiddenPostIDs = []
        UserDefaults.standard.removeObject(forKey: Self.blockedKey)
        UserDefaults.standard.removeObject(forKey: Self.hiddenKey)
    }

    var statusLabel: String {
        switch status {
        case .offline: return isConfigured ? "Not synced yet" : "Offline · sample data"
        case .syncing: return "Syncing Clubhouse…"
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
            async let eventRows: [ClubEvent] = client.select("clubhouse_events", [URLQueryItem(name: "order", value: "created_at.asc")])

            sessions = try await sessionRows.map(\.practiceSession)
            members = try await memberRows
            challenges = try await challengeRows.sorted { ($0.joined ?? false) && !($1.joined ?? false) }
            feed = try await feedRows
            announcements = try await announcementRows
            // clubhouse_events arrives with app_store_lockdown.sql; keep the built-in list until then.
            if let rows = try? await eventRows, !rows.isEmpty { events = rows }
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

    func pushProfile(_ user: FairLieUser) async {
        guard let client else { return }
        let handle = user.username.hasPrefix("@") ? String(user.username.dropFirst()) : user.username
        let args = ProfileArgs(
            p_display_name: user.name,
            p_handle: handle,
            p_handicap: user.handicap,
            p_bio: user.bio,
            p_location: user.city,
            p_preferred_clubs: user.bag,
            p_streak_days: user.streakWeeks * 7
        )
        do {
            do {
                let _: [ProfileRow] = try await client.rpc("update_profile", args)
            } catch let error as SupabaseError where error.isMissingFunction {
                try await legacyProfileUpdate(client, user: user, handle: handle)
            }
            members = try await client.select("clubhouse_members", [URLQueryItem(name: "order", value: "rank.asc")])
            status = .synced(Date())
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    func join(_ challenge: ClubChallenge) async {
        await replaceChallenge(
            rpc: "join_challenge",
            challenge,
            legacy: ChallengePatch(joined: true, progress: nil)
        )
    }

    func logProgress(_ challenge: ClubChallenge) async {
        let next = min(max(1, challenge.target ?? 1), (challenge.progress ?? 0) + 1)
        await replaceChallenge(
            rpc: "log_challenge_progress",
            challenge,
            legacy: ChallengePatch(joined: true, progress: next)
        )
    }

    func post(author: String, text: String) async -> Bool {
        let body = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let client, !body.isEmpty else { return false }
        do {
            let rows: [FeedPost] = try await client.insert(
                "clubhouse_feed",
                NewFeedPost(author: String(author.prefix(60)), text: String(body.prefix(500)))
            )
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
            let rows: [FeedPost]
            do {
                rows = try await client.rpc("like_post", IDArg(p_id: post.id))
            } catch let error as SupabaseError where error.isMissingFunction {
                rows = try await client.update(
                    "clubhouse_feed",
                    where: [URLQueryItem(name: "id", value: "eq.\(post.id)")],
                    LikesPatch(likes: (post.likes ?? 0) + 1)
                )
            }
            if let updated = rows.first, let index = feed.firstIndex(where: { $0.id == updated.id }) {
                feed[index] = updated
            }
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    func rsvp(_ event: ClubEvent) async {
        guard event.rsvped != true else { return }
        var local = event
        local.rsvped = true
        local.attendees = (event.attendees ?? 0) + 1
        guard let client else {
            replace(local)
            return
        }
        do {
            let rows: [ClubEvent] = try await client.rpc("rsvp_event", IDArg(p_id: event.id))
            replace(rows.first ?? local)
        } catch let error as SupabaseError where error.isMissingFunction {
            replace(local)
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    private func replace(_ event: ClubEvent) {
        if let index = events.firstIndex(where: { $0.id == event.id }) {
            events[index] = event
        }
    }

    private func replaceChallenge(rpc function: String, _ challenge: ClubChallenge, legacy: ChallengePatch) async {
        guard let client else { return }
        do {
            let rows: [ClubChallenge]
            do {
                rows = try await client.rpc(function, IDArg(p_id: challenge.id))
            } catch let error as SupabaseError where error.isMissingFunction {
                rows = try await client.update(
                    "clubhouse_challenges",
                    where: [URLQueryItem(name: "id", value: "eq.\(challenge.id)")],
                    legacy
                )
            }
            if let updated = rows.first, let index = challenges.firstIndex(where: { $0.id == updated.id }) {
                challenges[index] = updated
            }
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    /// Direct table writes for databases that still have the dev-open policies from schema.sql.
    private func legacyProfileUpdate(_ client: SupabaseREST, user: FairLieUser, handle: String) async throws {
        let current: [ProfileRow] = try await client.select("profiles", [
            URLQueryItem(name: "order", value: "created_at.asc"),
            URLQueryItem(name: "limit", value: "1"),
        ])
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
        let _: [ClubMember] = try await client.update(
            "clubhouse_members",
            where: [URLQueryItem(name: "is_you", value: "eq.true")],
            member
        )
    }
}
