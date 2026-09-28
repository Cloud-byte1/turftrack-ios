import SwiftUI
import UIKit

enum LegalDocument: String, Identifiable {
    case privacy
    case terms

    var id: String { rawValue }

    var title: String {
        switch self {
        case .privacy: return "Privacy Policy"
        case .terms: return "Terms of Use"
        }
    }

    var hostedURL: URL {
        switch self {
        case .privacy: return AppConfig.privacyPolicyURL
        case .terms: return AppConfig.termsOfUseURL
        }
    }

    var effectiveDate: String {
        switch self {
        case .privacy: return "September 28, 2026"
        case .terms: return "September 28, 2026"
        }
    }

    var sections: [LegalSection] {
        switch self {
        case .privacy: return LegalCopy.privacySections
        case .terms: return LegalCopy.termsSections
        }
    }
}

struct LegalSection: Identifiable {
    var id: String { heading }
    let heading: String
    let body: String
}

/// In-app mirror of the publicly hosted policy pages. The hosted URLs remain the
/// canonical versions submitted to App Store Connect.
enum LegalCopy {
    static let privacySections: [LegalSection] = [
        LegalSection(
            heading: "What we collect",
            body: """
            With an account, fairLie collects the profile details you enter — name, username, email address, home city, handicap, skill level, club bag, and bio — plus the practice sessions you save and anything you post in the Clubhouse. Session data includes strike scores, strike location and pressure on the mat, estimated carry, club speed, and attack angle, ball speed (measured when the radar is linked, otherwise estimated), club path, and when the session happened.
            """
        ),
        LegalSection(
            heading: "How your data is stored",
            body: """
            Accounts: your profile, practice sessions, and Clubhouse activity are stored with our cloud database provider, Supabase. Sign-in tokens are kept in your iPhone's Keychain. Your practice sessions are private to your account. Your display name, username, handicap, streak, and average strike score appear on the Clubhouse leaderboard, and posts you share in the Clubhouse feed are visible to other signed-in golfers.

            Guest mode: if you continue without an account, your profile and sessions are stored only on this iPhone and are never uploaded. Sessions that include simulated swings are also kept only on this iPhone, even when you're signed in.

            We do not sell or share your data with data brokers or advertisers.
            """
        ),
        LegalSection(
            heading: "Bluetooth",
            body: """
            fairLie uses Bluetooth only to connect to your GolfMat practice mat and the optional fairLie radar sensor, receive strike readings from them, and reconnect to the last device you used. Bluetooth is never used to determine your location, to build an advertising profile, or to scan for nearby people or beacons.
            """
        ),
        LegalSection(
            heading: "Sign in with Apple",
            body: """
            When you choose Sign in with Apple, Apple provides fairLie with a stable, app-specific user identifier and — only on your first sign-in — the name and email address you approve. If you use Apple's Hide My Email feature we receive a private relay address instead of your real one. We use this information only to create and recognize your account.
            """
        ),
        LegalSection(
            heading: "Tracking and analytics",
            body: """
            fairLie does not track you across apps or websites owned by other companies, does not use third-party advertising SDKs, and does not request the App Tracking Transparency permission.
            """
        ),
        LegalSection(
            heading: "Your choices",
            body: """
            You can edit your profile at any time from Settings. You can export a copy of your account record from Settings → Privacy & data. You can permanently delete your account and all associated data — profile, sessions, posts, likes, RSVPs, and challenge progress — from Settings → Delete account; deletion is immediate and cannot be undone. Guests can erase their guest profile and sessions from Settings → Erase guest data, or by deleting the app.
            """
        ),
        LegalSection(
            heading: "Children",
            body: """
            fairLie is not directed to children under 13, and we do not knowingly collect personal information from them.
            """
        ),
        LegalSection(
            heading: "Contact",
            body: """
            Questions about this policy can be sent to \(AppConfig.supportEmail). We respond to privacy requests within 30 days.
            """
        )
    ]

