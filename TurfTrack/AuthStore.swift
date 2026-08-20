import Combine
import Foundation

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
            needsSetup: true
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
