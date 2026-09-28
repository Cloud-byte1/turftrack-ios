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
                            if !auth.user.bio.isEmpty {
                                Text(auth.user.bio).font(.caption)
                            }
                            Text([auth.user.city, auth.user.level].filter { !$0.isEmpty }.joined(separator: " · "))
                                .font(.caption).foregroundStyle(Theme.green)
                        }
                    }

                    HStack {
                        stat("\(store.sessions.count)", "Sessions")
                        stat("\(stats.totalSwings)", "Swings")
                        stat("\(auth.user.strikeXp)", "XP")
                    }

                    HStack {
                        Text("Level \(auth.user.levelNumber)").font(.caption.weight(.bold))
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(Color(red: 0.91, green: 0.96, blue: 0.93), in: Capsule())
                        Text(String(format: "HCP %.1f", auth.user.handicap)).font(.caption.weight(.bold))
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(Theme.cream, in: Capsule())
                    }

                    HStack {
                        tabChip("Activity", "activity")
                        tabChip("Stats", "stats")
                    }

                    if tab == "activity" {
                        if store.sessions.isEmpty {
                            Text("No saved sessions yet.").font(.caption).foregroundStyle(Theme.muted)
                        }
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
                    } else {
                        let insights = store.insights
                        HStack {
                            score(stats.avgScore.map(String.init) ?? "—", "Avg score")
                            score(insights.centeredPct.map { "\($0)%" } ?? "—", "Centered")
                            score(insights.consistency.map(String.init) ?? "—", "Consistency")
                        }
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            score(stats.bestScore.map(String.init) ?? "—", "Best score")
                            score(stats.bestCarryYds.map { "\($0)" } ?? "—", "Est. best yds")
                            score(stats.avgBallMph.map(String.init) ?? "—", "Avg ball*")
                        }
                        Text("* Ball speed is radar-measured when the radar was linked, otherwise estimated. Carry is always an estimate.")
                            .font(.caption2).foregroundStyle(Theme.muted)
                        if !auth.isGuest {
                            Text(store.cloud.statusLabel).font(.caption2).foregroundStyle(Theme.muted)
                        }
                    }
                }
                .padding(18)
            }
        }
        .background(Theme.cream.ignoresSafeArea())
    }

    private var stats: CloudProfileStats { CloudProfileStats(sessions: store.sessions) }

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
    @EnvironmentObject private var store: FairLieStore
    var onClose: () -> Void
    @State private var name = ""
    @State private var city = ""
    @State private var bio = ""
    @State private var handicap = 0.0
    @State private var legalDocument: LegalDocument?
    @State private var showDeleteAccount = false
    @State private var confirmEraseGuest = false
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

    @ViewBuilder
    private var accountSection: some View {
        if auth.isGuest {
            guestAccountSection
        } else {
            signedInAccountSection
        }
    }

    private var guestAccountSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Account").font(.headline)
            Text("You're using guest mode. Your profile and sessions are stored only on this iPhone and are never uploaded.")
                .font(.caption)
                .foregroundStyle(Theme.muted)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fairCard()

            Button("Create account or sign in") {
                onClose()
                auth.leaveGuest()
            }
            .font(.subheadline.weight(.bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Theme.green, in: Capsule())

            Button("Erase guest data") { confirmEraseGuest = true }
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Theme.danger)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .confirmationDialog("Erase your guest profile and all guest sessions from this iPhone?",
                                    isPresented: $confirmEraseGuest, titleVisibility: .visible) {
                    Button("Erase guest data", role: .destructive) {
                        auth.eraseGuestData()
                        store.eraseLocalSessions()
                        onClose()
                    }
                }

            versionFooter
        }
    }

    private var versionFooter: some View {
        Text("\(AppConfig.appName) · \(AppConfig.versionLabel)")
            .font(.caption2)
            .foregroundStyle(Theme.muted)
            .frame(maxWidth: .infinity)
    }

    private var signedInAccountSection: some View {
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

            versionFooter
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
