import SwiftUI

struct ControlBar: View {
    @EnvironmentObject private var ble: GolfMatBLEManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("LIVE HARDWARE")
                .font(.caption2.weight(.semibold))
                .tracking(1.2)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                if ble.isConnected {
                    Button("Disconnect") {
                        ble.disconnect()
                    }
                    .buttonStyle(SecondaryButtonStyle())

                    Button(ble.armed ? "Re-zero" : "Calibrate / Zero") {
                        ble.calibrateAndArm()
                    }
                    .buttonStyle(PrimaryButtonStyle(color: Color(red: 0.96, green: 0.72, blue: 0.2)))
                } else {
                    Button(ble.connectionState == .scanning ? "Scanning…" : "Connect GolfMat") {
                        ble.connect()
                    }
                    .buttonStyle(PrimaryButtonStyle(color: Color(red: 0.2, green: 0.7, blue: 0.45)))
                    .disabled(ble.connectionState == .scanning || ble.connectionState == .unsupported)
                }
            }

            Text(helpText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
    }

    private var helpText: String {
        if ble.isConnected {
            return ble.armed
                ? "Armed at 0. Pads stay dark until a full strike is detected."
                : "Connected. Press Calibrate / Zero before swinging."
        }
        return "Power the mat, enable Bluetooth, then Connect. iPhone uses BLE (not Web Bluetooth)."
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    var color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color(red: 0.06, green: 0.09, blue: 0.08))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(color.opacity(configuration.isPressed ? 0.75 : 1), in: Capsule())
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.white.opacity(configuration.isPressed ? 0.08 : 0.12), in: Capsule())
    }
}
