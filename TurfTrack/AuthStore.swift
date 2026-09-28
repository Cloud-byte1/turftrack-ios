import AuthenticationServices
import Combine
import Foundation

enum AuthProvider: String, Codable {
    case email
    case apple
}

struct AuthAccount: Identifiable, Equatable {
    var id: String
    var email: String
    var provider: AuthProvider
    var city: String
    var needsSetup: Bool

    var resolvedProvider: AuthProvider { provider }
}

/// Accounts live in Supabase Auth; the session is kept in the Keychain by `AuthTokenStore`.
/// Each account owns one `profiles` row (created by the `on_auth_user_created` trigger).
@MainActor
final class AuthStore: ObservableObject {
    @Published private(set) var session: AuthAccount?
    @Published var user: FairLieUser = .sample
    @Published var errorMessage: String?
    @Published var infoMessage: String?
    @Published private(set) var isWorking = false
    @Published private(set) var isRestoring = true

    private let config = SupabaseConfig.load()
    private var profile: ProfileRow?
    private var appleNonce: String?

    var isSignedIn: Bool { session != nil }
    var needsProfileSetup: Bool { session?.needsSetup == true }

    init() {
        Task { await restore() }
    }

    // MARK: - Email

    func signIn(email: String, password: String) {
        let normalized = normalize(email)
        guard normalized.contains("@"), password.count >= 6 else {
            errorMessage = "Enter a valid email and a password of at least 6 characters."
            return
        }
        run { api in
            let tokens = try await api.signIn(email: normalized, password: password)
            try await self.start(tokens)
        }
    }

    func signUp(name: String, email: String, password: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = normalize(email)
        guard trimmed.count >= 2 else {
            errorMessage = "Enter your name to create an account."
            return
        }
        guard normalized.contains("@") else {
            errorMessage = "Enter a valid email address."
            return
        }
        guard password.count >= 6 else {
            errorMessage = "Password must be at least 6 characters."
            return
        }
        run { api in
            if let tokens = try await api.signUp(email: normalized, password: password, name: trimmed) {
                try await self.start(tokens)
            } else {
                self.infoMessage = "Check \(normalized) for a confirmation link, then come back and sign in."
            }
        }
    }

    func sendPasswordReset(email: String) {
        let normalized = normalize(email)
        guard normalized.contains("@") else {
            errorMessage = "Enter your email above, then tap Forgot password."
            return
        }
        run { api in
            try await api.sendPasswordReset(email: normalized)
            self.infoMessage = "If \(normalized) has an account, a reset link is on its way."
        }
    }

    // MARK: - Sign in with Apple

