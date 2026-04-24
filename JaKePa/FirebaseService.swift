import Foundation
import FirebaseAuth
import FirebaseDatabase

// MARK: - Snapshot DTOs

struct RoomSnapshot {
    let phase: GamePhase
    let namesLocked: Bool
    let timerStartedAt: TimeInterval?   // milliseconds since epoch
    let settings: RoomSettings
    let host: String

    init?(value: [String: Any]) {
        let phaseStr = value["phase"] as? String ?? "lobby"
        switch phaseStr {
        case "playing":  phase = .playing
        case "revealed": phase = .revealed
        default:         phase = .lobby
        }
        namesLocked    = value["namesLocked"] as? Bool ?? false
        timerStartedAt = value["timerStartedAt"] as? TimeInterval
        host           = value["host"] as? String ?? ""

        let s = value["settings"] as? [String: Any] ?? [:]
        settings = RoomSettings(
            durationMinutes:      s["durationMinutes"]      as? Int ?? 30,
            maxNameChanges:       s["maxNameChanges"]       as? Int ?? 1,
            bubbleDurationSeconds: s["bubbleDurationSeconds"] as? Int ?? 10,
            hostPlays:            s["hostPlays"]            as? Bool ?? true
        )
    }
}

struct PlayerSnapshot {
    let key: String
    let displayName: String
    let animalId: Int
    let hand: Hand?
    let nameChangeCount: Int

    init?(key: String, value: [String: Any]) {
        self.key           = key
        guard let name  = value["displayName"] as? String,
              let aId   = value["animalId"] as? Int else { return nil }
        displayName    = name
        animalId       = aId
        nameChangeCount = value["nameChangeCount"] as? Int ?? 0
        hand = (value["hand"] as? String).flatMap { Hand(rawValue: $0) }
    }
}

// MARK: - FirebaseService

@MainActor
class FirebaseService {
    private let db: DatabaseReference
    private(set) var uid: String = ""
    private(set) var playerKey: String = UUID().uuidString

    private var roomHandle: DatabaseHandle?
    private var playersHandle: DatabaseHandle?
    private var chatHandle: DatabaseHandle?
    private var stampsHandle: DatabaseHandle?
    private var roomRef: DatabaseReference?

    init() {
        db = Database.database().reference()
    }

    // MARK: Auth

    func signIn() async throws {
        if let current = Auth.auth().currentUser {
            uid = current.uid
            return
        }
        let result = try await Auth.auth().signInAnonymously()
        uid = result.user.uid
    }

    // MARK: Room

    func createRoom(code: String, settings: RoomSettings) async throws {
        roomRef = db.child("rooms/\(code)")
        let data: [String: Any] = [
            "host": playerKey,
            "phase": "lobby",
            "namesLocked": false,
            "settings": [
                "durationMinutes":       settings.durationMinutes,
                "maxNameChanges":        settings.maxNameChanges,
                "bubbleDurationSeconds": settings.bubbleDurationSeconds,
                "hostPlays":             settings.hostPlays,
            ],
            "createdAt": ServerValue.timestamp(),
        ]
        try await roomRef!.setValue(data)
    }

    func roomExists(code: String) async throws -> Bool {
        let snap = try await db.child("rooms/\(code)").getData()
        return snap.exists()
    }

    func setRoomRef(code: String) {
        roomRef = db.child("rooms/\(code)")
    }

    func getTakenAnimalIds(code: String) async throws -> [Int] {
        let snap = try await db.child("rooms/\(code)/players").getData()
        guard let dict = snap.value as? [String: Any] else { return [] }
        return dict.values.compactMap { ($0 as? [String: Any])?["animalId"] as? Int }
    }

    // MARK: Players

    func addPlayer(displayName: String, animalId: Int) async throws {
        guard let ref = roomRef else { return }
        let data: [String: Any] = [
            "displayName":    displayName,
            "animalId":       animalId,
            "nameChangeCount": 0,
            "joinedAt":       ServerValue.timestamp(),
        ]
        try await ref.child("players/\(playerKey)").setValue(data)
    }

    func updateName(_ name: String) async throws {
        guard let ref = roomRef else { return }
        try await ref.child("players/\(playerKey)/displayName").setValue(name)
        try await ref.child("players/\(playerKey)/nameChangeCount")
            .runTransactionBlock { current in
                let n = (current.value as? Int ?? 0) + 1
                current.value = n
                return TransactionResult.success(withValue: current)
            }
    }

    func selectHand(_ hand: Hand) async throws {
        guard let ref = roomRef else { return }
        try await ref.child("players/\(playerKey)/hand").setValue(hand.rawValue)
    }

