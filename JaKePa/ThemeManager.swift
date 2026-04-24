import SwiftUI

// MARK: - AppTheme

enum AppTheme: String, CaseIterable, Identifiable {
    case sunset, ocean, forest, sakura, galaxy

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .sunset:  "🌅"
        case .ocean:   "🌊"
        case .forest:  "🌿"
        case .sakura:  "🌸"
        case .galaxy:  "🌌"
        }
    }

    var displayName: String {
        switch self {
        case .sunset:  "サンセット"
        case .ocean:   "オーシャン"
        case .forest:  "フォレスト"
        case .sakura:  "さくら"
        case .galaxy:  "ギャラクシー"
        }
    }

    var primary: Color {
        switch self {
        case .sunset:  .orange
        case .ocean:   .blue
        case .forest:  .green
        case .sakura:  Color(red: 1.0, green: 0.42, blue: 0.54)
        case .galaxy:  .purple
        }
    }

    var secondary: Color {
        switch self {
        case .sunset:  .pink
        case .ocean:   .cyan
        case .forest:  Color(red: 0.4, green: 0.8, blue: 0.6)
        case .sakura:  .pink
        case .galaxy:  .indigo
        }
    }

    var logoGradient: [Color] {
        switch self {
        case .sunset:  [.orange, .pink, .purple]
        case .ocean:   [.blue, .cyan, .teal]
        case .forest:  [.green, Color(red: 0.4, green: 0.8, blue: 0.4), .teal]
        case .sakura:  [Color(red: 1.0, green: 0.42, blue: 0.54), .pink, .purple]
        case .galaxy:  [.purple, .indigo, Color(red: 0.17, green: 0.18, blue: 0.62)]
        }
    }

    var timerGradient: [Color] {
        switch self {
        case .sunset:  [.orange, .pink]
        case .ocean:   [.blue, .cyan]
        case .forest:  [.green, .mint]
        case .sakura:  [Color(red: 1.0, green: 0.42, blue: 0.54), .pink]
        case .galaxy:  [.purple, .indigo]
        }
    }
}

// MARK: - ThemeManager

class ThemeManager: ObservableObject {
    @Published var current: AppTheme {
        didSet { UserDefaults.standard.set(current.rawValue, forKey: "appTheme") }
    }

    init() {
        let raw = UserDefaults.standard.string(forKey: "appTheme") ?? ""
        current = AppTheme(rawValue: raw) ?? .sunset
    }
}
