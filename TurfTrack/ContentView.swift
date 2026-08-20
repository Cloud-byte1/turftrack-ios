import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: FairLieStore
    @EnvironmentObject private var auth: AuthStore
    @State private var showProfile = false
    @State private var showSettings = false

    var body: some View {
        Group {
            if !auth.isSignedIn {
                LoginView()
            } else if auth.needsProfileSetup {
                ProfileSetupView()
            } else {
                mainApp
            }
        }
    }

    private var mainApp: some View {
        ZStack(alignment: .bottom) {
            Theme.cream.ignoresSafeArea()
            Group {
                switch store.tab {
                case .home:
                    HomeView(
                        onOpenProfile: { showProfile = true },
                        onOpenClub: { store.tab = .club },
                        onOpenPractice: { store.tab = .practice }
                    )
                case .practice:
                    LabView()
                case .play:
                    ChallengesView()
                case .progress:
                    SessionsView()
                case .club:
                    ClubhouseView(
                        onOpenProfile: { showProfile = true },
                        onOpenSettings: { showSettings = true }
                    )
                }
            }
            .padding(.bottom, 78)

            tabBar
        }
        .sheet(isPresented: $showProfile) {
            ProfileView(
                onOpenSettings: {
                    showProfile = false
                    showSettings = true
                },
                onClose: { showProfile = false }
            )
            .environmentObject(store)
            .environmentObject(auth)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(onClose: { showSettings = false })
                .environmentObject(auth)
        }
    }

    private var tabBar: some View {
        HStack {
            ForEach(FairLieStore.Tab.allCases, id: \.self) { item in
                Button {
                    store.tab = item
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: icon(for: item))
                            .font(.system(size: 18, weight: .semibold))
                        Text(item.rawValue)
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(store.tab == item ? Theme.green : Theme.muted)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 10)
        .padding(.bottom, 18)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) { Divider() }
    }

    private func icon(for tab: FairLieStore.Tab) -> String {
        switch tab {
        case .home: return "house.fill"
        case .practice: return "flag.fill"
        case .play: return "trophy.fill"
        case .progress: return "chart.bar.fill"
        case .club: return "person.3.fill"
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(FairLieStore())
        .environmentObject(AuthStore())
}