    // MARK: Game Control (host)

    func startTimer() async throws {
        guard let ref = roomRef else { return }
        try await ref.updateChildValues([
            "phase": "playing",
            "timerStartedAt": ServerValue.timestamp(),
        ])
    }

    func revealHands() async throws {
        guard let ref = roomRef else { return }
        try await ref.child("phase").setValue("revealed")
    }

    func lockNames() async throws {
        guard let ref = roomRef else { return }
        try await ref.child("namesLocked").setValue(true)
    }

    func rematchRound() async throws {
        guard let ref = roomRef else { return }
        let snap = try await ref.child("players").getData()
        if let dict = snap.value as? [String: Any] {
            var updates: [String: Any] = ["phase": "playing"]
            for key in dict.keys { updates["players/\(key)/hand"] = NSNull() }
            try await ref.updateChildValues(updates)
        }
    }

    func resetRoom(durationSeconds: Int) async throws {
        guard let ref = roomRef else { return }
        // Clear all hands
        let playersSnap = try await ref.child("players").getData()
        if let players = playersSnap.value as? [String: Any] {
            var updates: [String: Any] = [:]
            for key in players.keys {
                updates["players/\(key)/hand"] = NSNull()
            }
            updates["phase"] = "lobby"
            updates["namesLocked"] = false
            updates["timerStartedAt"] = NSNull()
            try await ref.updateChildValues(updates)
        }
    }

    // MARK: Chat

    func sendChat(text: String, playerName: String, playerEmoji: String) async throws {
        guard let ref = roomRef else { return }
        let data: [String: Any] = [
            "playerId":   playerKey,
            "playerName": playerName,
            "emoji":      playerEmoji,
            "text":       text,
            "ts":         ServerValue.timestamp(),
        ]
        try await ref.child("chat").childByAutoId().setValue(data)
    }

    // MARK: Stamps

    func sendStamp(emoji: String, fromName: String) async throws {
        guard let ref = roomRef else { return }
        let data: [String: Any] = [
            "emoji":    emoji,
            "fromName": fromName,
            "ts":       ServerValue.timestamp(),
        ]
        try await ref.child("stamps").childByAutoId().setValue(data)
    }

    // MARK: Observers

    func observeRoom(onChange: @escaping (RoomSnapshot) -> Void) {
        roomHandle = roomRef?.observe(.value) { snap in
            guard let dict = snap.value as? [String: Any],
                  let room = RoomSnapshot(value: dict) else { return }
            onChange(room)
        }
    }

    func observePlayers(onChange: @escaping ([PlayerSnapshot]) -> Void) {
        playersHandle = roomRef?.child("players").observe(.value) { snap in
            guard let dict = snap.value as? [String: Any] else {
                onChange([])
                return
            }
            let players = dict.compactMap { key, val -> PlayerSnapshot? in
                guard let data = val as? [String: Any] else { return nil }
                return PlayerSnapshot(key: key, value: data)
            }
            onChange(players)
        }
    }

    func observeChat(onMessage: @escaping (ChatMessage, UUID) -> Void) {
        chatHandle = roomRef?.child("chat").observe(.childAdded) { snap in
            guard let dict = snap.value as? [String: Any],
                  let name  = dict["playerName"] as? String,
                  let emoji = dict["emoji"]       as? String,
                  let text  = dict["text"]        as? String,
                  let pid   = dict["playerId"]    as? String else { return }
            let playerId = UUID(uuidString: pid) ?? UUID()
            let msg = ChatMessage(
                playerId: playerId,
                playerAnimalEmoji: emoji,
                playerName: name,
                text: text
            )
            onMessage(msg, playerId)
        }
    }

    func observeStamps(onStamp: @escaping (FloatingStamp) -> Void) {
        stampsHandle = roomRef?.child("stamps").observe(.childAdded) { snap in
            guard let dict  = snap.value as? [String: Any],
                  let emoji = dict["emoji"]    as? String,
                  let from  = dict["fromName"] as? String else { return }
            let stamp = FloatingStamp(
                emoji: emoji,
                fromName: from,
                xPosition: CGFloat.random(in: 60...300)
            )
            onStamp(stamp)
        }
    }

    // MARK: Cleanup

    func removeObservers() {
        if let h = roomHandle    { roomRef?.removeObserver(withHandle: h) }
        if let h = playersHandle { roomRef?.child("players").removeObserver(withHandle: h) }
        if let h = chatHandle    { roomRef?.child("chat").removeObserver(withHandle: h) }
        if let h = stampsHandle  { roomRef?.child("stamps").removeObserver(withHandle: h) }
    }
}
