import SwiftUI

struct StrikeHeatmapView: View {
    let swing: SwingResult
    let armed: Bool
    let waiting: Bool

    private let labels = ["S0", "S1", "S2", "S3", "S4", "S5"]
    private let grid: [[Int]] = [[0, 1], [2, 3], [4, 5]]

    private var hasStrike: Bool { !swing.isZeroed && !waiting }
    private var maxPeak: Int { max(swing.fsrPeaks.max() ?? 1, 1) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("MAT CENTER")
                        .font(.caption2.weight(.semibold))
                        .tracking(1.2)
                        .foregroundStyle(Color(red: 0.33, green: 0.89, blue: 0.55).opacity(0.9))
                    Text("Strike pads")
                        .font(.subheadline.weight(.semibold))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(hasStrike ? "White = hit strength" : "Zeroed — waiting for strike")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("Low = faint · Solid = bright")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            if hasStrike {
                HStack(spacing: 12) {
                    GradeBadgeView(grade: swing.letterGrade, size: 56)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Hit grade")
                            .font(.subheadline.weight(.semibold))
                        Text("Quality \(swing.impactQuality) · A best → F weakest")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Text(
                    armed
                        ? "Calibrated. Pads stay dark at 0 until a full strike."
                        : "Connect GolfMat and press Calibrate / Zero to arm tracking."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 12))
            }

            padGrid

            Text(hasStrike ? swing.directionLabel : (armed ? "Waiting for strike" : "Not armed"))
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .foregroundStyle(hasStrike ? Color.primary : Color.secondary)
        }
        .padding(14)
        .background(Color(red: 0.06, green: 0.14, blue: 0.09), in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var padGrid: some View {
        VStack(spacing: 8) {
            ForEach(Array(grid.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 8) {
                    ForEach(row, id: \.self) { index in
                        padCell(index: index)
                    }
                }
            }
            HStack {
                Text("Heel").font(.caption2).foregroundStyle(.secondary)
                Spacer()
                Text("Toe").font(.caption2).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.13, green: 0.45, blue: 0.28).opacity(0.35),
                            Color(red: 0.02, green: 0.12, blue: 0.07),
                        ],
                        center: .center,
                        startRadius: 10,
                        endRadius: 180
                    )
                )
        )
    }

    private func padCell(index: Int) -> some View {
        let value = index < swing.fsrPeaks.count ? swing.fsrPeaks[index] : 0
        let isImpact = hasStrike && index == swing.impactZone
        let intensity = hasStrike ? CGFloat(value) / CGFloat(maxPeak) : 0
        let whiteOpacity = hasStrike
            ? max(0.12, min(1, intensity * intensity * 0.35 + intensity * 0.65))
            : 0

        return VStack {
            HStack {
                Text(labels[index])
                    .font(.caption2.weight(.semibold))
                Spacer()
                Text(hasStrike ? "\(value)" : "0")
                    .font(.subheadline.weight(.bold).monospacedDigit())
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 52)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.13, green: 0.55, blue: 0.3).opacity(0.35),
                    Color(red: 0.08, green: 0.35, blue: 0.2).opacity(0.55),
                    Color.white.opacity(whiteOpacity),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(
                    Color.white.opacity(isImpact ? 0.55 + whiteOpacity * 0.4 : 0.08 + whiteOpacity * 0.25),
                    lineWidth: isImpact ? 2 : 1
                )
        )
        .foregroundStyle(whiteOpacity > 0.55 ? Color(red: 0.06, green: 0.09, blue: 0.12) : Color(red: 0.9, green: 0.98, blue: 0.93))
    }
}