    func configureAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = AppleNonce.make()
        appleNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = AppleNonce.sha256(nonce)
    }

    func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        errorMessage = nil
        switch result {
        case .failure(let error):
            if (error as? ASAuthorizationError)?.code == .canceled { return }
            errorMessage = "Sign in with Apple failed. \(error.localizedDescription)"
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8),
                  let nonce = appleNonce
            else {
                errorMessage = "Sign in with Apple returned an unexpected credential."
                return
            }
            // Apple only shares the name on the very first authorization.
            let fullName = [credential.fullName?.givenName, credential.fullName?.familyName]
                .compactMap { $0 }
                .joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            run { api in
                let tokens = try await api.signInWithApple(idToken: idToken, nonce: nonce)
                try await self.start(tokens)
                if !fullName.isEmpty, self.profile?.needsSetup == true {
                    try await self.patchProfile(ProfileRow(displayName: fullName, initials: Self.initials(fullName)))
                }
            }
        }
    }

    // MARK: - Profile

    func completeSetup(city: String, handicap: Double, skill: String, bag: [String]) {
        run { _ in
            try await self.patchProfile(ProfileRow(
                handicap: handicap,
                preferredClubs: bag.isEmpty ? nil : bag,
                location: city,
                skill: skill,
                needsSetup: false
            ))
        }
    }

    func updateProfile(name: String, city: String, bio: String, handicap: Double) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        run { _ in
            try await self.patchProfile(ProfileRow(
                displayName: trimmed.isEmpty ? nil : trimmed,
                initials: trimmed.isEmpty ? nil : Self.initials(trimmed),
                handicap: handicap,
                bio: bio,
                location: city
            ))
        }
    }

    /// Fills the stats Home and Clubhouse show from the golfer's saved sessions.
    func apply(stats: CloudProfileStats) {
        guard session != nil else { return }
        user.sessions = stats.totalSessions
        user.strikeScore = stats.avgScore ?? 0
        user.bestClubScore = stats.bestScore ?? 0
        user.strikeXp = stats.totalSwings * 10
    }

    // MARK: - Sign out / delete

    func signOut() {
        if let config, let tokens = AuthTokenStore.shared.current {
            Task { await SupabaseAuthAPI(config: config).signOut(accessToken: tokens.accessToken) }
        }
        clearLocal()
    }

    /// Deletes the Supabase account and, via cascades, every row it owns
    /// (profile, sessions, posts, likes, RSVPs, challenge progress). App Review 5.1.1(v).
    func deleteAccount() async -> Bool {
        guard let config else { return false }
        isWorking = true
        defer { isWorking = false }
        do {
            try await SupabaseREST(config: config).rpcVoid("delete_my_account")
            clearLocal()
            for key in Self.userScopedKeys {
                UserDefaults.standard.removeObject(forKey: key)
            }
            return true
        } catch {
            errorMessage = "Could not delete your account. Check your connection and try again. (\(error.localizedDescription))"
            return false
        }
    }

    private static let userScopedKeys = [
        "fairlie.sessions",
        "fairlie.swings",
        "fairlie.preferences",
        "fairlie.hiddenPosts",
        "fairlie.blockedAuthors",
        "fairlie.accounts",
        "fairlie.sessionUserId",
    ]

    func exportAccountData() -> String {
        guard let account = session else { return "No account is signed in." }
        let lines = [
            "\(AppConfig.appName) account export",
            "Generated: \(ISO8601DateFormatter().string(from: Date()))",
            "",
            "Account ID: \(account.id)",
            "Email: \(account.email)",
            "Sign-in method: \(account.provider == .apple ? "Sign in with Apple" : "Email and password")",
            "Name: \(user.name)",
            "Username: \(user.username)",
            "City: \(user.city.isEmpty ? "—" : user.city)",
            "Handicap: \(String(format: "%.1f", user.handicap))",
            "Skill level: \(user.level)",
            "Bag: \(user.bag.joined(separator: ", "))",
            "Bio: \(user.bio.isEmpty ? "—" : user.bio)",
            "Saved sessions: \(user.sessions)",
            "",
            "Your profile, practice sessions, and Clubhouse activity are stored in the fairLie cloud (Supabase).",
            "Deleting your account removes all of it.",
        ]
        return lines.joined(separator: "\n")
    }

    // MARK: - Internals

    private func restore() async {
        defer { isRestoring = false }
        guard let config, var tokens = AuthTokenStore.shared.current else { return }
        if tokens.expiresAt < Date().addingTimeInterval(60) {
            do {
                tokens = try await SupabaseAuthAPI(config: config).refresh(tokens.refreshToken)
                AuthTokenStore.shared.set(tokens)
            } catch let error as AuthAPIError where error.isRejected {
                clearLocal()
                return
            } catch {
                // Offline: keep the stored session and load the profile when the network is back.
            }
        }
        do {
            try await start(tokens)
        } catch {
            session = AuthAccount(id: tokens.userID, email: tokens.email ?? "", provider: provider(tokens), city: "", needsSetup: false)
            user = FairLieUser.starter(name: tokens.email?.components(separatedBy: "@").first ?? "Golfer")
        }
    }

    private func start(_ tokens: AuthTokens) async throws {
        AuthTokenStore.shared.set(tokens)
        guard let config else { return }
        let client = SupabaseREST(config: config)
        let filter = [URLQueryItem(name: "user_id", value: "eq.\(tokens.userID)")]
        var rows: [ProfileRow] = try await client.select("profiles", filter)
        if rows.isEmpty {
            let name = tokens.email?.components(separatedBy: "@").first ?? "Golfer"
            rows = try await client.insert("profiles", ProfileRow(
                userId: tokens.userID,
                displayName: name,
                initials: Self.initials(name),
                needsSetup: true
            ))
        }
        guard let row = rows.first else { throw AuthAPIError.missingSession }
        apply(row, tokens: tokens)
    }

    private func patchProfile(_ patch: ProfileRow) async throws {
        guard let config, let tokens = AuthTokenStore.shared.current else { return }
        var body = patch
        body.updatedAt = ISO8601DateFormatter().string(from: Date())
        let rows: [ProfileRow] = try await SupabaseREST(config: config).update(
            "profiles",
            where: [URLQueryItem(name: "user_id", value: "eq.\(tokens.userID)")],
            body
        )
        if let row = rows.first { apply(row, tokens: tokens) }
    }

    private func apply(_ row: ProfileRow, tokens: AuthTokens) {
        profile = row
        let name = row.displayName ?? "Golfer"
        session = AuthAccount(
            id: tokens.userID,
            email: tokens.email ?? "",
            provider: provider(tokens),
            city: row.location ?? "",
            needsSetup: row.needsSetup ?? false
        )
        var next = FairLieUser.starter(name: name)
        next.username = "@\(row.handle ?? name.lowercased())"
        next.city = row.location ?? ""
        next.handicap = row.handicap ?? next.handicap
        next.level = row.skill ?? next.level
        next.bag = row.preferredClubs ?? next.bag
        next.bio = row.bio ?? next.bio
        next.streakWeeks = (row.streakDays ?? 0) / 7
        next.sessions = user.sessions
        next.strikeScore = user.strikeScore
        next.bestClubScore = user.bestClubScore
        next.strikeXp = user.strikeXp
        user = next
    }

    private func clearLocal() {
        AuthTokenStore.shared.set(nil)
        session = nil
        profile = nil
        user = .sample
        errorMessage = nil
        infoMessage = nil
    }

    private func provider(_ tokens: AuthTokens) -> AuthProvider {
        tokens.provider == "apple" ? .apple : .email
    }

    private func normalize(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func initials(_ name: String) -> String {
        let parts = name.split(separator: " ").prefix(2)
        return parts.map { String($0.prefix(1)).uppercased() }.joined()
    }

    private func run(_ work: @escaping (SupabaseAuthAPI) async throws -> Void) {
        guard let config else {
            errorMessage = "fairLie cloud is not configured in this build."
            return
        }
        errorMessage = nil
        infoMessage = nil
        isWorking = true
        Task {
            defer { isWorking = false }
            do {
                try await work(SupabaseAuthAPI(config: config))
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
