import AuthenticationServices
import Combine
import Foundation

enum AuthProvider: String, Codable {
    case email
    case apple
}

struct AuthAccount: Codable, Identifiable, Equatable {
    var id: String
    var email: String
    var password: String
    var name: String
    var username: String
    var city: String
    var handicap: Double
    var skill: String
    var bag: [String]
    var bio: String
    var needsSetup: Bool
    /// Absent in accounts saved before Sign in with Apple shipped, so it decodes as nil.
    var provider: AuthProvider?
    var appleUserID: String?

    var resolvedProvider: AuthProvider { provider ?? .email }
}

@MainActor
final class AuthStore: ObservableObject {
    @Published private(set) var session: AuthAccount?
    @Published var user: FairLieUser = .sample
    @Published var errorMessage: String?

    private var accounts: [AuthAccount] = []
    private let accountsKey = "fairlie.accounts"
    private let sessionKey = "fairlie.sessionUserId"

    var isSignedIn: Bool { session != nil }
    var needsProfileSetup: Bool { session?.needsSetup == true }

    init() {
        load()
    }

    func signIn(email: String, password: String) {
        errorMessage = nil
        let normalized = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard normalized.contains("@"), password.count >= 6 else {
            errorMessage = "Enter a valid email and a password of at least 6 characters."
            return
        }
        guard let account = accounts.first(where: { $0.email == normalized && $0.password == password }) else {
            errorMessage = "Email or password is incorrect."
            return
        }
        apply(account)
    }

    func signUp(name: String, email: String, password: String) {
        errorMessage = nil
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
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
        if accounts.contains(where: { $0.email == normalized }) {
            errorMessage = "An account with this email already exists. Sign in instead."
            return
        }
        let slug = trimmed.lowercased().replacingOccurrences(of: " ", with: "_")
        let account = AuthAccount(
            id: "\(slug)-\(Int(Date().timeIntervalSince1970))",
            email: normalized,
            password: password,
            name: trimmed,
            username: "@\(slug)_golf",
            city: "",
            handicap: 18,
            skill: "Beginner",
            bag: ["Driver", "7 Iron", "Pitching Wedge"],
            bio: "New to fairLie — building my strike.",
            needsSetup: true,
            provider: .email,
            appleUserID: nil
        )
        accounts.append(account)
        apply(account)
        persist()
    }

    // MARK: - Sign in with Apple

