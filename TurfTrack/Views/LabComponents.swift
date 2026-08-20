import SwiftUI

struct PressureHeatmapView: View {
    let swing: SwingResult
    var live: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("LIVE PRESSURE MAP").eyebrowStyle()
                    Text("Six-sensor strike heat").font(.subheadline.weight(.semibold))
                }
                Spacer()
                Text(live ? "● Live · waiting for strike" : "Latest strike")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(live ? Theme.green : Theme.muted)
            }
            HStack(spacing: 10) {
                Text("HEEL").font(.caption2.weight(.bold)).foregroundStyle(Theme.muted).rotationEffect(.degrees(-90))
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(0..<6, id: \.self) { index in
                        let value = index < swing.fsrPeaks.count ? swing.fsrPeaks[index] : 0
                        let intensity = min(1, Double(value) / 180)
                        let hue = 55.0 - intensity * 50
                        RoundedRectangle(cornerRadius: 12)
                            .fill(value == 0 ? Color(red: 0.87, green: 0.91, blue: 0.89) : Color(hue: hue / 360, saturation: 0.88, brightness: 0.93 - intensity * 0.25))
                            .overlay(alignment: .topLeading) {
                                Text("S\(index + 1)").font(.caption2.weight(.bold)).padding(8)
                            }
                            .overlay {
                                if index == swing.impactZone && !swing.isZeroed {
                                    RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.8), lineWidth: 2)
                                }
                            }
                            .frame(height: 72)
                    }
                }
                Text("TOE").font(.caption2.weight(.bold)).foregroundStyle(Theme.muted).rotationEffect(.degrees(90))
            }
            HStack {
                Text("Low pressure").font(.caption2).foregroundStyle(Theme.muted)
                Capsule().fill(LinearGradient(colors: [Color(red: 0.87, green: 0.91, blue: 0.89), Theme.gold, Color.orange], startPoint: .leading, endPoint: .trailing)).frame(height: 6)
                Text("Peak pressure").font(.caption2).foregroundStyle(Theme.muted)
            }
        }
    }
}

struct SwingPathView: View {
    let points: [SIMD3Point]
    let quality: Int

    var body: some View {
        Canvas { context, size in
            guard points.count > 1 else { return }
            let xs = points.map(\.x)
            let ys = points.map(\.y)
            let zs = points.map(\.z)
            let minX = (xs.min() ?? 0) - 0.15
            let maxX = (xs.max() ?? 1) + 0.15
            let minY = (ys.min() ?? 0) - 0.1
            let maxY = (ys.max() ?? 1) + 0.1
            func project(_ p: SIMD3Point) -> CGPoint {
                let px = (p.x - minX) / max(0.001, maxX - minX)
                let py = (p.y - minY) / max(0.001, maxY - minY)
                let depth = (p.z + 1.2) / 2.4
                return CGPoint(
                    x: 24 + (size.width - 48) * px + CGFloat(p.z) * 12,
                    y: size.height - 20 - (size.height - 40) * py - CGFloat(depth) * 8
                )
            }
            let impactIndex = Int(Double(points.count) * 0.58)
            var back = Path()
            var through = Path()
            for (index, point) in points.enumerated() {
                let mapped = project(point)
                if index <= impactIndex {
                    if index == 0 { back.move(to: mapped) } else { back.addLine(to: mapped) }
                } else {
                    if index == impactIndex + 1 { through.move(to: project(points[impactIndex])); through.addLine(to: mapped) }
                    else { through.addLine(to: mapped) }
                }
            }
            context.stroke(back, with: .color(quality >= 70 ? Theme.green : Theme.gold), lineWidth: 4)
            context.stroke(through, with: .color(.gray.opacity(0.45)), lineWidth: 3)
            if let last = points.last {
                let finish = project(last)
                context.fill(Path(ellipseIn: CGRect(x: finish.x - 5, y: finish.y - 5, width: 10, height: 10)), with: .color(Theme.gold))
            }
            if impactIndex < points.count {
                let impact = project(points[impactIndex])
                context.fill(Path(ellipseIn: CGRect(x: impact.x - 6, y: impact.y - 6, width: 12, height: 12)), with: .color(.white))
                context.stroke(Path(ellipseIn: CGRect(x: impact.x - 6, y: impact.y - 6, width: 12, height: 12)), with: .color(Theme.green), lineWidth: 2)
            }
        }
        .background(
            LinearGradient(colors: [Color(red: 0.93, green: 0.96, blue: 0.94), .white], startPoint: .top, endPoint: .bottom),
            in: RoundedRectangle(cornerRadius: 16)
        )
    }
}

struct ShotGraphic: View {
    var body: some View {
        ZStack {
            Path { path in
                path.move(to: CGPoint(x: 12, y: 95))
                path.addQuadCurve(to: CGPoint(x: 120, y: 28), control: CGPoint(x: 70, y: 0))
            }
            .stroke(Theme.gold, style: StrokeStyle(lineWidth: 3, dash: [6, 5]))
            Circle().fill(.white).frame(width: 13, height: 13).position(x: 16, y: 98)
            Circle().stroke(.white.opacity(0.4), lineWidth: 1).frame(width: 44, height: 44).position(x: 118, y: 88)
            Circle().fill(Theme.gold).frame(width: 6, height: 6).position(x: 118, y: 88)
        }
    }
}
