import SwiftUI

private let mint = Color(red: 0.91, green: 0.96, blue: 0.93)

struct ClubhouseView: View {
    @EnvironmentObject private var store: FairLieStore
    @EnvironmentObject private var auth: AuthStore
    @Environment(\.openURL) private var openURL
    var onOpenProfile: () -> Void
    var onOpenSettings: () -> Void

    enum Section: String, CaseIterable {
        case overview = "Overview"
        case board = "Leaderboard"
        case challenges = "Challenges"
        case feed = "Feed"
        case events = "Events"
    }

    @State private var section: Section = .overview
    @State private var draft = ""
    @State private var posting = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                if auth.isGuest {
                    GuestAccountPrompt(message: "The Clubhouse leaderboard, challenges, feed, and events need an account so your scores and posts belong to you.")
                    personalOverview
                } else {
                    statStrip
                    sectionPicker

                    switch section {
                    case .overview: overview
                    case .board: leaderboard
                    case .challenges: challengeList
                    case .feed: feedSection
                    case .events: eventList
                    }

                    Text(store.cloud.statusLabel)
                        .font(.caption2)
                        .foregroundStyle(Theme.muted)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(18)
        }
        .background(Theme.cream)
        .refreshable { await store.refreshCloud() }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Button(action: onOpenProfile) {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(mint)
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
                .accessibilityLabel("Open my profile")
                Spacer()
                VStack {
                    Text("XP").font(.caption2).foregroundStyle(Theme.muted)
                    Text("\(auth.user.xpIntoLevel)").font(.headline).foregroundStyle(Theme.gold)
                }
                .frame(width: 64, height: 64)
                .background(Theme.paper, in: Circle())
                .overlay(Circle().stroke(Theme.gold.opacity(0.4), lineWidth: 4))
                .accessibilityElement(children: .combine)
            }

