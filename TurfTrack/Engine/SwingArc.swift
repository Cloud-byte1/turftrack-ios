import Foundation

enum SwingArc {
    static func build(quality: Int, pathDeg: Double, attackDeg: Double, count: Int = 48) -> [SIMD3Point] {
        let topY = 1.25 + (Double(quality) / 100) * 0.4
        let finishY = 1.35 + (Double(quality) / 100) * 0.4
        let keys: [(Double, Double, Double, Double)] = [
            (0.00, -0.18, 0.06, 0.14),
            (0.08, -0.55, 0.28, 0.32),
            (0.18, -0.98, 0.72, 0.58),
            (0.28, -0.72, 1.25, 0.92),
            (0.38, -0.12, topY, 1.18),
            (0.46, -0.62, 1.15, 0.78),
            (0.52, -0.38, 0.48, 0.32),
            (0.58, 0.00, 0.00, 0.00),
            (0.66, 0.62, 0.28, -0.28),
            (0.78, 1.05, 0.85, -0.22),
            (0.90, 0.72, 1.35, 0.35),
            (1.00, 0.22, finishY, 0.95),
        ]
        let yaw = pathDeg * .pi / 180
        let pitch = attackDeg * .pi / 180 * 0.35
        return (0..<count).map { index in
            let phase = Double(index) / Double(max(1, count - 1))
            var seg = 1
            while seg < keys.count && keys[seg].0 < phase { seg += 1 }
            let a = keys[seg - 1]
            let b = keys[min(seg, keys.count - 1)]
            let span = (b.0 - a.0) == 0 ? 1 : (b.0 - a.0)
            let t = smoothstep((phase - a.0) / span)
            var x = a.1 + (b.1 - a.1) * t
            var y = a.2 + (b.2 - a.2) * t
            var z = a.3 + (b.3 - a.3) * t
            let xr = x * cos(yaw) - z * sin(yaw)
            let zr = x * sin(yaw) + z * cos(yaw)
            let yr = y * cos(pitch) - xr * sin(pitch)
            let xf = xr * cos(pitch) + y * sin(pitch)
            return SIMD3Point(x: xf, y: yr, z: zr)
        }
    }

    private static func smoothstep(_ t: Double) -> Double {
        let x = min(1, max(0, t))
        return x * x * (3 - 2 * x)
    }
}
