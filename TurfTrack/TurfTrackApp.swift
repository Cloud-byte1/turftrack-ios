import SwiftUI

@main
struct TurfTrackApp: App {
    @StateObject private var store = FairLieStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .preferredColorScheme(.light)
        }
    }
}