            GeometryReader { geo in
                Capsule().fill(Color(white: 0.92)).overlay(alignment: .leading) {
                    Capsule().fill(Theme.gold).frame(width: geo.size.width * CGFloat(auth.user.xpIntoLevel) / 500)
                }
            }
            .frame(height: 5)
            Text("\(500 - auth.user.xpIntoLevel) XP to level \(auth.user.levelNumber + 1) · 10 XP per saved swing")
                .font(.caption).foregroundStyle(Theme.muted)
        }
    }

    private var statStrip: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("STRIKE LAB CLUBHOUSE").eyebrowStyle()
            Text("Range rats chasing pure contact").font(.subheadline.weight(.semibold))
            HStack {
                stripStat(store.cloud.members.count, "members")
                stripStat(store.cloud.challenges.count, "challenges")
                stripStat(store.cloud.feed.count, "posts")
                stripStat(store.cloud.events.count, "events")
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fairCard()
    }

    private func stripStat(_ value: Int, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text("\(value)").font(.title3.weight(.heavy)).foregroundStyle(Theme.greenDark)
            Text(label).font(.caption2).foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var sectionPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Section.allCases, id: \.self) { item in
                    Button(item.rawValue) { section = item }
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(section == item ? Theme.green : Theme.paper, in: Capsule())
                        .foregroundStyle(section == item ? .white : Theme.greenDark)
                        .overlay(Capsule().stroke(section == item ? Theme.green : Color(white: 0.88)))
                        .accessibilityAddTraits(section == item ? .isSelected : [])
                }
            }
        }
    }

    // MARK: - Overview

    private var overview: some View {
        VStack(alignment: .leading, spacing: 16) {
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

            if !store.cloud.events.isEmpty {
                HStack {
                    Text("Up next").font(.headline)
                    Spacer()
                    Button("All events") { section = .events }
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.green)
                }
                ForEach(store.cloud.events.prefix(2)) { event in
                    eventCard(event)
                }
            }

            personalOverview

            VStack(spacing: 0) {
                link("My profile", action: onOpenProfile)
                link("Settings", action: onOpenSettings)
            }
        }
    }

    /// Bag, trophies, and devices — everything here comes from this golfer's own data.
    private var personalOverview: some View {
        VStack(alignment: .leading, spacing: 16) {
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
                ForEach(FairLieCatalog.badges(for: store.sessions)) { badge in
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
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(badge.title), \(badge.earned ? "earned" : "locked")")
                }
            }

            Text("Devices").font(.headline)
            VStack(alignment: .leading, spacing: 8) {
                deviceRow("GolfMat", connected: store.ble.isConnected)
                deviceRow("Radar sensor", connected: store.radar.isConnected)
                Button("Open Practice to connect") { store.tab = .practice }
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.greenDark)
            }
            .padding(16)
            .fairCard()
        }
    }

    private func deviceRow(_ title: String, connected: Bool) -> some View {
        HStack {
            Text(title).font(.subheadline.weight(.bold))
            Spacer()
            Text(connected ? "Connected" : "Offline")
                .font(.caption.weight(.bold))
                .foregroundStyle(connected ? Theme.green : Theme.muted)
        }
    }

    // MARK: - Leaderboard

    private var leaderboard: some View {
        VStack(alignment: .leading, spacing: 12) {
            if store.cloud.members.isEmpty {
                Text("No golfers ranked yet. Save a GolfMat session to put your score on the board.")
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
            } else {
                cloudLeaderboard
            }
            Text("Ranked by average strike score across saved GolfMat sessions. Simulated swings are never uploaded.")
                .font(.caption2)
                .foregroundStyle(Theme.muted)

            ShareLink(item: AppConfig.marketingURL, message: Text("Practice with me on \(AppConfig.appName)")) {
                Text("Invite a friend")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Theme.green, in: Capsule())
            }
        }
    }

    private var cloudLeaderboard: some View {
        VStack(spacing: 8) {
            ForEach(Array(store.cloud.members.enumerated()), id: \.element.id) { index, member in
                HStack {
                    Text("\(index + 1)").font(.caption.weight(.bold)).frame(width: 18)
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 6) {
                            Text(member.name).font(.subheadline.weight(.semibold))
                            if store.cloud.isMe(member) { youTag }
                        }
                        Text("HCP \(member.handicap.map { String(format: "%.1f", $0) } ?? "—") · \(member.swings ?? 0) swings · \(member.streak ?? 0)d streak")
                            .font(.caption2)
                            .foregroundStyle(Theme.muted)
                    }
                    Spacer()
                    Text("\(member.score ?? 0)").font(.headline)
                }
                .padding(.vertical, 4)
                .accessibilityElement(children: .combine)
            }
        }
        .padding(14)
        .fairCard()
    }

    private var youTag: some View {
        Text("YOU").font(.system(size: 9, weight: .heavy)).foregroundStyle(Theme.green)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(mint, in: Capsule())
    }

    // MARK: - Challenges

    private var challengeList: some View {
        VStack(alignment: .leading, spacing: 12) {
            if store.cloud.challenges.isEmpty {
                Text("Clubhouse challenges appear here once the Clubhouse syncs. Pull down to refresh.")
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
            }
            ForEach(store.cloud.challenges) { challenge in
                ClubChallengeRow(challenge: challenge)
            }
            Button("More challenges in Play") { store.tab = .play }
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Theme.greenDark)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(mint, in: Capsule())
        }
    }

    // MARK: - Feed

    private var feedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if store.cloud.isConfigured {
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
                Text("Posts are public to the Clubhouse. Keep it friendly — no personal info. Use ••• to report, hide, or block.")
                    .font(.caption2)
                    .foregroundStyle(Theme.muted)
            }
            if store.cloud.visibleFeed.isEmpty {
                Text("No posts yet.").font(.caption).foregroundStyle(Theme.muted)
            }
            ForEach(store.cloud.visibleFeed) { post in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(post.author).font(.subheadline.weight(.bold))
                        Spacer()
                        Text(post.displayWhen).font(.caption2).foregroundStyle(Theme.muted)
                        Menu {
                            if store.cloud.isMine(post) {
                                Button("Delete post", role: .destructive) { Task { await store.cloud.delete(post) } }
                            } else {
                                Button("Report post", role: .destructive) { report(post) }
                                Button("Hide post") { store.cloud.hide(post) }
                                Button("Block \(post.author)", role: .destructive) { store.cloud.block(author: post.author) }
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .foregroundStyle(Theme.muted)
                                .frame(width: 28, height: 28)
                        }
                        .accessibilityLabel("Post options")
                    }
                    Text(post.text).font(.subheadline)
                    Button {
                        Task { await store.cloud.like(post) }
                    } label: {
                        Label("\(post.likes ?? 0)", systemImage: "hand.thumbsup")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.greenDark)
                    }
                    .accessibilityLabel("Like, \(post.likes ?? 0) likes")
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fairCard()
            }
        }
    }

    private func report(_ post: FeedPost) {
        store.cloud.hide(post)
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = AppConfig.supportEmail
        components.queryItems = [
            URLQueryItem(name: "subject", value: "Report Clubhouse post \(post.id)"),
            URLQueryItem(name: "body", value: "Author: \(post.author)\nPost: \(post.text)\n\nReason:"),
        ]
        if let url = components.url { openURL(url) }
    }

    // MARK: - Events

    private var eventList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Range calendar").font(.headline)
            if store.cloud.events.isEmpty {
                Text("No events scheduled yet.").font(.caption).foregroundStyle(Theme.muted)
            }
            ForEach(store.cloud.events) { event in
                eventCard(event)
            }
        }
    }

    private func eventCard(_ event: ClubEvent) -> some View {
        let going = event.rsvped == true
        return HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title).font(.subheadline.weight(.bold))
                if let detail = event.detail {
                    Text(detail).font(.caption).foregroundStyle(Theme.muted)
                }
                Text([event.whenLabel, event.place].compactMap { $0 }.joined(separator: " · "))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.green)
                Text("\(event.attendees ?? 0) going").font(.caption2).foregroundStyle(Theme.muted)
            }
            Spacer()
            Button(going ? "Going ✓" : "RSVP") {
                Task { await store.cloud.rsvp(event) }
            }
            .font(.caption.weight(.bold))
            .foregroundStyle(going ? Theme.greenDark : .white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(going ? mint : Theme.green, in: Capsule())
            .disabled(going)
        }
        .padding(14)
        .fairCard()
    }

    // MARK: - Shared

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

