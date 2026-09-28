import SwiftUI

struct ClubhouseView: View {
    @EnvironmentObject private var store: FairLieStore
    @EnvironmentObject private var auth: AuthStore
    var onOpenProfile: () -> Void
    var onOpenSettings: () -> Void

    @State private var board = "friends"
    @State private var draft = ""
    @State private var posting = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Button(action: onOpenProfile) {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(Color(red: 0.91, green: 0.96, blue: 0.93))
                                .frame(width: 56, height: 56)
                                .overlay(Text(auth.user.initials).font(.title3.weight(.bold)).foregroundStyle(Theme.greenDark))
                                .overlay(Circle().stroke(Theme.green, lineWidth: 2))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(auth.user.name).font(.headline)
                                Text("\(auth.user.level) · Level \(auth.user.levelNumber)").font(.caption).foregroundStyle(Theme.green)
                                Text(String(format: "Handicap %.1f", auth.user.handicap)).font(.caption2).foregroundStyle(Theme.muted)
                            }
                        }
                    }
                    .foregroundStyle(Theme.ink)
                    Spacer()
                    VStack {
                        Text("XP").font(.caption2).foregroundStyle(Theme.muted)
                        Text("\(auth.user.strikeXp % 500)").font(.headline).foregroundStyle(Theme.gold)
                    }
                    .frame(width: 64, height: 64)
                    .background(Theme.paper, in: Circle())
                    .overlay(Circle().stroke(Theme.gold.opacity(0.4), lineWidth: 4))
                }

                GeometryReader { geo in
                    Capsule().fill(Color(white: 0.92)).overlay(alignment: .leading) {
                        Capsule().fill(Theme.gold).frame(width: geo.size.width * CGFloat(auth.user.strikeXp % 500) / 500)
                    }
                }
                .frame(height: 5)
                Text("\(auth.user.strikeXp) Strike XP to Ball Striker").font(.caption).foregroundStyle(Theme.muted)

                Text("My Bag").font(.headline)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 70))], spacing: 8) {
                    ForEach(auth.user.bag, id: \.self) { club in
                        Text(club)
                            .font(.caption.weight(.bold))
                            .multilineTextAlignment(.center)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity)
                            .background(Theme.paper, in: RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(white: 0.9)))
                    }
                }

                Text("Trophy Case").font(.headline)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(FairLieCatalog.badges) { badge in
                        VStack(spacing: 6) {
                            Text(badge.earned ? "🏆" : "🔒")
                            Text(badge.title).font(.caption2.weight(.semibold)).multilineTextAlignment(.center)
                                .foregroundStyle(badge.earned ? Theme.gold : Theme.muted)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity)
                        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(badge.earned ? Theme.gold : Color(white: 0.9)))
                        .opacity(badge.earned ? 1 : 0.65)
                    }
                }

                Text("Friends").font(.headline)
                VStack(spacing: 0) {
                    ForEach(FairLieCatalog.friends) { friend in
                        HStack {
                            Circle().fill(Color(white: 0.92)).frame(width: 40, height: 40)
                                .overlay(Text(String(friend.name.prefix(1))).font(.headline))
                            VStack(alignment: .leading) {
                                Text(friend.name).font(.subheadline.weight(.semibold))
                                Text("\(friend.username) · \(friend.city)").font(.caption).foregroundStyle(Theme.muted)
                            }
                            Spacer()
                            Text("\(friend.strikeScore)").font(.headline).foregroundStyle(Theme.greenDark)
                        }
                        .padding(.vertical, 10)
                        Divider()
                    }
                }
                .padding(.horizontal, 12)
                .fairCard()

                HStack {
                    Text("Leaderboard").font(.headline)
                    Spacer()
                    HStack(spacing: 6) {
                        scope("Friends", id: "friends")
                        scope("Clubhouse", id: "clubhouse")
                    }
                }
                if board == "clubhouse", !store.cloud.members.isEmpty {
                    cloudLeaderboard
                } else {
                    VStack(spacing: 8) {
                        ForEach(Array(FairLieCatalog.leaderboard(scope: board, selfName: auth.user.name).enumerated()), id: \.element.id) { index, entry in
                            HStack {
                                Text("\(index + 1)").font(.caption.weight(.bold)).frame(width: 18)
                                Text(entry.name).font(.subheadline.weight(.semibold))
                                if entry.isSelf {
                                    Text("YOU").font(.system(size: 9, weight: .heavy)).foregroundStyle(Theme.green)
                                        .padding(.horizontal, 6).padding(.vertical, 2)
                                        .background(Color(red: 0.91, green: 0.96, blue: 0.93), in: Capsule())
                                }
                                Spacer()
                                Text(entry.verified ? "verified" : "manual").font(.caption2).foregroundStyle(Theme.muted)
                                Text("\(entry.score)").font(.headline)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .padding(14)
                    .fairCard()
                }
                Text("Ranked by verified smart-mat sessions and skill bracket, not raw shot volume.")
                    .font(.caption2)
                    .foregroundStyle(Theme.muted)

                if !store.cloud.announcements.isEmpty {
                    Text("Announcements").font(.headline)
                    ForEach(store.cloud.announcements) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title).font(.subheadline.weight(.bold))
                            Text(item.body).font(.caption).foregroundStyle(Theme.muted)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(Theme.gold.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.gold.opacity(0.3)))
                    }
                }

                if store.cloud.isConfigured {
                    feedSection
                }

                Text("Clubhouse").font(.headline)
                group("Weekend Foursome", "4 members · Club champion board")
                group("Range Regulars", "12 members · Weekly consistency challenge")

                Button("Invite your foursome") {}
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Theme.green, in: Capsule())

                Text("Device").font(.headline)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("fairLie Smart Mat").font(.subheadline.weight(.bold))
                        Spacer()
                        Text(store.ble.isConnected ? "Connected" : "Offline")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(store.ble.isConnected ? Theme.green : Theme.muted)
                    }
                    Text("Firmware 1.2.0 · Last calibrated recently").font(.caption).foregroundStyle(Theme.muted)
                    Button("Recalibrate") { store.zeroMat() }
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.greenDark)
                }
                .padding(16)
                .fairCard()

                VStack(spacing: 0) {
                    link("My profile", action: onOpenProfile)
                    link("Settings & levels", action: onOpenSettings)
                    link("Friends", action: {})
                    link("Privacy & safety", action: {})
                }

                Text(store.cloud.statusLabel)
                    .font(.caption2)
                    .foregroundStyle(Theme.muted)
                    .frame(maxWidth: .infinity)
            }
            .padding(18)
        }
        .background(Theme.cream)
        .refreshable { await store.refreshCloud() }
    }

    private var cloudLeaderboard: some View {
        VStack(spacing: 8) {
            ForEach(Array(store.cloud.members.enumerated()), id: \.element.id) { index, member in
                HStack {
                    Text("\(member.rank ?? index + 1)").font(.caption.weight(.bold)).frame(width: 18)
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 6) {
                            Text(member.name).font(.subheadline.weight(.semibold))
                            if member.isYou == true {
                                Text("YOU").font(.system(size: 9, weight: .heavy)).foregroundStyle(Theme.green)
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(Color(red: 0.91, green: 0.96, blue: 0.93), in: Capsule())
                            }
                        }
                        Text("HCP \(member.handicap.map { String(format: "%.1f", $0) } ?? "—") · \(member.swings ?? 0) swings · \(member.streak ?? 0)d streak")
                            .font(.caption2)
                            .foregroundStyle(Theme.muted)
                    }
                    Spacer()
                    Text("\(member.score ?? 0)").font(.headline)
                }
                .padding(.vertical, 4)
            }
        }
        .padding(14)
        .fairCard()
    }

    private var feedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Clubhouse feed").font(.headline)
            HStack(spacing: 8) {
                TextField("Share a range win…", text: $draft)
                    .padding(12)
                    .background(Theme.paper, in: RoundedRectangle(cornerRadius: 12))
                Button(posting ? "…" : "Post") {
                    posting = true
                    Task {
                        if await store.cloud.post(author: auth.user.name, text: draft) { draft = "" }
                        posting = false
                    }
                }
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Theme.green, in: Capsule())
                .disabled(posting || draft.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            ForEach(store.cloud.feed) { post in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(post.author).font(.subheadline.weight(.bold))
                        Spacer()
                        Text(post.displayWhen).font(.caption2).foregroundStyle(Theme.muted)
                    }
                    Text(post.text).font(.subheadline)
                    Button {
                        Task { await store.cloud.like(post) }
                    } label: {
                        Label("\(post.likes ?? 0)", systemImage: "hand.thumbsup")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.greenDark)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fairCard()
            }
        }
    }

    private func scope(_ title: String, id: String) -> some View {
        Button(title) { board = id }
            .font(.caption.weight(.bold))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(board == id ? Color(red: 0.91, green: 0.96, blue: 0.93) : Theme.paper, in: Capsule())
            .foregroundStyle(board == id ? Theme.green : Theme.muted)
            .overlay(Capsule().stroke(board == id ? Theme.green : Color(white: 0.9)))
    }

    private func group(_ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.subheadline.weight(.bold))
            Text(subtitle).font(.caption).foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .fairCard()
    }

    private func link(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title).foregroundStyle(Theme.ink)
                Spacer()
                Text("›").font(.title2).foregroundStyle(Theme.muted)
            }
            .padding(.vertical, 14)
        }
        .overlay(alignment: .bottom) { Divider() }
    }
}

