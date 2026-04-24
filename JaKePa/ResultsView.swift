import SwiftUI

struct ResultsView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    private var handCounts: [Hand: Int] {
        appState.players.reduce(into: [:]) { counts, player in
            if let h = player.selectedHand { counts[h, default: 0] += 1 }
        }
    }

    private var winningHand: Hand? {
        let hands = Set(appState.players.compactMap(\.selectedHand))
        guard hands.count == 2 else { return nil }
        if hands == [.rock, .scissors] { return .rock }
        if hands == [.scissors, .paper] { return .scissors }
        if hands == [.paper, .rock]     { return .paper }
        return nil
    }

    private var winners: [Player] {
        guard let w = winningHand else { return [] }
        return appState.players.filter { $0.selectedHand == w }
    }

    private var losers: [Player] {
        guard let w = winningHand else { return [] }
        return appState.players.filter { $0.selectedHand != w }
    }

    var body: some View {
        ZStack {
            FloatingHandsBackground()

            ScrollView {
                VStack(spacing: 24) {
                    // Hand tally
                    HStack(spacing: 20) {
                        ForEach([Hand.rock, .scissors, .paper], id: \.self) { hand in
                            VStack(spacing: 4) {
                                Text(hand.rawValue).font(.system(size: 48))
                                Text("\(handCounts[hand, default: 0])人")
                                    .font(.headline)
                                    .foregroundStyle(winningHand == hand ? .orange : .primary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(winningHand == hand ? Color.orange.opacity(0.15) : Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                    }

                    // Verdict
                    if let w = winningHand {
                        Text("\(w.rawValue) \(w.displayName) の勝ち！🎉")
                            .font(.title.bold())
                            .foregroundStyle(.orange)
                    } else {
                        Text("あいこ！🤝")
                            .font(.largeTitle.bold())
                    }

                    if !winners.isEmpty {
                        ResultGroup(title: "勝ち 🎉", players: winners, color: .orange)
                    }
                    if !losers.isEmpty {
                        ResultGroup(title: "負け 😭", players: losers, color: .purple)
                    }

                    Button {
                        appState.reset()
                        dismiss()
                    } label: {
                        Label("もう一回！", systemImage: "arrow.clockwise")
                            .font(.title2.bold())
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.orange)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
                .padding()
            }
        }
        .navigationTitle("結果発表！")
        .navigationBarTitleDisplayMode(.large)
    }
}

struct ResultGroup: View {
    let title: String
    let players: [Player]
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline).foregroundStyle(color)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 8) {
                ForEach(players) { player in
                    VStack(spacing: 4) {
                        Text(player.animal.emoji).font(.system(size: 34))
                        Text(player.displayName)
                            .font(.caption).lineLimit(1).minimumScaleFactor(0.6)
                        if let hand = player.selectedHand {
                            Text(hand.rawValue).font(.title3)
                        }
                    }
                    .padding(8)
                    .background(color.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
