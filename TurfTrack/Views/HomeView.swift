import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: FairLieStore
    @EnvironmentObject private var auth: AuthStore
    var onOpenProfile: () -> Void
    var onOpenClub: () -> Void
    var onOpenPractice: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Button(action: onOpenProfile) {
                        HStack(spacing: 12) {
                            avatar
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Ready to dial in your strike?").font(.caption).foregroundStyle(Theme.muted)
                                Text(auth.user.name).font(.title3.weight(.bold)).foregroundStyle(Theme.ink)
                            }
                        }
                    }
                    Spacer()
                    Text(store.ble.isConnected ? "Mat on" : "Mat off")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(store.ble.isConnected ? Theme.greenDark : Theme.muted)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(store.ble.isConnected ? Color(red: 0.91, green: 0.96, blue: 0.93) : Color(white: 0.93), in: Capsule())
                }

                Button(action: onOpenClub) {
                    ZStack(alignment: .bottomLeading) {
                        LinearGradient(colors: [Theme.greenDeep, Color(red: 0.12, green: 0.32, blue: 0.22)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Clubhouse").font(.title2.weight(.bold)).foregroundStyle(.white)
                            Text(auth.isGuest ? "Create an account to join the leaderboard" : "Leaderboard · challenges · feed")
                                .font(.caption).foregroundStyle(.white.opacity(0.8))
                            Text("Open Clubhouse →").font(.caption.weight(.bold)).foregroundStyle(Theme.gold)
                        }
                        .padding(18)
                    }
                    .frame(height: 160)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                }

                HStack {
                    scoreChip(store.sessions.isEmpty ? "—" : "\(auth.user.strikeScore)", "Strike score")
                    scoreChip(insights.centeredPct.map { "\($0)%" } ?? "—", "Centered")
                    scoreChip("\(store.sessions.count)", "Sessions")
                }

                Button(store.activeSessionStarted ? "End Session" : "Start Session") {
                    if store.activeSessionStarted {
                        store.endSession()
                    } else {
                        store.startSession()
                        onOpenPractice()
                    }
                }
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(store.activeSessionStarted ? Theme.danger : Theme.green, in: Capsule())

                Text("Quick reads").font(.headline)
                if store.sessions.isEmpty {
                    insight("Save your first session", "Connect GolfMat, or try the swing simulator in Practice. Your reads build from real sessions.", Theme.green)
                } else {
                    if let fix = insights.fixThisNext {
                        insight("Fix this next: \(fix.lowercased())", "From your saved sessions", Theme.gold)
                    }
                    if let best = insights.bestClub {
                        insight("Best club: \(best.club)", "\(best.score) average strike score", Color.blue)
                    }
                    if let consistency = insights.consistency {
                        insight("Consistency \(consistency)", "How tightly your strike scores cluster", Theme.green)
                    }
                }
                if let challenge = store.cloud.challenges.first(where: { $0.joined == true && !$0.isComplete }) {
                    insight("Active: \(challenge.title)", "\(challenge.progress ?? 0) of \(challenge.target ?? 1)", Theme.green)
                }
            }
            .padding(18)
        }
        .background(Theme.cream)
    }

    private var avatar: some View {
        Circle()
            .fill(Theme.profile)
            .frame(width: 48, height: 48)
            .overlay(Text(auth.user.initials).font(.headline.weight(.bold)))
            .overlay(Circle().stroke(.white, lineWidth: 3))
    }

    private func scoreChip(_ value: String, _ label: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.title3.weight(.heavy)).foregroundStyle(Theme.greenDark)
            Text(label).font(.caption2).foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .fairCard()
    }

    private var insights: PracticeInsights { store.insights }

    private func insight(_ title: String, _ subtitle: String, _ accent: Color) -> some View {
        HStack(spacing: 12) {
            Capsule().fill(accent).frame(width: 4)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(subtitle).font(.caption).foregroundStyle(Theme.muted)
            }
            Spacer()
        }
        .padding(14)
        .fairCard()
    }
}
