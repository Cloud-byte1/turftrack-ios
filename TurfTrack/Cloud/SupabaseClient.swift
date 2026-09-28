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

    private func send<T: Decodable>(
        _ table: String,
        method: String,
        query: [URLQueryItem] = [],
        body: (any Encodable)? = nil
    ) async throws -> [T] {
        var components = URLComponents(url: config.url.appendingPathComponent("rest/v1/\(table)"), resolvingAgainstBaseURL: false)!
        if !query.isEmpty { components.queryItems = query }
        var request = URLRequest(url: components.url!)
        request.httpMethod = method
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        // Legacy anon keys are JWTs and also go in Authorization; new publishable keys must not.
        if config.anonKey.hasPrefix("eyJ") {
            request.setValue("Bearer \(config.anonKey)", forHTTPHeaderField: "Authorization")
        }
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("return=representation", forHTTPHeaderField: "Prefer")
            request.httpBody = try JSONEncoder().encode(body)
        }
        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            throw SupabaseError.http(status, String(data: data, encoding: .utf8) ?? "")
        }
        if data.isEmpty { return [] }
        return try JSONDecoder().decode([T].self, from: data)
    }
}
