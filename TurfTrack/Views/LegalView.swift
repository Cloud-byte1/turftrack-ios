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

    var effectiveDate: String { "September 3, 2026" }

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
            fairLie collects the profile details you enter — name, username, email address, home city, handicap, skill level, club bag, and bio — plus the swing and strike data produced when you practice. Swing data includes impact quality, strike location on the mat, club and ball speed, attack angle, club path, and the timestamp of each shot.
            """
        ),
        LegalSection(
            heading: "How your data is stored",
            body: """
            Your account and practice history are stored locally on your iPhone using the operating system's standard app storage. fairLie does not upload your profile or swing history to a fairLie server, and we do not sell or share it with data brokers or advertisers.
            """
        ),
        LegalSection(
            heading: "Bluetooth",
            body: """
            fairLie uses Bluetooth solely to discover and connect to your GolfMat practice mat and to receive strike measurements from it. Bluetooth is never used to determine your location, to build an advertising profile, or to scan for nearby people or beacons.
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
            You can edit your profile at any time from Settings. You can export a copy of your account record from Settings → Privacy & data. You can permanently delete your account and all associated practice data from Settings → Delete account; deletion is immediate and cannot be undone.
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
            You agree not to reverse engineer the app, interfere with its operation, upload unlawful or abusive content to social features such as the Clubhouse, or misrepresent your results in challenges and leaderboards.
            """
        ),
        LegalSection(
            heading: "Measurement accuracy",
            body: """
            fairLie reports sensor measurements and derived coaching estimates from your practice mat. These figures are training aids, not certified instrumentation, and accuracy depends on correct mat setup and calibration. Do not rely on them for club fitting, competition scoring, or any purpose requiring certified measurement.
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
                        Text("Deleting your account immediately removes your profile, saved sessions, swing history, badges, and challenge progress from this device. Nothing is archived and nothing can be restored.")
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

                    Button("Delete my account permanently") {
                        auth.deleteAccount()
                        onClose()
                    }
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(canDelete ? Theme.danger : Theme.danger.opacity(0.35), in: Capsule())
                    .disabled(!canDelete)

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