    func configureAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        request.requestedScopes = [.fullName, .email]
    }

    func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        errorMessage = nil
        switch result {
        case .failure(let error):
            if (error as? ASAuthorizationError)?.code == .canceled { return }
            errorMessage = "Sign in with Apple failed. \(error.localizedDescription)"
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                errorMessage = "Sign in with Apple returned an unexpected credential."
                return
            }
            signInWithApple(credential: credential)
        }
    }

    private func signInWithApple(credential: ASAuthorizationAppleIDCredential) {
        let appleUserID = credential.user

        // Apple only returns name and email on the very first authorization, so an
        // existing account is matched on the stable user identifier.
        if let existing = accounts.first(where: { $0.appleUserID == appleUserID }) {
            apply(existing)
            return
        }

        let fullName = [credential.fullName?.givenName, credential.fullName?.familyName]
            .compactMap { $0 }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = fullName.isEmpty ? "fairLie Golfer" : fullName
        let email = credential.email?.lowercased() ?? "\(appleUserID.prefix(8))@privaterelay.appleid.com"

        if let index = accounts.firstIndex(where: { $0.email == email }) {
            // Link Apple to the account this person already created with email.
            accounts[index].appleUserID = appleUserID
            let linked = accounts[index]
            apply(linked)
            persist()
            return
        }

        let slug = displayName.lowercased().replacingOccurrences(of: " ", with: "_")
        let account = AuthAccount(
            id: "apple-\(appleUserID.prefix(12))",
            email: email,
            password: "",
            name: displayName,
            username: "@\(slug)_golf",
            city: "",
            handicap: 18,
            skill: "Beginner",
            bag: ["Driver", "7 Iron", "Pitching Wedge"],
            bio: "New to fairLie — building my strike.",
            needsSetup: true,
            provider: .apple,
            appleUserID: appleUserID
        )
        accounts.append(account)
        apply(account)
        persist()
    }

    func completeSetup(city: String, handicap: Double, skill: String, bag: [String]) {
        guard var account = session else { return }
        account.city = city
        account.handicap = handicap
        account.skill = skill
        account.bag = bag.isEmpty ? account.bag : bag
        account.needsSetup = false
        update(account)
    }

    func updateProfile(name: String, city: String, bio: String, handicap: Double) {
        guard var account = session else { return }
        account.name = name
        account.city = city
        account.bio = bio
        account.handicap = handicap
        update(account)
    }

    func signOut() {
        session = nil
        user = .sample
        UserDefaults.standard.removeObject(forKey: sessionKey)
    }

    /// Permanently removes the signed-in account and everything stored against it.
    /// Required by App Store Review Guideline 5.1.1(v) for any app with account creation.
    func deleteAccount() {
        guard let account = session else { return }
        accounts.removeAll { $0.id == account.id }
        persist()

        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: sessionKey)
        for key in Self.userScopedKeys {
            defaults.removeObject(forKey: key)
        }

        session = nil
        user = .sample
        errorMessage = nil
    }

    /// Everything written to disk on the user's behalf, cleared on account deletion.
    private static let userScopedKeys = [
        "fairlie.sessions",
        "fairlie.swings",
        "fairlie.preferences"
    ]

    /// Plain-text copy of the account record, for the "download my data" affordance.
    func exportAccountData() -> String {
        guard let account = session else { return "No account is signed in." }
        var lines = [
            "\(AppConfig.appName) account export",
            "Generated: \(ISO8601DateFormatter().string(from: Date()))",
            "",
            "Name: \(account.name)",
            "Username: \(account.username)",
            "Email: \(account.email)",
            "Sign-in method: \(account.resolvedProvider == .apple ? "Sign in with Apple" : "Email and password")",
            "City: \(account.city.isEmpty ? "—" : account.city)",
            "Handicap: \(String(format: "%.1f", account.handicap))",
            "Skill level: \(account.skill)",
            "Bag: \(account.bag.joined(separator: ", "))",
            "Bio: \(account.bio.isEmpty ? "—" : account.bio)"
        ]
        lines.append("")
        lines.append("Account data is stored on this device only and is not uploaded to a server.")
        return lines.joined(separator: "\n")
    }

    private func update(_ account: AuthAccount) {
        if let index = accounts.firstIndex(where: { $0.id == account.id }) {
            accounts[index] = account
        }
        apply(account)
        persist()
    }

    private func apply(_ account: AuthAccount) {
        session = account
        var next = FairLieUser.starter(name: account.name)
        next.username = account.username
        next.city = account.city
        next.handicap = account.handicap
        next.level = account.skill
        next.bag = account.bag
        next.bio = account.bio
        if account.name.lowercased().contains("carmi") && !account.needsSetup {
            next = .sample
            next.name = account.name
            next.city = account.city.isEmpty ? next.city : account.city
            next.handicap = account.handicap == 0 ? next.handicap : account.handicap
            next.bio = account.bio.isEmpty ? next.bio : account.bio
            next.bag = account.bag
        }
        user = next
        UserDefaults.standard.set(account.id, forKey: sessionKey)
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(accounts) {
            UserDefaults.standard.set(data, forKey: accountsKey)
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: accountsKey),
           let saved = try? JSONDecoder().decode([AuthAccount].self, from: data) {
            accounts = saved
        }
        if let id = UserDefaults.standard.string(forKey: sessionKey),
           let account = accounts.first(where: { $0.id == id }) {
            apply(account)
        }
    }
}
