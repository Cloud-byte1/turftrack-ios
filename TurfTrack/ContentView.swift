import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var ble: GolfMatBLEManager

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    ControlBar()
                    StrikeHeatmapView(
                        swing: ble.displaySwing,
                        armed: ble.armed,
                        waiting: ble.waitingForStrike
                    )
                    if let swing = ble.lastSwing, !swing.isZeroed {
                        GradeSummaryView(swing: swing)
                        PressureBreakdownView(swing: swing)
                    }
                    SessionHistoryView(swings: ble.history)
                }
                .padding(16)
            }
            .background(Color(red: 0.05, green: 0.09, blue: 0.07).ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        Text("TURFTRACK")
                            .font(.caption.weight(.bold))
                            .tracking(2)
                            .foregroundStyle(Color.turf)
                        Text("Mat strike lab")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(ble.statusTitle)
                    .font(.headline)
                Text(ble.statusDetail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Circle()
                .fill(ble.isConnected ? Color.turf : Color.secondary.opacity(0.4))
                .frame(width: 10, height: 10)
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

private extension Color {
    static let turf = Color(red: 0.33, green: 0.89, blue: 0.55)
}

#Preview {
    ContentView()
        .environmentObject(GolfMatBLEManager())
}
