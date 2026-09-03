import Foundation

/// Single source of truth for the App Store facing metadata that has to match
/// what is entered in App Store Connect.
enum AppConfig {
    static let appName = "fairLie"
    static let subtitle = "Golf strike & swing training"
    static let bundleIdentifier = "com.fairlie.turftrack"

    static let supportURL = URL(string: "https://fairlie.app/support")!
    static let marketingURL = URL(string: "https://fairlie.app")!
    static let privacyPolicyURL = URL(string: "https://fairlie.app/privacy")!
    static let termsOfUseURL = URL(string: "https://fairlie.app/terms")!

    /// Apple's standard EULA link, used when no custom terms are supplied.
    static let appleStandardEULAURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    static let supportEmail = "support@fairlie.app"

    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    static var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }

    static var versionLabel: String { "Version \(version) (\(build))" }

    static var supportMailtoURL: URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = supportEmail
        components.queryItems = [
            URLQueryItem(name: "subject", value: "\(appName) support — \(versionLabel)")
        ]
        return components.url
    }
}
