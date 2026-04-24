import Foundation
import SwiftUI
import Combine

@MainActor
class AppState: ObservableObject {
    @Published var players: [Player] = []
    @Published var chatMessages: [ChatMessage] = []
    @Published var floatingStamps: [FloatingStamp] = []
    @Published var phase: GamePhase = .lobby
    @Published var settings: RoomSettings = RoomSettings()
    @Published var timeRemaining: Int = 30 * 60
    @Published var roomCode: String = ""
    @Published var myPlayerId: UUID = UUID()
    @Published var announcement: Announcement? = nil
    @Published var isHost: Bool = false

    private var timerTask: Task<Void, Never>?

    init() { setupDemo() }

    // MARK: Demo Setup

    private func setupDemo() {
        roomCode = randomCode()
        let myId = UUID()
        myPlayerId = myId
        let myAnimal = Animal.all[0]
        players = [
            Player(id: myId, displayName: "\(myAnimal.name)さん", animal: myAnimal),
            Player(id: UUID(), displayName: "ねこさん",   animal: Animal.all[1], selectedHand: .rock),
            Player(id: UUID(), displayName: "いぬさん",   animal: Animal.all[2]),
            Player(id: UUID(), displayName: "くまさん",   animal: Animal.all[3], selectedHand: .scissors),
            Player(id: UUID(), displayName: "きつねさん", animal: Animal.all[4]),
        ]
        timeRemaining = settings.durationMinutes * 60
        chatMessages = [
            ChatMessage(playerId: players[1].id, playerAnimalEmoji: "🐱", playerName: "ねこさん", text: "よろしく〜！"),
            ChatMessage(playerId: players[3].id, playerAnimalEmoji: "🐻", playerName: "くまさん", text: "絶対勝つ！！"),
        ]
    }

    private func randomCode() -> String {
        let chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        return String((0..<5).map { _ in chars.randomElement()! })
    }

    var myPlayer: Player? {
        players.first { $0.id == myPlayerId }
    }

    // MARK: Timer

    func startTimer() {
        phase = .playing
        timerTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { break }
                if timeRemaining > 0 {
                    timeRemaining -= 1
                    checkAnnouncement()
                } else {
                    revealHands()
                    break
                }
            }
        }
    }

    func stopTimer() {
        timerTask?.cancel()
        timerTask = nil
    }

    private func checkAnnouncement() {
        let m = timeRemaining / 60
        let s = timeRemaining % 60
        switch (m, s) {
        case (10, 0): triggerAnnouncement("残り10分！", urgent: false)
        case (5, 0):  triggerAnnouncement("残り5分！", urgent: false)
        case (1, 0):  triggerAnnouncement("残り1分！", urgent: true)
        case (0, 30): triggerAnnouncement("残り30秒！！", urgent: true)
        default: break
        }
    }

    func triggerAnnouncement(_ text: String, urgent: Bool) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
            announcement = Announcement(text: text, isUrgent: urgent)
        }
        Task {
            try? await Task.sleep(for: .seconds(3))
            withAnimation(.easeOut) {
                self.announcement = nil
            }
        }
    }

    func revealHands() {
        stopTimer()
        for i in players.indices where players[i].selectedHand == .random {
            players[i].selectedHand = [.rock, .scissors, .paper].randomElement()
        }
        withAnimation(.spring()) { phase = .revealed }
    }

    // MARK: Actions

    func selectHand(_ hand: Hand) {
        guard let idx = players.firstIndex(where: { $0.id == myPlayerId }) else { return }
        withAnimation(.spring(response: 0.3)) {
            players[idx].selectedHand = hand
        }
    }

    func sendChat(_ text: String) {
        guard let me = myPlayer else { return }
        let msg = ChatMessage(
            playerId: me.id,
            playerAnimalEmoji: me.animal.emoji,
            playerName: me.displayName,
            text: text
        )
        withAnimation { chatMessages.append(msg) }

        let duration = TimeInterval(settings.bubbleDurationSeconds)
        Task {
            try? await Task.sleep(for: .seconds(duration))
            withAnimation { self.chatMessages.removeAll { $0.id == msg.id } }
        }
    }

    func sendStamp(_ stamp: Stamp) {
        guard let me = myPlayer else { return }
        let fs = FloatingStamp(
            emoji: stamp.rawValue,
            fromName: me.displayName,
            xPosition: CGFloat.random(in: 60...300)
        )
        withAnimation { floatingStamps.append(fs) }
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            withAnimation { self.floatingStamps.removeAll { $0.id == fs.id } }
        }
    }

    func sendLike() { sendStamp(.like) }

    func reset() {
        stopTimer()
        for i in players.indices { players[i].selectedHand = nil }
        phase = .lobby
        timeRemaining = settings.durationMinutes * 60
        announcement = nil
    }
}
