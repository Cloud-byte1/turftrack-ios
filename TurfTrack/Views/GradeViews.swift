import SwiftUI

struct GradeBadgeView: View {
    let grade: LetterGrade
    var size: CGFloat = 48

    var body: some View {
        Text(grade.rawValue)
            .font(.system(size: size * 0.55, weight: .black, design: .rounded))
            .foregroundStyle(Color(hex: grade.colorHex))
            .frame(width: size, height: size)
            .background(Color(hex: grade.colorHex).opacity(0.15), in: RoundedRectangle(cornerRadius: size * 0.28))
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.28)
                    .stroke(Color(hex: grade.colorHex).opacity(0.45), lineWidth: 1)
            )
    }
}

struct GradeSummaryView: View {
    let swing: SwingResult

    var body: some View {
        HStack(spacing: 14) {
            GradeBadgeView(grade: swing.letterGrade, size: 64)
            VStack(alignment: .leading, spacing: 6) {
                metric("Impact", "\(swing.impactQuality) / 100")
                metric("Distance", "\(swing.estimatedDistanceM) m")
                metric("Direction", swing.directionLabel)
            }
            Spacer()
        }
        .padding(14)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
    }

    private func metric(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Text(value)
                .font(.subheadline.weight(.semibold).monospacedDigit())
        }
    }
}

struct PressureBreakdownView: View {
    let swing: SwingResult

    private var zones: [(String, Int, Color)] {
        [
            ("Heel", swing.heelPressurePct, .blue),
            ("Center", swing.centerPressurePct, Color(red: 0.13, green: 0.77, blue: 0.37)),
            ("Toe", swing.toePressurePct, .orange),
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("PRESSURE DISTRIBUTION")
                .font(.caption2.weight(.semibold))
                .tracking(1.2)
                .foregroundStyle(.secondary)

            ForEach(zones, id: \.0) { label, value, color in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(label).font(.subheadline).foregroundStyle(.secondary)
                        Spacer()
                        Text("\(value)%")
                            .font(.subheadline.weight(.bold).monospacedDigit())
                    }
                    GeometryReader { geo in
                        Capsule()
                            .fill(Color.white.opacity(0.08))
                            .overlay(alignment: .leading) {
                                Capsule()
                                    .fill(color)
                                    .frame(width: geo.size.width * CGFloat(min(max(value, 0), 100)) / 100)
                            }
                    }
                    .frame(height: 8)
                }
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
    }
}

struct SessionHistoryView: View {
    let swings: [SwingResult]

    var body: some View {
        let recent = Array(swings.suffix(5))
        if !recent.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("SESSION HISTORY")
                    .font(.caption2.weight(.semibold))
                    .tracking(1.2)
                    .foregroundStyle(.secondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(recent.enumerated()), id: \.element.id) { index, swing in
                            VStack(spacing: 4) {
                                Text(swing.letterGrade.rawValue)
                                    .font(.title2.weight(.black))
                                    .foregroundStyle(Color(hex: swing.letterGrade.colorHex))
                                Text("\(swing.impactQuality)")
                                    .font(.caption2.monospacedDigit())
                                    .foregroundStyle(.secondary)
                                Text(swing.directionLabel)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                    .lineLimit(1)
                            }
                            .frame(width: 72)
                            .padding(.vertical, 10)
                            .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(hex: swing.letterGrade.colorHex).opacity(0.5), lineWidth: 1)
                            )
                            .opacity(0.55 + Double(index + 1) / Double(recent.count) * 0.45)
                        }
                    }
                }
            }
            .padding(14)
            .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
        }
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}
