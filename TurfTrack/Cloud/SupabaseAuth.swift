import CryptoKit
import Foundation
import Security

struct AuthTokens: Codable, Equatable {
    var accessToken: String
    var refreshToken: String
    var expiresAt: Date
    var userID: String
    var email: String?
    var provider: String?
}

/// Current Supabase session, readable from any thread and persisted in the Keychain.
final class AuthTokenStore: @unchecked Sendable {
    static let shared = AuthTokenStore()

    private let lock = NSLock()
    private var tokens: AuthTokens?
    private let service = "com.fairlie.turftrack.auth"
    private let account = "supabase.session"

    init() {
        tokens = readKeychain()
    }

    var current: AuthTokens? {
        lock.lock()
        defer { lock.unlock() }
        return tokens
    }

    func set(_ next: AuthTokens?) {
        lock.lock()
        tokens = next
        lock.unlock()
        if let next, let data = try? JSONEncoder().encode(next) {
            writeKeychain(data)
        } else {
            deleteKeychain()
        }
    }

    private var baseQuery: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }

    private func readKeychain() -> AuthTokens? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess, let data = item as? Data else { return nil }
        return try? JSONDecoder().decode(AuthTokens.self, from: data)
    }

    private func writeKeychain(_ data: Data) {
        deleteKeychain()
        var query = baseQuery
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(query as CFDictionary, nil)
    }

    private func deleteKeychain() {
        SecItemDelete(baseQuery as CFDictionary)
    }
}

enum AuthAPIError: LocalizedError {
    case server(Int, String)
    case missingSession

    var errorDescription: String? {
        switch self {
        case .server(_, let message): return message
        case .missingSession: return "Supabase did not return a session."
        }
    }

    /// The refresh token was rejected, so the user has to sign in again.
    var isRejected: Bool {
        if case .server(let code, _) = self { return code == 400 || code == 401 || code == 403 }
        return false
    }
}

/// Supabase Auth (GoTrue) over REST: email/password, Sign in with Apple, refresh, sign out.
struct SupabaseAuthAPI {
    let config: SupabaseConfig
    var session: URLSession = .shared

    /// Returns nil when the project requires email confirmation before the first sign-in.
    func signUp(email: String, password: String, name: String) async throws -> AuthTokens? {
        let response = try await post("signup", body: [
            "email": email,
            "password": password,
            "data": ["name": name],
        ])
        return try? tokens(from: response)
    }

    func signIn(email: String, password: String) async throws -> AuthTokens {
        try tokens(from: try await post("token?grant_type=password", body: ["email": email, "password": password]))
    }

    func signInWithApple(idToken: String, nonce: String) async throws -> AuthTokens {
        try tokens(from: try await post("token?grant_type=id_token", body: [
            "provider": "apple",
            "id_token": idToken,
            "nonce": nonce,
        ]))
    }

    func refresh(_ refreshToken: String) async throws -> AuthTokens {
        try tokens(from: try await post("token?grant_type=refresh_token", body: ["refresh_token": refreshToken]))
    }

    func sendPasswordReset(email: String) async throws {
        _ = try await post("recover", body: ["email": email])
    }

    func signOut(accessToken: String) async {
        _ = try? await post("logout", body: [:], bearer: accessToken)
    }

    /// Asks the `apple-revoke` Edge Function to exchange a fresh Apple authorization code
    /// and revoke the user's Apple tokens (App Review 5.1.1(v)). Must run before the account is deleted.
    func revokeApple(authorizationCode: String, accessToken: String) async throws {
        _ = try await post("apple-revoke", base: "functions/v1", body: ["code": authorizationCode], bearer: accessToken)
    }

    private func post(_ path: String, base: String = "auth/v1", body: [String: Any], bearer: String? = nil) async throws -> [String: Any] {
        var request = URLRequest(url: URL(string: "\(base)/\(path)", relativeTo: config.url)!)
        request.httpMethod = "POST"
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let bearer {
            request.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        guard (200..<300).contains(status) else {
            let message = json["msg"] as? String
                ?? json["error_description"] as? String
                ?? json["message"] as? String
                ?? json["error"] as? String
                ?? "Sign-in failed (\(status))."
            throw AuthAPIError.server(status, Self.friendly(message))
        }
        return json
    }

    private func tokens(from json: [String: Any]) throws -> AuthTokens {
        guard let access = json["access_token"] as? String,
              let refresh = json["refresh_token"] as? String,
              let user = json["user"] as? [String: Any],
              let id = user["id"] as? String
        else { throw AuthAPIError.missingSession }
        let expiresIn = (json["expires_in"] as? Double) ?? 3600
        let provider = (user["app_metadata"] as? [String: Any])?["provider"] as? String
        return AuthTokens(
            accessToken: access,
            refreshToken: refresh,
            expiresAt: Date().addingTimeInterval(expiresIn),
            userID: id,
            email: user["email"] as? String,
            provider: provider
        )
    }

    private static func friendly(_ message: String) -> String {
        switch message.lowercased() {
        case let m where m.contains("invalid login credentials"): return "Email or password is incorrect."
        case let m where m.contains("email not confirmed"): return "Confirm your email first — check your inbox for the link."
        case let m where m.contains("already registered"): return "An account with this email already exists. Sign in instead."
        default: return message
        }
    }
}

enum AppleNonce {
    static func make(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var bytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, length, &bytes)
        return String(bytes.map { charset[Int($0) % charset.count] })
    }

    static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
