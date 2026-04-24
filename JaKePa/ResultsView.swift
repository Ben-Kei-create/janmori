import SwiftUI

struct ResultsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager
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

    // Top 3 by wins (multi-round)
    private var topThree: [Player] {
        Array(appState.players.sorted { $0.wins > $1.wins }.prefix(3))
    }

    private var shareText: String {
        let verdict = winningHand.map { "\($0.rawValue)\($0.displayName)の勝ち！" } ?? "あいこ！🤝"
        let myHand  = appState.myPlayer?.selectedHand.map { $0.rawValue } ?? "?"
        let winnerNames = winners.map { $0.displayName }.joined(separator: "、")
        return """
        【JaKePa 結果】
        ルーム: \(appState.roomCode)
        \(verdict)
        🏆 \(winnerNames.isEmpty ? "なし" : winnerNames)
        私の手: \(myHand)（第\(appState.roundNumber)ラウンド）
        #JaKePa #ジャケッパ
        """
    }

    var body: some View {
        ZStack {
            FloatingHandsBackground()

            ScrollView {
                VStack(spacing: 24) {

                    // Round badge
                    if appState.roundNumber > 1 {
                        Text("第\(appState.roundNumber)ラウンドまで戦いました！")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    // Hand tally
                    HStack(spacing: 12) {
                        ForEach([Hand.rock, .scissors, .paper], id: \.self) { hand in
                            VStack(spacing: 4) {
                                Text(hand.rawValue).font(.system(size: 44))
                                Text("\(handCounts[hand, default: 0])人")
                                    .font(.headline)
                                    .foregroundStyle(winningHand == hand ? themeManager.current.primary : .primary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(winningHand == hand
                                        ? themeManager.current.primary.opacity(0.15)
                                        : Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                    }

                    // Verdict
                    if let w = winningHand {
                        Text("\(w.rawValue) \(w.displayName) の勝ち！🎉")
                            .font(.title.bold())
                            .foregroundStyle(themeManager.current.primary)
                    } else {
                        Text("あいこ！🤝")
                            .font(.largeTitle.bold())
                    }

                    // Top 3 ranking (multi-round)
                    if appState.roundNumber > 1 && topThree.first?.wins ?? 0 > 0 {
                        RankingSection(players: topThree, theme: themeManager.current)
                    }

                    if !winners.isEmpty {
                        ResultGroup(title: "勝ち 🎉", players: winners, color: themeManager.current.primary)
                    }
                    if !losers.isEmpty {
                        ResultGroup(title: "負け 😭", players: losers, color: .purple)
                    }

                    // Share button
                    ShareLink(item: shareText) {
                        Label("結果をシェア", systemImage: "square.and.arrow.up")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemGray6))
                            .foregroundStyle(.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }

                    // Reset
                    Button {
                        appState.saveSessionStats()
                        appState.reset()
                        dismiss()
                    } label: {
                        Label("もう一回！", systemImage: "arrow.clockwise")
                            .font(.title2.bold())
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(themeManager.current.primary)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
                .padding()
            }
        }
        .navigationTitle("結果発表！")
        .navigationBarTitleDisplayMode(.large)
        .onDisappear {
            // Save stats if navigating away without tapping the button
            if !appState.roomCode.isEmpty { appState.saveSessionStats() }
        }
    }
}

// MARK: - Ranking Section

struct RankingSection: View {
    let players: [Player]
    let theme: AppTheme

    private let medals = ["🥇", "🥈", "🥉"]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("総合ランキング 🏆").font(.headline)

            ForEach(Array(players.enumerated()), id: \.element.id) { idx, player in
                HStack(spacing: 12) {
                    Text(medals[safe: idx] ?? "")
                        .font(.title2)
                    Text(player.animal.emoji)
                        .font(.title3)
                    Text(player.displayName)
                        .font(.subheadline.bold())
                    Spacer()
                    Text("\(player.wins)勝")
                        .font(.headline)
                        .foregroundStyle(theme.primary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(idx == 0 ? theme.primary.opacity(0.12) : Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Result Group

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
                        if player.wins > 0 {
                            Text("\(player.wins)勝")
                                .font(.caption2.bold())
                                .foregroundStyle(color)
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

// MARK: - Safe subscript

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