struct ClubChallengeRow: View {
    @EnvironmentObject private var store: FairLieStore
    let challenge: ClubChallenge

    var body: some View {
        let target = max(1, challenge.target ?? 1)
        let progress = min(target, challenge.progress ?? 0)
        VStack(alignment: .leading, spacing: 8) {
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
                        .background(mint, in: Capsule())
                }
            }
        }
        .padding(14)
        .fairCard()
    }
}

struct ChallengesView: View {
    @EnvironmentObject private var store: FairLieStore
    @EnvironmentObject private var auth: AuthStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Challenges").font(.system(size: 28, weight: .bold))
                Text("Compete on skill, not just volume.").foregroundStyle(Theme.muted)

                if auth.isGuest {
                    GuestAccountPrompt(message: "Clubhouse challenges track your progress against other golfers, so they need an account.")
                } else {
                    if let next = store.cloud.challenges.first(where: { $0.joined == true && !$0.isComplete }) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("YOUR TURN").font(.caption.weight(.bold)).foregroundStyle(Theme.gold)
                            Text(next.title).font(.headline)
                            Text("\(max(0, (next.target ?? 1) - (next.progress ?? 0))) to go").font(.caption).foregroundStyle(Theme.muted)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.gold.opacity(0.12), in: RoundedRectangle(cornerRadius: 18))
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.gold.opacity(0.35)))
                    }

                    if store.cloud.challenges.isEmpty {
                        Text("No Clubhouse challenges right now. Pull down to refresh.")
                            .font(.caption)
                            .foregroundStyle(Theme.muted)
                    }
                    ForEach(store.cloud.challenges) { challenge in
                        ClubChallengeRow(challenge: challenge)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Fair play").font(.headline)
                    Text("The leaderboard ranks average strike score from saved GolfMat sessions. Simulated swings never count.")
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
}

/// Shown in place of account-only features while using guest mode.
struct GuestAccountPrompt: View {
    @EnvironmentObject private var auth: AuthStore
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("GUEST MODE").eyebrowStyle()
            Text("Create a free account to join in").font(.headline)
            Text(message).font(.caption).foregroundStyle(Theme.muted)
            Text("Your guest sessions stay on this iPhone.").font(.caption2).foregroundStyle(Theme.muted)
            Button("Create account or sign in") { auth.leaveGuest() }
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Theme.green, in: Capsule())
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fairCard()
    }
}

