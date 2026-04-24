import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager
    let onCreate: () -> Void

    @State private var durationMinutes = 30
    @State private var maxNameChanges = 1
    @State private var bubbleDuration = 10
    @State private var hostPlays = true
    @State private var rematchOnDraw = true
    @State private var sfxEnabled = true
    @State private var bgmEnabled = false
    @State private var isCreating = false

    private let durationOptions = [1, 3, 5, 10, 15, 20, 30, 45, 60]
    private let bubbleOptions   = [5, 10, 15, 20, 30, 60]

    var body: some View {
        NavigationStack {
            Form {
                // ─── Timer ───
                Section {
                    Picker("制限時間", selection: $durationMinutes) {
                        ForEach(durationOptions, id: \.self) { Text("\($0)分").tag($0) }
                    }
                } header: { Text("タイマー") }

                // ─── Players ───
                Section {
                    Picker("名前の変更回数", selection: $maxNameChanges) {
                        Text("変更不可").tag(0)
                        ForEach(1...5, id: \.self) { Text("\($0)回").tag($0) }
                    }
                    Toggle("ホストも参加する", isOn: $hostPlays)
                } header: { Text("参加者") }

                // ─── Rules ───
                Section {
                    Toggle("あいこのとき自動で再戦", isOn: $rematchOnDraw)
                } header: { Text("ルール") }
                  footer: { Text("オンにすると、あいこ時に3秒後に自動でラウンドが再開します") }

                // ─── Chat ───
                Section {
                    Picker("吹き出し表示時間", selection: $bubbleDuration) {
                        ForEach(bubbleOptions, id: \.self) { Text("\($0)秒").tag($0) }
                    }
                } header: { Text("チャット") }

                // ─── Sound ───
                Section {
                    Toggle("効果音（バイブ含む）", isOn: $sfxEnabled)
                    Toggle("BGM", isOn: $bgmEnabled)
                        .disabled(true) // BGMファイル未収録
                } header: { Text("サウンド") }
                  footer: { Text("BGMは今後のアップデートで追加予定です") }

                // ─── Theme ───
                Section {
                    ForEach(AppTheme.allCases) { theme in
                        Button {
                            themeManager.current = theme
                        } label: {
                            HStack {
                                Text("\(theme.emoji) \(theme.displayName)")
                                    .foregroundStyle(.primary)
                                Spacer()
                                if themeManager.current == theme {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(theme.primary)
                                        .bold()
                                }
                            }
                        }
                    }
                } header: { Text("テーマカラー") }
            }
            .navigationTitle("ルーム設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    if isCreating {
                        ProgressView()
                    } else {
                        Button("作成！") {
                            isCreating = true
                            appState.settings = RoomSettings(
                                durationMinutes:       durationMinutes,
                                maxNameChanges:        maxNameChanges,
                                bubbleDurationSeconds: bubbleDuration,
                                hostPlays:             hostPlays,
                                rematchOnDraw:         rematchOnDraw,
                                sfxEnabled:            sfxEnabled,
                                bgmEnabled:            bgmEnabled
                            )
                            Task {
                                await appState.createRoom()
                                onCreate()
                            }
                        }
                        .bold()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { onCreate() }
                }
            }
        }
        .presentationDetents([.large])
        .interactiveDismissDisabled(isCreating)
    }
}
