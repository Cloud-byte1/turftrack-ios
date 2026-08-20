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
                            Text("Friends · leaderboards · your golf crew").font(.caption).foregroundStyle(.white.opacity(0.8))
                            Text("Open Clubhouse →").font(.caption.weight(.bold)).foregroundStyle(Theme.gold)
                        }
                        .padding(18)
                    }
                    .frame(height: 160)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                }

                HStack {
                    scoreChip("\(auth.user.strikeScore)", "Strike score")
                    scoreChip("\(auth.user.centerStrikePct)%", "Center")
                    scoreChip("\(auth.user.cleanContactPct)%", "Clean")
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

                puttingCard

                Text("Quick reads").font(.headline)
                insight("Fix this next: \(auth.user.fixThisNext.lowercased())", "Shows up most on your 7 iron", Theme.gold)
                insight("Active: \(FairLieCatalog.challenges[0].title)", "\(FairLieCatalog.challenges[0].progress) of \(FairLieCatalog.challenges[0].total) shots", Theme.green)
                insight("Best club: \(auth.user.bestClub)", "\(auth.user.bestClubScore) avg · trending up", Color.blue)

                HStack(spacing: 10) {
                    photo("Course prep", Theme.greenDeep)
                    photo("Practice Lab", Theme.green)
                    photo("Strike ref", Color(red: 0.15, green: 0.28, blue: 0.2))
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

    private var puttingCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PUTTING SNAPSHOT").eyebrowStyle()
            Text("\(auth.user.puttsMade)/\(auth.user.puttAttempts) made · \(auth.user.puttDistanceFt) ft")
                .font(.headline)
            Text("Line accuracy \(auth.user.lineAccuracy)% — tap Practice Lab to work it.")
                .font(.caption)
                .foregroundStyle(Theme.muted)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(white: 0.92))
                    Capsule().fill(Theme.green).frame(width: geo.size.width * CGFloat(auth.user.lineAccuracy) / 100)
                }
            }
            .frame(height: 8)
        }
        .padding(16)
        .fairCard()
        .onTapGesture { onOpenPractice() }
    }

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

    private func photo(_ label: String, _ color: Color) -> some View {
        Button(action: onOpenPractice) {
            ZStack(alignment: .bottom) {
                color
                Text(label).font(.caption.weight(.bold)).foregroundStyle(.white).padding(8)
            }
            .frame(height: 88)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }
}
