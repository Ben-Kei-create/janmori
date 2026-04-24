import Foundation
import SwiftUI

// MARK: - Animal

struct Animal: Identifiable {
    let id: Int
    let name: String
    let emoji: String

    static let all: [Animal] = [
        Animal(id: 0,  name: "うさぎ",     emoji: "🐰"),
        Animal(id: 1,  name: "ねこ",       emoji: "🐱"),
        Animal(id: 2,  name: "いぬ",       emoji: "🐶"),
        Animal(id: 3,  name: "くま",       emoji: "🐻"),
        Animal(id: 4,  name: "きつね",     emoji: "🦊"),
        Animal(id: 5,  name: "ぱんだ",     emoji: "🐼"),
        Animal(id: 6,  name: "はむすたー", emoji: "🐹"),
        Animal(id: 7,  name: "ぺんぎん",   emoji: "🐧"),
        Animal(id: 8,  name: "かえる",     emoji: "🐸"),
        Animal(id: 9,  name: "こあら",     emoji: "🐨"),
        Animal(id: 10, name: "たぬき",     emoji: "🦝"),
        Animal(id: 11, name: "しか",       emoji: "🦌"),
        Animal(id: 12, name: "ひつじ",     emoji: "🐑"),
        Animal(id: 13, name: "ぞう",       emoji: "🐘"),
        Animal(id: 14, name: "らいおん",   emoji: "🦁"),
        Animal(id: 15, name: "とら",       emoji: "🐯"),
        Animal(id: 16, name: "さる",       emoji: "🐵"),
        Animal(id: 17, name: "うし",       emoji: "🐮"),
        Animal(id: 18, name: "ぶた",       emoji: "🐷"),
        Animal(id: 19, name: "かっぱ",     emoji: "🐢"),
    ]
}

// MARK: - Hand

enum Hand: String, CaseIterable, Identifiable {
    case rock     = "✊"
    case scissors = "✌️"
    case paper    = "🖐️"
    case random   = "🎲"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .rock:     "グー"
        case .scissors: "チョキ"
        case .paper:    "パー"
        case .random:   "おまかせ"
        }
    }

    func resolved() -> Hand {
        self == .random ? [.rock, .scissors, .paper].randomElement()! : self
    }
}

// MARK: - Player

struct Player: Identifiable {
    let id: UUID
    var displayName: String
    let animal: Animal
    var selectedHand: Hand?
    var nameChangeCount: Int = 0
    var wins: Int = 0

    var isReady: Bool { selectedHand != nil }
}

// MARK: - ChatMessage

struct ChatMessage: Identifiable {
    let id = UUID()
    let playerId: UUID
    let playerAnimalEmoji: String
    let playerName: String
    let text: String
}

// MARK: - Stamp

enum Stamp: String, CaseIterable, Identifiable {
    case like   = "👍"
    case heart  = "❤️"
    case laugh  = "😂"
    case fire   = "🔥"
    case clap   = "👏"
    case shock  = "😱"
    case devil  = "😈"
    case nice   = "✨"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .like:  "いいね！"
        case .heart: "すき"
        case .laugh: "ウケる"
        case .fire:  "熱い"
        case .clap:  "拍手"
        case .shock: "やばい"
        case .devil: "悪魔"
        case .nice:  "ナイス"
        }
    }
}

// MARK: - FloatingStamp

struct FloatingStamp: Identifiable {
    let id = UUID()
    let emoji: String
    let fromName: String
    let xPosition: CGFloat
}

// MARK: - Announcement

struct Announcement: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let isUrgent: Bool
}

// MARK: - Room Settings

struct RoomSettings {
    var durationMinutes: Int = 30
    var maxNameChanges: Int = 1
    var bubbleDurationSeconds: Int = 10
    var hostPlays: Bool = true
}

// MARK: - Game Phase

enum GamePhase {
    case lobby, playing, revealed
}
