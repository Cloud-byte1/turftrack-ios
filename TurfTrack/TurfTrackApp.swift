import SwiftUI

@main
struct TurfTrackApp: App {
    @StateObject private var store = FairLieStore()
    @StateObject private var auth = AuthStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(auth)
                .preferredColorScheme(.light)
        }
    }
}
