import SwiftUI

@main
struct TurfTrackApp: App {
    @StateObject private var ble = GolfMatBLEManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(ble)
                .preferredColorScheme(.dark)
        }
    }
}
