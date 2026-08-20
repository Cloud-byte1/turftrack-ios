import SwiftUI

enum Theme {
    static let ink = Color(red: 0.09, green: 0.13, blue: 0.11)
    static let muted = Color(red: 0.41, green: 0.46, blue: 0.44)
    static let eyebrow = Color(red: 0.49, green: 0.54, blue: 0.51)
    static let green = Color(red: 0.11, green: 0.61, blue: 0.37)
    static let greenDark = Color(red: 0.07, green: 0.38, blue: 0.24)
    static let greenDeep = Color(red: 0.06, green: 0.36, blue: 0.22)
    static let cream = Color(red: 0.96, green: 0.96, blue: 0.96)
    static let paper = Color.white
    static let gold = Color(red: 0.96, green: 0.83, blue: 0.20)
    static let profile = Color(red: 0.91, green: 0.83, blue: 0.66)
    static let danger = Color(red: 0.84, green: 0.27, blue: 0.23)
    static let cardShadow = Color(red: 0.08, green: 0.22, blue: 0.15).opacity(0.08)
}

extension View {
    func fairCard() -> some View {
        self
            .background(Theme.paper, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: Theme.cardShadow, radius: 18, y: 8)
    }

    func eyebrowStyle() -> some View {
        self
            .font(.system(size: 11, weight: .bold))
            .tracking(1.6)
            .foregroundStyle(Theme.eyebrow)
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
