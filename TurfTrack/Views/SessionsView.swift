import SwiftUI

struct SessionsView: View {
    @EnvironmentObject private var store: FairLieStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("YOUR ACTIVITY").eyebrowStyle()
                Text("All sessions").font(.system(size: 28, weight: .bold))
                if let session = store.selectedSession {
                    sessionDetail(session)
                }
                ForEach(store.sessions) { session in
                    Button {
                        store.selectedSession = session
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle().fill(Color(red: 0.91, green: 0.96, blue: 0.93))
                                Image(systemName: "flag.fill").foregroundStyle(Theme.greenDark)
                            }
                            .frame(width: 44, height: 44)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(session.club) practice").font(.subheadline.weight(.bold)).foregroundStyle(Theme.ink)
                                Text("\(session.when) · \(session.swings) swings").font(.caption).foregroundStyle(Theme.muted)
                            }
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text(session.distance).font(.subheadline.weight(.bold)).foregroundStyle(Theme.ink)
                                Text("best carry").font(.caption2).foregroundStyle(Theme.muted)
                            }
                            Text("\(session.score)")
                                .font(.headline)
                                .foregroundStyle(session.tone == "great" ? Theme.greenDark : session.tone == "good" ? Color.orange : Theme.danger)
                                .frame(width: 40)
                            Image(systemName: "chevron.right").foregroundStyle(Theme.muted)
                        }
                        .padding(14)
                        .fairCard()
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(18)
        }
        .background(Theme.cream)
    }

    private func sessionDetail(_ session: PracticeSession) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading) {
                    Text("SESSION SUMMARY").eyebrowStyle()
                    Text("\(session.club) practice").font(.headline)
                    Text("\(session.when) · \(session.swings) swings").font(.caption).foregroundStyle(Theme.muted)
                }
                Spacer()
                Button("Close") { store.selectedSession = nil }
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.greenDark)
            }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                stat("\(session.score)", "avg score")
                stat(session.distance, "best carry")
                stat(session.avgBallMph.map(String.init) ?? "—", "avg ball")
                stat(session.bestBallMph.map(String.init) ?? "—", "best ball")
                stat(session.avgClubMph.map(String.init) ?? "—", "avg club")
                stat(session.avgSmash.map { String(format: "%.2f", $0) } ?? "—", "smash")
                stat("\(session.radarHitPct)%", "radar hits")
                stat(session.avgAttackDeg.map { String(format: "%.1f°", $0) } ?? "—", "attack")
                stat("\(session.centeredPct)%", "centered")
            }
            if !session.swingSnapshots.isEmpty {
                Text("RECENT STRIKES").eyebrowStyle()
                ForEach(session.swingSnapshots) { item in
                    HStack {
                        Text("#\(item.n)").font(.caption.weight(.bold))
                        Text("\(item.score) pts")
                        Text("\(item.carryYds) yds")
                        Text("\(item.ballMph) mph")
                        Spacer()
                        Text(item.radar ? "radar" : "no radar").foregroundStyle(Theme.muted)
                    }
                    .font(.caption)
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(18)
        .fairCard()
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.headline).foregroundStyle(Theme.greenDark)
            Text(label).font(.caption2).foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ProgressViewTab: View {
    @EnvironmentObject private var store: FairLieStore

    var body: some View {
        let avg = store.sessions.isEmpty ? 0 : store.sessions.map(\.score).reduce(0, +) / store.sessions.count
        let best = store.sessions.map(\.bestCarryYds).max() ?? 0
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("PROGRESS").eyebrowStyle()
                Text("Your strike trend").font(.system(size: 28, weight: .bold))
                HStack(spacing: 10) {
                    progressCard("\(avg)", "avg score")
                    progressCard("\(best)", "best yds")
                    progressCard("\(store.sessions.count)", "sessions")
                }
                VStack(alignment: .leading, spacing: 10) {
                    Text("SCORE HISTORY").eyebrowStyle()
                    HStack(alignment: .bottom, spacing: 8) {
                        ForEach(Array(store.sessions.prefix(8).reversed().enumerated()), id: \.offset) { _, session in
                            VStack {
                                Capsule()
                                    .fill(session.tone == "great" ? Theme.green : session.tone == "good" ? Theme.gold : Color.orange)
                                    .frame(width: 18, height: max(16, CGFloat(session.score)))
                                Text("\(session.score)").font(.system(size: 9, weight: .bold)).foregroundStyle(Theme.muted)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(height: 140, alignment: .bottom)
                }
                .padding(18)
                .fairCard()
                Text("Keep sessions going — each saved practice feeds this chart from live mat strikes and simulator swings.")
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
            }
            .padding(18)
        }
        .background(Theme.cream)
    }

    private func progressCard(_ value: String, _ label: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.title.weight(.heavy)).foregroundStyle(Theme.greenDark)
            Text(label).font(.caption).foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .fairCard()
    }
}
