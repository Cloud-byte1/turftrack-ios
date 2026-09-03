import SwiftUI
import UIKit

struct ProfileView: View {
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var store: FairLieStore
    var onOpenSettings: () -> Void
    var onClose: () -> Void
    @State private var tab = "activity"

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("← Back", action: onClose).foregroundStyle(Theme.greenDark)
                Spacer()
                Text(auth.user.username).font(.subheadline.weight(.bold))
                Spacer()
                Button("Settings", action: onOpenSettings).foregroundStyle(Theme.green)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 14) {
                        Circle().fill(Theme.profile).frame(width: 72, height: 72)
                            .overlay(Text(auth.user.initials).font(.title.weight(.bold)))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(auth.user.name).font(.title3.weight(.bold))
                            Text(auth.user.username).font(.caption).foregroundStyle(Theme.muted)
                            Text(auth.user.bio).font(.caption)
                            Text("\(auth.user.city) · \(auth.user.level)").font(.caption).foregroundStyle(Theme.green)
                        }
                    }

                    HStack {
                        stat("\(auth.user.sessions)", "Sessions")
                        stat("128", "Followers")
                        stat("4", "Following")
                    }

                    HStack {
                        Text("A-\(auth.user.levelNumber)").font(.caption.weight(.bold))
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(Color(red: 0.91, green: 0.96, blue: 0.93), in: Capsule())
                        Text(String(format: "HCP %.1f", auth.user.handicap)).font(.caption.weight(.bold))
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(Theme.cream, in: Capsule())
                    }

                    HStack {
                        tabChip("Activity", "activity")
                        tabChip("Stats", "stats")
                        tabChip("Clips", "clips")
                    }

                    if tab == "activity" {
                        ForEach(store.sessions.prefix(5)) { session in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("\(session.club) practice").font(.subheadline.weight(.bold))
                                    Text("\(session.when) · \(session.swings) swings").font(.caption).foregroundStyle(Theme.muted)
                                }
                                Spacer()
                                Text("\(session.score)").font(.title3.weight(.bold)).foregroundStyle(Theme.greenDark)
                            }
                            .padding(14)
                            .fairCard()
                        }
                    } else if tab == "stats" {
                        HStack {
                            score("\(auth.user.strikeScore)", "Score")
                            score("\(auth.user.centerStrikePct)%", "Center")
                            score("\(auth.user.consistencyScore)", "Consistency")
                        }
                    } else {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            ForEach(0..<6, id: \.self) { index in
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(index % 2 == 0 ? Theme.greenDeep : Theme.green)
                                    .frame(height: 90)
                                    .overlay(Text("▶ \(8 + index)s").font(.caption.weight(.bold)).foregroundStyle(.white))
                            }
                        }
                    }
                }
                .padding(18)
            }
        }
        .background(Theme.cream.ignoresSafeArea())
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack {
            Text(value).font(.headline)
            Text(label).font(.caption2).foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity)
    }

    private func score(_ value: String, _ label: String) -> some View {
        VStack {
            Text(value).font(.title.weight(.heavy)).foregroundStyle(Theme.greenDark)
            Text(label).font(.caption).foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .fairCard()
    }

    private func tabChip(_ title: String, _ id: String) -> some View {
        Button(title) { tab = id }
            .font(.caption.weight(.bold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(tab == id ? .white : Color.clear, in: Capsule())
            .foregroundStyle(tab == id ? Theme.greenDark : Theme.muted)
            .background(Color(white: 0.94), in: Capsule())
    }
}

struct SettingsView: View {
    @EnvironmentObject private var auth: AuthStore
    var onClose: () -> Void
    @State private var name = ""
    @State private var city = ""
    @State private var bio = ""
    @State private var handicap = 12.4
    @State private var outdoor = true
    @State private var notifications = true
    @State private var legalDocument: LegalDocument?
    @State private var showDeleteAccount = false
    @State private var exportedData = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("← Back", action: onClose).foregroundStyle(Theme.greenDark)
                Spacer()
                Text("Settings").font(.headline)
                Spacer()
                Color.clear.frame(width: 48)
            }
            .padding(16)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    profileSection
                    preferencesSection
                    privacySection
                    supportSection
                    accountSection
                }
                .padding(18)
            }
        }
        .background(Theme.cream.ignoresSafeArea())
        .sheet(item: $legalDocument) { document in
            LegalDocumentView(document: document) { legalDocument = nil }
        }
        .sheet(isPresented: $showDeleteAccount) {
            DeleteAccountView(onClose: { showDeleteAccount = false })
                .environmentObject(auth)
        }
        .onAppear {
            name = auth.user.name
            city = auth.user.city
            bio = auth.user.bio
            handicap = auth.user.handicap
        }
    }

    private var profileSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Profile").font(.headline)
            field("Name", text: $name)
            field("City", text: $city)
            field("Bio", text: $bio)
            VStack(alignment: .leading) {
                HStack {
                    Text("Handicap")
                    Spacer()
                    Text(String(format: "%.1f", handicap)).foregroundStyle(Theme.greenDark)
                }
                Slider(value: $handicap, in: 0...36, step: 0.1).tint(Theme.green)
            }
            .padding(14)
            .fairCard()

            Button("Save profile") {
                auth.updateProfile(name: name, city: city, bio: bio, handicap: handicap)
                onClose()
            }
            .font(.subheadline.weight(.bold)).foregroundStyle(.white)
            .frame(maxWidth: .infinity).padding(.vertical, 14)
            .background(Theme.green, in: Capsule())
        }
    }

    private var preferencesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Preferences").font(.headline)
            toggle("Outdoor readability", "Higher contrast for range use", $outdoor)
            toggle("Notifications", "Challenges, streaks, and session recaps", $notifications)
        }
    }

    private var privacySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Privacy & data").font(.headline)
            VStack(spacing: 0) {
                row("Privacy Policy", icon: "hand.raised") { legalDocument = .privacy }
                divider
                row("Terms of Use", icon: "doc.text") { legalDocument = .terms }
                divider
                row(exportedData ? "Copied to clipboard" : "Export my data", icon: "square.and.arrow.down") {
                    UIPasteboard.general.string = auth.exportAccountData()
                    exportedData = true
                }
            }
            .fairCard()
        }
    }

    private var supportSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Support").font(.headline)
            VStack(spacing: 0) {
                linkRow("Contact support", icon: "envelope", url: AppConfig.supportMailtoURL)
                divider
                linkRow("Help centre", icon: "questionmark.circle", url: AppConfig.supportURL)
            }
            .fairCard()
        }
    }

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Account").font(.headline)
            VStack(alignment: .leading, spacing: 4) {
                Text("Signed in as \(auth.session?.email ?? "—")")
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
                Text(auth.session?.resolvedProvider == .apple
                     ? "Using Sign in with Apple"
                     : "Using email and password")
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fairCard()

            Button("Sign out") { auth.signOut() }
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Theme.greenDark)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .fairCard()

            Button("Delete account") { showDeleteAccount = true }
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Theme.danger)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)

            Text("\(AppConfig.appName) · \(AppConfig.versionLabel)")
                .font(.caption2)
                .foregroundStyle(Theme.muted)
                .frame(maxWidth: .infinity)
        }
    }

    private var divider: some View {
        Rectangle().frame(height: 1).foregroundStyle(Color(white: 0.92))
    }

    private func row(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon).frame(width: 22).foregroundStyle(Theme.greenDark)
                Text(title).font(.subheadline)
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(Theme.muted)
            }
            .padding(14)
        }
        .foregroundStyle(Theme.ink)
    }

    @ViewBuilder
    private func linkRow(_ title: String, icon: String, url: URL?) -> some View {
        if let url {
            Link(destination: url) {
                HStack(spacing: 12) {
                    Image(systemName: icon).frame(width: 22).foregroundStyle(Theme.greenDark)
                    Text(title).font(.subheadline)
                    Spacer()
                    Image(systemName: "arrow.up.right").font(.caption).foregroundStyle(Theme.muted)
                }
                .padding(14)
            }
            .foregroundStyle(Theme.ink)
        }
    }

    private func field(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.caption.weight(.semibold)).foregroundStyle(Theme.muted)
            TextField(label, text: text)
                .padding(12)
                .background(Theme.paper, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private func toggle(_ title: String, _ subtitle: String, _ value: Binding<Bool>) -> some View {
        Toggle(isOn: value) {
            VStack(alignment: .leading) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(subtitle).font(.caption).foregroundStyle(Theme.muted)
            }
        }
        .padding(14)
        .fairCard()
        .tint(Theme.green)
    }
}
