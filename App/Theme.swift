import SwiftUI

enum Theme {
    static let bg = Color(red: 0.086, green: 0.098, blue: 0.145)
    static let card = Color(red: 0.137, green: 0.153, blue: 0.20)
    static let cream = Color(red: 1.0, green: 0.965, blue: 0.91)
    static let accent = Color(red: 0.969, green: 0.718, blue: 0.20)
    static let faded = cream.opacity(0.55)

    static func font(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

func hoursMinutes(_ interval: TimeInterval) -> String {
    let minutes = Int(interval / 60)
    return "\(minutes / 60)h \(String(format: "%02d", minutes % 60))m"
}