    static let termsSections: [LegalSection] = [
        LegalSection(
            heading: "Acceptance",
            body: """
            By creating a fairLie account or using the app you agree to these Terms of Use. If you do not agree, do not use the app.
            """
        ),
        LegalSection(
            heading: "Your account",
            body: """
            You are responsible for keeping your sign-in credentials secure and for the activity that happens under your account. You must provide accurate profile information and be at least 13 years old to create an account.
            """
        ),
        LegalSection(
            heading: "Acceptable use",
            body: """
            You agree not to reverse engineer the app, interfere with its operation, post unlawful, harassing, or abusive content in the Clubhouse, or misrepresent your results in challenges and leaderboards. You can report, hide, or block posts; we review reports and may remove content or suspend accounts that break these rules.
            """
        ),
        LegalSection(
            heading: "Measurement accuracy",
            body: """
            fairLie reports sensor readings and derived coaching estimates. Carry distance, club speed, and attack angle are always estimates from the mat sensors; ball speed is measured only when the radar sensor is linked and is otherwise estimated. Simulated swings are made up for practice and are labeled as such. These figures are training aids, not certified instrumentation, and accuracy depends on correct setup and calibration. Do not rely on them for club fitting, competition scoring, or any purpose requiring certified measurement.
            """
        ),
        LegalSection(
            heading: "Safety",
            body: """
            Swinging a golf club carries risk of injury and property damage. Ensure you have clear space around you, follow the practice mat manufacturer's instructions, and stop if you feel pain. You use fairLie at your own risk.
            """
        ),
        LegalSection(
            heading: "Hardware",
            body: """
            The GolfMat practice mat and any other hardware are sold separately and covered by their own warranties. fairLie is provided as software and does not warrant third-party hardware.
            """
        ),
        LegalSection(
            heading: "Disclaimer and liability",
            body: """
            The app is provided "as is" without warranties of any kind. To the maximum extent permitted by law, fairLie is not liable for indirect, incidental, or consequential damages arising from your use of the app.
            """
        ),
        LegalSection(
            heading: "Changes and termination",
            body: """
            We may update these terms and will revise the effective date above when we do. You may stop using fairLie and delete your account at any time from Settings.
            """
        ),
        LegalSection(
            heading: "Contact",
            body: """
            Reach us at \(AppConfig.supportEmail).
            """
        )
    ]
}

struct LegalDocumentView: View {
    let document: LegalDocument
    var onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Done", action: onClose)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.greenDark)
                Spacer()
                Text(document.title).font(.headline)
                Spacer()
                Color.clear.frame(width: 44)
            }
            .padding(16)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Effective \(document.effectiveDate) · \(AppConfig.appName) \(AppConfig.version)")
                        .font(.caption)
                        .foregroundStyle(Theme.muted)

                    ForEach(document.sections) { section in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(section.heading)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(Theme.greenDark)
                            Text(section.body)
                                .font(.footnote)
                                .foregroundStyle(Theme.ink)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fairCard()
                    }

                    Link("Read the current version online", destination: document.hostedURL)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.greenDark)
                        .frame(maxWidth: .infinity)
                }
                .padding(18)
            }
        }
        .background(Theme.cream.ignoresSafeArea())
    }
}

/// Two-step confirmation so account deletion is deliberate but still reachable
/// without contacting support, as App Store Review requires.
struct DeleteAccountView: View {
    @EnvironmentObject private var auth: AuthStore
    var onClose: () -> Void

    @State private var confirmation = ""

    private var canDelete: Bool {
        confirmation.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() == "DELETE"
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Cancel", action: onClose)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.greenDark)
                Spacer()
                Text("Delete account").font(.headline)
                Spacer()
                Color.clear.frame(width: 54)
            }
            .padding(16)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("This cannot be undone")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Theme.danger)
                        Text("Deleting your account immediately removes your fairLie account, profile, saved sessions, Clubhouse posts, likes, RSVPs, and challenge progress from our servers and this device. Nothing is archived and nothing can be restored.")
                            .font(.footnote)
                            .foregroundStyle(Theme.ink)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.danger.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))

                    Button {
                        exportData()
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                            Text("Export my data first")
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.greenDark)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                    }
                    .fairCard()

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Type DELETE to confirm")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.muted)
                        TextField("DELETE", text: $confirmation)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .padding(12)
                            .background(Theme.paper, in: RoundedRectangle(cornerRadius: 12))
                    }

                    if let error = auth.errorMessage {
                        Text(error).font(.caption).foregroundStyle(Theme.danger)
                    }

                    Button {
                        Task {
                            if await auth.deleteAccount() { onClose() }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            if auth.isWorking { ProgressView().tint(.white) }
                            Text("Delete my account permanently")
                        }
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(canDelete ? Theme.danger : Theme.danger.opacity(0.35), in: Capsule())
                    }
                    .disabled(!canDelete || auth.isWorking)

                    if let url = AppConfig.supportMailtoURL {
                        Link("Contact support instead", destination: url)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.muted)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(18)
            }
        }
        .background(Theme.cream.ignoresSafeArea())
    }

    private func exportData() {
        let text = auth.exportAccountData()
        UIPasteboard.general.string = text
    }
}
