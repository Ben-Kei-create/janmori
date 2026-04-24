import Foundation

// MARK: - Session Record

struct SessionRecord: Codable, Identifiable {
    let id: UUID
    let date: Date
    let roomCode: String
    let playerName: String
    let animalEmoji: String
    let totalWins: Int
    let totalRounds: Int
    let rockCount: Int
    let scissorsCount: Int
    let paperCount: Int

    var winRate: Double {
        guard totalRounds > 0 else { return 0 }
        return Double(totalWins) / Double(totalRounds)
    }
}

// MARK: - StatsManager

class StatsManager: ObservableObject {
    static let shared = StatsManager()

    @Published private(set) var sessions: [SessionRecord] = []

    private let key = "jakeppa_sessions_v1"

    private init() { load() }

    func save(_ record: SessionRecord) {
        sessions.insert(record, at: 0)
        sessions = Array(sessions.prefix(100))
        persist()
    }

    func clear() {
        sessions = []
        UserDefaults.standard.removeObject(forKey: key)
    }

    // MARK: Aggregates

    var totalRocks:    Int { sessions.reduce(0) { $0 + $1.rockCount } }
    var totalScissors: Int { sessions.reduce(0) { $0 + $1.scissorsCount } }
    var totalPapers:   Int { sessions.reduce(0) { $0 + $1.paperCount } }
    var totalHands:    Int { totalRocks + totalScissors + totalPapers }

    var totalWins:   Int { sessions.reduce(0) { $0 + $1.totalWins } }
    var totalRounds: Int { sessions.reduce(0) { $0 + $1.totalRounds } }

    var overallWinRate: Double {
        guard totalRounds > 0 else { return 0 }
        return Double(totalWins) / Double(totalRounds)
    }

    // MARK: Private

    private func persist() {
        if let data = try? JSONEncoder().encode(sessions) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let records = try? JSONDecoder().decode([SessionRecord].self, from: data) else { return }
        sessions = records
    }
}
