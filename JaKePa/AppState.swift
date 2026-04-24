import Foundation
import SwiftUI
import FirebaseCore

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
    @Published var namesLocked: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var roundNumber: Int = 1
    @Published var showConfetti: Bool = false

    private var service: FirebaseService?
    private var timerTask: Task<Void, Never>?

    // Stats tracking for current session
    private var sessionRocks = 0
    private var sessionScissors = 0
    private var sessionPapers = 0
    private var sessionWins = 0

    // true when Firebase is available (GoogleService-Info.plist is real)
    var isFirebaseMode: Bool { FirebaseApp.app() != nil }

    init() { setupDemo() }

    // MARK: - Demo

    private func setupDemo() {
        roomCode = randomCode()
        let myId   = UUID()
        myPlayerId = myId
        let me     = Animal.all[0]
        players = [
            Player(id: myId,    displayName: "\(me.name)さん",    animal: me),
            Player(id: UUID(),  displayName: "ねこさん",           animal: Animal.all[1], selectedHand: .rock),
            Player(id: UUID(),  displayName: "いぬさん",           animal: Animal.all[2]),
            Player(id: UUID(),  displayName: "くまさん",           animal: Animal.all[3], selectedHand: .scissors),
            Player(id: UUID(),  displayName: "きつねさん",         animal: Animal.all[4]),
        ]
        timeRemaining = settings.durationMinutes * 60
        chatMessages = [
            ChatMessage(playerId: players[1].id, playerAnimalEmoji: "🐱", playerName: "ねこさん", text: "よろしく〜！"),
            ChatMessage(playerId: players[3].id, playerAnimalEmoji: "🐻", playerName: "くまさん", text: "絶対勝つ！！"),
        ]
    }

    var myPlayer: Player? { players.first { $0.id == myPlayerId } }

    // MARK: - Room Management

    func createRoom() async {
        isLoading = true
        defer { isLoading = false }

        guard isFirebaseMode else {
            setupDemo()
            return
        }

        do {
            let svc = FirebaseService()
            try await svc.signIn()
            let code = randomCode()
            try await svc.createRoom(code: code, settings: settings)

            service   = svc
            roomCode  = code

            // Add host as first player
            let taken  = (try? await svc.getTakenAnimalIds(code: code)) ?? []
            let animal = Animal.all.first { !taken.contains($0.id) } ?? Animal.all[0]
            let pKey   = svc.playerKey
            myPlayerId = UUID(uuidString: pKey) ?? UUID()
            try await svc.addPlayer(displayName: "\(animal.name)さん", animalId: animal.id)
            timeRemaining = settings.durationMinutes * 60

            startObserving(svc)
        } catch {
            errorMessage = "接続エラー。デモモードで起動します"
            setupDemo()
        }
    }

    func joinRoom(code: String) async -> Bool {
        isLoading = true
        defer { isLoading = false }

        guard isFirebaseMode else {
            setupDemo()
            return true
        }

        do {
            let svc = FirebaseService()
            try await svc.signIn()

            guard try await svc.roomExists(code: code.uppercased()) else {
                errorMessage = "ルームが見つかりません"
                return false
            }

            svc.setRoomRef(code: code.uppercased())
            service   = svc
            roomCode  = code.uppercased()

            let taken  = (try? await svc.getTakenAnimalIds(code: roomCode)) ?? []
            let animal = Animal.all.first { !taken.contains($0.id) } ?? Animal.all[0]
            let pKey   = svc.playerKey
            myPlayerId = UUID(uuidString: pKey) ?? UUID()
            try await svc.addPlayer(displayName: "\(animal.name)さん", animalId: animal.id)

            startObserving(svc)
            return true
        } catch {
            errorMessage = "参加に失敗しました"
            return false
        }
    }

    // MARK: - Firebase Observers

    private func startObserving(_ svc: FirebaseService) {
        svc.observeRoom { [weak self] snap in
            guard let self else { return }
            let prevPhase = self.phase
            self.settings  = snap.settings
            self.namesLocked = snap.namesLocked

            // Phase transitions
            switch snap.phase {
            case .playing where prevPhase == .lobby:
                self.phase = .playing
                self.timeRemaining = snap.settings.durationMinutes * 60
                self.startLocalTimer()
            case .playing where prevPhase == .revealed:
                // Rematch after draw: host already wrote to Firebase, all clients react here
                self.roundNumber += 1
                withAnimation(.spring()) { self.phase = .playing }
                self.timeRemaining = snap.settings.durationMinutes * 60
                self.startLocalTimer()
            case .revealed where prevPhase != .revealed:
                self.stopTimer()
                HapticManager.handsRevealed()
                withAnimation(.spring()) { self.phase = .revealed }
                self.checkDrawAndScore()
            case .lobby where prevPhase != .lobby:
                self.stopTimer()
                self.phase = .lobby
                self.timeRemaining = snap.settings.durationMinutes * 60
            default:
                break
            }
        }

        svc.observePlayers { [weak self] snapshots in
            guard let self else { return }
            let myKey = svc.playerKey
            withAnimation {
                self.players = snapshots.compactMap { snap in
                    guard let animal = Animal.all.first(where: { $0.id == snap.animalId }) else { return nil }
                    let pid = UUID(uuidString: snap.key) ?? UUID()
                    return Player(
                        id: pid,
                        displayName: snap.displayName,
                        animal: animal,
                        selectedHand: snap.hand,
                        nameChangeCount: snap.nameChangeCount
                    )
                }
                if let pKey = UUID(uuidString: myKey) {
                    self.myPlayerId = pKey
                }
            }
        }

        svc.observeChat { [weak self] msg, _ in
            guard let self else { return }
            withAnimation { self.chatMessages.append(msg) }
            let dur = TimeInterval(self.settings.bubbleDurationSeconds)
            Task {
                try? await Task.sleep(for: .seconds(dur))
                withAnimation { self.chatMessages.removeAll { $0.id == msg.id } }
            }
        }

        svc.observeStamps { [weak self] stamp in
            guard let self else { return }
            withAnimation { self.floatingStamps.append(stamp) }
            Task {
                try? await Task.sleep(for: .seconds(2.5))
                withAnimation { self.floatingStamps.removeAll { $0.id == stamp.id } }
            }
        }
    }

    // MARK: - Timer

    private func startLocalTimer() {
        stopTimer()
        timerTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { break }
                if timeRemaining > 0 {
                    timeRemaining -= 1
                    checkAnnouncement()
                } else {
                    if isHost { await hostRevealHands() }
                    break
                }
            }
        }
    }

    // Called by host tapping "スタート！"
    func startTimer() {
        if isFirebaseMode, let svc = service {
            Task { try? await svc.startTimer() }
            // Phase transition comes back via observer
        } else {
            phase = .playing
            startLocalTimer()
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
        case (10, 0): triggerAnnouncement("残り10分！",   urgent: false)
        case (5, 0):  triggerAnnouncement("残り5分！",    urgent: false)
        case (1, 0):  triggerAnnouncement("残り1分！",    urgent: true)
        case (0, 30): triggerAnnouncement("残り30秒！！", urgent: true)
        default: break
        }
    }

    func triggerAnnouncement(_ text: String, urgent: Bool) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
            announcement = Announcement(text: text, isUrgent: urgent)
        }
        HapticManager.announcement()
        Task {
            try? await Task.sleep(for: .seconds(3))
            withAnimation(.easeOut) { self.announcement = nil }
        }
    }

    // MARK: - Game Actions

    func selectHand(_ hand: Hand) {
        guard let idx = players.firstIndex(where: { $0.id == myPlayerId }) else { return }
        withAnimation(.spring(response: 0.3)) { players[idx].selectedHand = hand }
        HapticManager.handSelected()
        if isFirebaseMode, let svc = service {
            Task { try? await svc.selectHand(hand) }
        }
    }

    func sendChat(_ text: String) {
        guard let me = myPlayer else { return }
        if isFirebaseMode, let svc = service {
            Task { try? await svc.sendChat(text: text, playerName: me.displayName, playerEmoji: me.animal.emoji) }
        } else {
            let msg = ChatMessage(playerId: me.id, playerAnimalEmoji: me.animal.emoji, playerName: me.displayName, text: text)
            withAnimation { chatMessages.append(msg) }
            let dur = TimeInterval(settings.bubbleDurationSeconds)
            Task {
                try? await Task.sleep(for: .seconds(dur))
                withAnimation { self.chatMessages.removeAll { $0.id == msg.id } }
            }
        }
    }

    func sendStamp(_ stamp: Stamp) {
        guard let me = myPlayer else { return }
        HapticManager.stampSent()
        if isFirebaseMode, let svc = service {
            Task { try? await svc.sendStamp(emoji: stamp.rawValue, fromName: me.displayName) }
        } else {
            let fs = FloatingStamp(emoji: stamp.rawValue, fromName: me.displayName, xPosition: CGFloat.random(in: 60...300))
            withAnimation { floatingStamps.append(fs) }
            Task {
                try? await Task.sleep(for: .seconds(2.5))
                withAnimation { self.floatingStamps.removeAll { $0.id == fs.id } }
            }
        }
    }

    func sendLike() { sendStamp(.like) }

    // MARK: - Host Actions

    private func hostRevealHands() async {
        if isFirebaseMode, let svc = service {
            try? await svc.revealHands()
        } else {
            revealHandsLocal()
        }
    }

    func revealHands() {
        if isFirebaseMode, let svc = service {
            Task { try? await svc.revealHands() }
        } else {
            revealHandsLocal()
        }
    }

    private func revealHandsLocal() {
        stopTimer()
        for i in players.indices where players[i].selectedHand == .random {
            players[i].selectedHand = [.rock, .scissors, .paper].randomElement()
        }
        HapticManager.handsRevealed()
        withAnimation(.spring()) { phase = .revealed }
        checkDrawAndScore()
    }

    // MARK: - Draw / Score

    private func isDrawRound() -> Bool {
        let hands = Set(players.compactMap(\.selectedHand))
        return hands.count == 1 || hands.count == 3
    }

    private func winningHand() -> Hand? {
        let hands = Set(players.compactMap(\.selectedHand))
        guard hands.count == 2 else { return nil }
        if hands == [.rock, .scissors] { return .rock }
        if hands == [.scissors, .paper] { return .scissors }
        if hands == [.paper, .rock]     { return .paper }
        return nil
    }

    func checkDrawAndScore() {
        if isDrawRound() {
            HapticManager.drawDetected()
            triggerAnnouncement("あいこ！🤝", urgent: true)
            if settings.rematchOnDraw {
                if isFirebaseMode {
                    // Only host writes rematch to Firebase; all clients react via observer
                    if isHost, let svc = service {
                        Task {
                            try? await Task.sleep(for: .seconds(3.5))
                            try? await svc.rematchRound()
                        }
                    }
                } else {
                    // Demo mode: handle locally
                    Task {
                        try? await Task.sleep(for: .seconds(3.5))
                        self.roundNumber += 1
                        for i in self.players.indices { self.players[i].selectedHand = nil }
                        withAnimation(.spring()) { self.phase = .playing }
                    }
                }
            }
        } else {
            // Update scores
            if let winner = winningHand() {
                for i in players.indices where players[i].selectedHand == winner {
                    players[i].wins += 1
                }
                // Track my stats
                if let me = myPlayer {
                    switch me.selectedHand {
                    case .rock:     sessionRocks += 1
                    case .scissors: sessionScissors += 1
                    case .paper:    sessionPapers += 1
                    default: break
                    }
                    if me.selectedHand == winner { sessionWins += 1 }
                }
            }
            withAnimation(.spring(response: 0.3)) { showConfetti = true }
            Task {
                try? await Task.sleep(for: .seconds(2))
                showConfetti = false
            }
        }
    }

    func saveSessionStats() {
        guard let me = myPlayer else { return }
        let record = SessionRecord(
            id: UUID(),
            date: Date(),
            roomCode: roomCode,
            playerName: me.displayName,
            animalEmoji: me.animal.emoji,
            totalWins: sessionWins,
            totalRounds: roundNumber,
            rockCount: sessionRocks,
            scissorsCount: sessionScissors,
            paperCount: sessionPapers
        )
        StatsManager.shared.save(record)
    }

    func lockNames() {
        namesLocked = true
        triggerAnnouncement("もう変えられないよ🔒", urgent: false)
        if isFirebaseMode, let svc = service {
            Task { try? await svc.lockNames() }
        }
    }

    // MARK: - Name Change

    /// Returns error message if invalid, nil on success
    func changeName(_ newName: String) -> String? {
        switch NameFilter.validate(newName) {
        case .failure(let reason):
            return reason
        case .success(let clean):
            guard let idx = players.firstIndex(where: { $0.id == myPlayerId }) else { return nil }
            let count = players[idx].nameChangeCount
            if settings.maxNameChanges > 0 && count >= settings.maxNameChanges {
                return "名前の変更回数が上限に達しました"
            }
            players[idx].displayName = clean
            players[idx].nameChangeCount += 1
            if isFirebaseMode, let svc = service {
                Task { try? await svc.updateName(clean) }
            }
            return nil
        }
    }

    // MARK: - Reset

    func reset() {
        stopTimer()
        service?.removeObservers()
        service = nil
        players = []
        chatMessages = []
        floatingStamps = []
        namesLocked = false
        phase = .lobby
        timeRemaining = settings.durationMinutes * 60
        announcement = nil
        roomCode = ""
        roundNumber = 1
        showConfetti = false
        sessionRocks = 0; sessionScissors = 0; sessionPapers = 0; sessionWins = 0
        if !isFirebaseMode { setupDemo() }
    }

    // MARK: - Helpers

    private func randomCode() -> String {
        let chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        return String((0..<5).map { _ in chars.randomElement()! })
    }
}
