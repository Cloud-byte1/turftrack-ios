import Combine
import Foundation

/// Supabase-backed sessions and Clubhouse for the signed-in golfer. Row-level security
/// scopes sessions, challenge progress, RSVPs, and likes to `auth.uid()`.
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
    @Published private(set) var events: [ClubEvent] = []
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
    var currentUserID: String? { AuthTokenStore.shared.current?.userID }

    var statusLabel: String {
        switch status {
        case .offline: return isConfigured ? "Not synced yet" : "Clubhouse offline"
        case .syncing: return "Syncing Clubhouse…"
        case .synced(let date): return "Synced \(CloudDates.label(for: date).lowercased())"
        case .failed(let message): return "Sync failed · \(message)"
        }
    }

    /// Feed minus anything this user reported or whose author they blocked (App Review 1.2).
    var visibleFeed: [FeedPost] {
        feed.filter { !hiddenPostIDs.contains($0.id) && !blockedAuthors.contains($0.author) }
    }

    func isMine(_ post: FeedPost) -> Bool {
        post.userId != nil && post.userId == currentUserID
    }

    func isMe(_ member: ClubMember) -> Bool {
        member.userId != nil && member.userId == currentUserID
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

    /// Clears everything tied to the previous account.
    func reset() {
        status = .offline
        sessions = []
        members = []
        challenges = []
        feed = []
        announcements = []
        events = []
        stats = CloudProfileStats()
    }

    func refresh() async {
        guard let client else { return }
        guard currentUserID != nil else {
            reset()
            return
        }
        status = .syncing
        do {
            async let sessionRows: [SessionRow] = client.select("sessions", [URLQueryItem(name: "order", value: "created_at.desc")])
            async let memberRows: [ClubMember] = client.select("clubhouse_members", [URLQueryItem(name: "order", value: "score.desc")])
            async let feedRows: [FeedPost] = client.select("clubhouse_feed", [URLQueryItem(name: "order", value: "created_at.desc")])
            async let announcementRows: [Announcement] = client.select("clubhouse_announcements", [URLQueryItem(name: "order", value: "created_at.desc")])
            async let challengeRows: [ClubChallenge] = client.rpc("list_challenges", NoArgs())
            async let eventRows: [ClubEvent] = client.rpc("list_events", NoArgs())

            sessions = try await sessionRows.map(\.practiceSession)
            members = try await memberRows
            feed = try await feedRows
            announcements = try await announcementRows
            challenges = try await challengeRows.sorted { ($0.joined ?? false) && !($1.joined ?? false) }
            events = (try? await eventRows) ?? []
            stats = CloudProfileStats(sessions: sessions)
            status = .synced(Date())
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    func upload(_ session: PracticeSession) async -> PracticeSession? {
        guard let client, currentUserID != nil, !session.isSimulated else { return nil }
        do {
            let rows: [SessionRow] = try await client.insert("sessions", SessionRow(session))
            guard let saved = rows.first?.practiceSession else { return nil }
            sessions.insert(saved, at: 0)
            stats = CloudProfileStats(sessions: sessions)
            members = (try? await client.select("clubhouse_members", [URLQueryItem(name: "order", value: "score.desc")])) ?? members
            status = .synced(Date())
            return saved
        } catch {
            status = .failed(error.localizedDescription)
            return nil
        }
    }

    func join(_ challenge: ClubChallenge) async {
        await replaceChallenge(rpc: "join_challenge", challenge)
    }

    func logProgress(_ challenge: ClubChallenge) async {
        await replaceChallenge(rpc: "log_challenge_progress", challenge)
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

    func delete(_ post: FeedPost) async {
        guard let client, isMine(post) else { return }
        do {
            try await client.delete("clubhouse_feed", where: [URLQueryItem(name: "id", value: "eq.\(post.id)")])
            feed.removeAll { $0.id == post.id }
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    func like(_ post: FeedPost) async {
        guard let client else { return }
        do {
            let rows: [FeedPost] = try await client.rpc("like_post", IDArg(p_id: post.id))
            if let updated = rows.first, let index = feed.firstIndex(where: { $0.id == updated.id }) {
                feed[index] = updated
            }
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    func rsvp(_ event: ClubEvent) async {
        guard event.rsvped != true, let client else { return }
        do {
            let rows: [ClubEvent] = try await client.rpc("rsvp_event", IDArg(p_id: event.id))
            if let updated = rows.first, let index = events.firstIndex(where: { $0.id == updated.id }) {
                events[index] = updated
            }
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    private func replaceChallenge(rpc function: String, _ challenge: ClubChallenge) async {
        guard let client else { return }
        do {
            let rows: [ClubChallenge] = try await client.rpc(function, IDArg(p_id: challenge.id))
            if let updated = rows.first, let index = challenges.firstIndex(where: { $0.id == updated.id }) {
                challenges[index] = updated
            }
        } catch {
            status = .failed(error.localizedDescription)
        }
    }
}