struct ChallengesView: View {
    @EnvironmentObject private var store: FairLieStore

    var body: some View {
        let active = FairLieCatalog.challenges.filter { $0.status == "active" }
        let upcoming = FairLieCatalog.challenges.filter { $0.status == "upcoming" }
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Challenges").font(.system(size: 28, weight: .bold))
                Text("Compete on skill, not just volume.").foregroundStyle(Theme.muted)

                if let first = active.first {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("YOUR TURN").font(.caption.weight(.bold)).foregroundStyle(Theme.gold)
                        Text(first.title).font(.headline)
                        Text("\(first.progress)/\(first.total) shots remaining").font(.caption).foregroundStyle(Theme.muted)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.gold.opacity(0.12), in: RoundedRectangle(cornerRadius: 18))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.gold.opacity(0.35)))
                }

                if !store.cloud.challenges.isEmpty {
                    Text("Clubhouse challenges").font(.headline)
                    ForEach(store.cloud.challenges) { challenge in
                        cloudChallengeRow(challenge)
                    }
                }

                Text("Active").font(.headline)
                ForEach(active) { challenge in
                    challengeRow(challenge)
                }
                if !upcoming.isEmpty {
                    Text("Upcoming").font(.headline)
                    ForEach(upcoming) { challenge in
                        challengeRow(challenge)
                    }
                }

                Text("Challenge types").font(.headline)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(FairLieCatalog.challengeTypes, id: \.self) { type in
                        Text(type)
                            .font(.caption.weight(.bold))
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                            .background(Theme.paper, in: RoundedRectangle(cornerRadius: 12))
                    }
                }

                Button("Create Challenge") {}
                    .font(.subheadline.weight(.bold)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(Theme.green, in: Capsule())
                Button("Join with Code") {}
                    .font(.subheadline.weight(.bold)).foregroundStyle(Theme.greenDark)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(Color(red: 0.91, green: 0.96, blue: 0.93), in: Capsule())

                VStack(alignment: .leading, spacing: 6) {
                    Text("Fair play").font(.headline)
                    Text("Ranked boards use verified mat sessions only. Skill brackets keep competition fair.")
                        .font(.caption).foregroundStyle(Theme.muted)
                }
                .padding(16)
                .fairCard()
            }
            .padding(18)
        }
        .background(Theme.cream)
        .refreshable { await store.refreshCloud() }
    }

    private func cloudChallengeRow(_ challenge: ClubChallenge) -> some View {
        let target = max(1, challenge.target ?? 1)
        let progress = min(target, challenge.progress ?? 0)
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(challenge.title).font(.subheadline.weight(.bold))
                Spacer()
                if challenge.isComplete {
                    Text("DONE").font(.caption2.weight(.heavy)).foregroundStyle(Theme.gold)
                } else if challenge.joined == true {
                    Text("JOINED").font(.caption2.weight(.heavy)).foregroundStyle(Theme.green)
                }
            }
            if let detail = challenge.detail {
                Text(detail).font(.caption).foregroundStyle(Theme.muted)
            }
            ProgressView(value: Double(progress), total: Double(target)).tint(Theme.green)
            HStack {
                Text("\(progress)/\(target)").font(.caption).foregroundStyle(Theme.muted)
                if let reward = challenge.reward {
                    Text("· \(reward)").font(.caption2).foregroundStyle(Theme.gold)
                }
                Spacer()
                if challenge.joined != true {
                    Button("Join") { Task { await store.cloud.join(challenge) } }
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14).padding(.vertical, 6)
                        .background(Theme.green, in: Capsule())
                } else if !challenge.isComplete {
                    Button("Log strike") { Task { await store.cloud.logProgress(challenge) } }
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.greenDark)
                        .padding(.horizontal, 14).padding(.vertical, 6)
                        .background(Color(red: 0.91, green: 0.96, blue: 0.93), in: Capsule())
                }
            }
        }
        .padding(14)
        .fairCard()
    }

    private func challengeRow(_ challenge: FairLieChallenge) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(challenge.title).font(.subheadline.weight(.bold))
                Spacer()
                Text(challenge.type).font(.caption2.weight(.bold)).foregroundStyle(Theme.green)
            }
            ProgressView(value: Double(challenge.progress), total: Double(challenge.total)).tint(Theme.green)
            HStack {
                Text("\(challenge.progress)/\(challenge.total)").font(.caption).foregroundStyle(Theme.muted)
                Spacer()
                Text("\(challenge.participants) golfers").font(.caption).foregroundStyle(Theme.muted)
            }
            if let stake = challenge.stake {
                Text(stake).font(.caption2).foregroundStyle(Theme.gold)
            }
        }
        .padding(14)
        .fairCard()
    }
}
