import SwiftUI
import Charts

struct StatsView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var stats = StatsManager.shared
    @State private var showClearAlert = false

    private var handData: [(hand: String, name: String, count: Int)] {
        [
            ("✊", "グー",   stats.totalRocks),
            ("✌️", "チョキ", stats.totalScissors),
            ("🖐️", "パー",  stats.totalPapers),
        ]
    }

    var body: some View {
        List {
            // ─── Summary ───
            Section {
                HStack(spacing: 0) {
                    StatTile(label: "セッション",  value: "\(stats.sessions.count)",          color: themeManager.current.primary)
                    StatTile(label: "総ラウンド",  value: "\(stats.totalRounds)",              color: themeManager.current.secondary)
                    StatTile(label: "勝率",       value: String(format: "%.0f%%", stats.overallWinRate * 100), color: .green)
                }
                .listRowInsets(.init())
            }

            // ─── Hand Tendency ───
            if stats.totalHands > 0 {
                Section("グー・チョキ・パー傾向") {
                    Chart(handData, id: \.hand) { item in
                        BarMark(
                            x: .value("手", "\(item.hand) \(item.name)"),
                            y: .value("回数", item.count)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: themeManager.current.timerGradient,
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .cornerRadius(8)
                        .annotation(position: .top) {
                            Text("\(item.count)")
                                .font(.caption2.bold())
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(height: 160)
                    .chartYAxis(.hidden)
                    .padding(.vertical, 8)

                    // Tendency label
                    if let fav = handData.max(by: { $0.count < $1.count }), fav.count > 0 {
                        HStack {
                            Text("あなたは")
                                .foregroundStyle(.secondary)
                            Text("\(fav.hand) \(fav.name)") .bold()
                            Text("派！")
                                .foregroundStyle(.secondary)
                        }
                        .font(.subheadline)
                    }
                }
            }

            // ─── Session History ───
            if !stats.sessions.isEmpty {
                Section("セッション履歴") {
                    ForEach(stats.sessions.prefix(20)) { session in
                        SessionRow(session: session, theme: themeManager.current)
                    }
                }

                Section {
                    Button("統計をリセット", role: .destructive) {
                        showClearAlert = true
                    }
                }
            } else {
                Section {
                    ContentUnavailableView(
                        "まだ記録がありません",
                        systemImage: "chart.bar.xaxis",
                        description: Text("ゲームをプレイすると自動で記録されます")
                    )
                }
            }
        }
        .navigationTitle("統計")
        .navigationBarTitleDisplayMode(.large)
        .alert("統計を削除", isPresented: $showClearAlert) {
            Button("削除", role: .destructive) { stats.clear() }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("すべての統計データを削除しますか？")
        }
    }
}

// MARK: - Tiles

private struct StatTile: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title.bold())
                .foregroundStyle(color)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }
}

// MARK: - Session Row

private struct SessionRow: View {
    let session: SessionRecord
    let theme: AppTheme

    var body: some View {
        HStack(spacing: 12) {
            Text(session.animalEmoji)
                .font(.title2)

            VStack(alignment: .leading, spacing: 2) {
                Text(session.playerName)
                    .font(.subheadline.bold())
                Text(session.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(session.totalWins)勝 / \(session.totalRounds)R")
                    .font(.subheadline.bold())
                    .foregroundStyle(theme.primary)
                HStack(spacing: 4) {
                    Text("✊\(session.rockCount)")
                    Text("✌️\(session.scissorsCount)")
                    Text("🖐️\(session.paperCount)")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
    }
}
