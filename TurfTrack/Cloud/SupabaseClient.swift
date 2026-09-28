import Foundation

/// Reads `Config/Supabase.plist` from the app bundle. That file is gitignored;
/// copy `Config/Supabase.example.plist` and fill in your project URL + publishable key.
struct SupabaseConfig {
    let url: URL
    let anonKey: String

    static func load(bundle: Bundle = .main) -> SupabaseConfig? {
        let fileURL = bundle.url(forResource: "Supabase", withExtension: "plist", subdirectory: "Config")
            ?? bundle.url(forResource: "Supabase", withExtension: "plist")
        guard let fileURL,
              let data = try? Data(contentsOf: fileURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let urlString = plist["SUPABASE_URL"] as? String,
              let key = plist["SUPABASE_ANON_KEY"] as? String,
              let url = URL(string: urlString),
              !key.isEmpty, !urlString.contains("YOUR_"), !key.contains("YOUR_")
        else { return nil }
        return SupabaseConfig(url: url, anonKey: key)
    }
}

enum SupabaseError: LocalizedError {
    case http(Int, String)

    /// The lockdown SQL has not been run yet, so the RPC does not exist.
    var isMissingFunction: Bool {
        if case .http(let code, let body) = self {
            return code == 404 || body.contains("PGRST202")
        }
        return false
    }

    var errorDescription: String? {
        switch self {
        case .http(let code, let body): return "Supabase \(code): \(body.prefix(160))"
        }
    }
}

/// Minimal PostgREST client — enough for the Strike Lab tables in `backend/supabase/schema.sql`.
struct SupabaseREST {
    let config: SupabaseConfig
    var session: URLSession = .shared

    func select<T: Decodable>(_ table: String, _ query: [URLQueryItem] = []) async throws -> [T] {
        try await send(table, method: "GET", query: [URLQueryItem(name: "select", value: "*")] + query)
    }

    func insert<T: Decodable, Body: Encodable>(_ table: String, _ body: Body) async throws -> [T] {
        try await send(table, method: "POST", body: body)
    }

    func update<T: Decodable, Body: Encodable>(_ table: String, where filters: [URLQueryItem], _ body: Body) async throws -> [T] {
        try await send(table, method: "PATCH", query: filters, body: body)
    }

    /// Calls a `returns setof <table>` function from `app_store_lockdown.sql`.
    func rpc<T: Decodable, Body: Encodable>(_ function: String, _ args: Body) async throws -> [T] {
        try await send("rpc/\(function)", method: "POST", body: args)
    }

    func delete(_ table: String, where filters: [URLQueryItem]) async throws {
        let _: [Empty] = try await send(table, method: "DELETE", query: filters)
    }

    /// For `returns void` functions such as `delete_my_account`.
    func rpcVoid(_ function: String) async throws {
        let _: [Empty] = try await send("rpc/\(function)", method: "POST", body: [String: String]())
    }

    private struct Empty: Decodable {}

    private func send<T: Decodable>(
        _ table: String,
        method: String,
        query: [URLQueryItem] = [],
        body: (any Encodable)? = nil,
        retried: Bool = false
    ) async throws -> [T] {
        var components = URLComponents(url: config.url.appendingPathComponent("rest/v1/\(table)"), resolvingAgainstBaseURL: false)!
        if !query.isEmpty { components.queryItems = query }
        var request = URLRequest(url: components.url!)
        request.httpMethod = method
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        if let bearer = await bearerToken(forceRefresh: retried) {
            request.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
        }
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("return=representation", forHTTPHeaderField: "Prefer")
            request.httpBody = try JSONEncoder().encode(body)
        }
        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 401, !retried, AuthTokenStore.shared.current != nil {
            return try await send(table, method: method, query: query, body: body, retried: true)
        }
        guard (200..<300).contains(status) else {
            throw SupabaseError.http(status, String(data: data, encoding: .utf8) ?? "")
        }
        let trimmed = data.drop { $0 == 0x20 || $0 == 0x0A }
        if trimmed.isEmpty || trimmed.first != UInt8(ascii: "[") { return [] }
        return try JSONDecoder().decode([T].self, from: data)
    }

    /// Signed-in user's JWT (refreshed when close to expiry); legacy JWT anon keys otherwise.
    /// New publishable keys only go in `apikey`, never in Authorization.
    private func bearerToken(forceRefresh: Bool) async -> String? {
        guard var tokens = AuthTokenStore.shared.current else {
            return config.anonKey.hasPrefix("eyJ") ? config.anonKey : nil
        }
        if forceRefresh || tokens.expiresAt < Date().addingTimeInterval(60) {
            if let refreshed = try? await SupabaseAuthAPI(config: config).refresh(tokens.refreshToken) {
                AuthTokenStore.shared.set(refreshed)
                tokens = refreshed
            }
        }
        return tokens.accessToken
    }
}
