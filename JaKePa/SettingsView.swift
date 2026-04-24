import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    let onCreate: () -> Void

    @State private var durationMinutes = 30
    @State private var maxNameChanges = 1
    @State private var bubbleDuration = 10
    @State private var hostPlays = true
    @State private var isCreating = false

    private let durationOptions = [1, 3, 5, 10, 15, 20, 30, 45, 60]
    private let bubbleOptions  = [5, 10, 15, 20, 30, 60]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("制限時間", selection: $durationMinutes) {
                        ForEach(durationOptions, id: \.self) { Text("\($0)分").tag($0) }
                    }
                } header: { Text("タイマー") }

                Section {
                    Picker("名前の変更回数", selection: $maxNameChanges) {
                        Text("変更不可").tag(0)
                        ForEach(1...5, id: \.self) { Text("\($0)回").tag($0) }
                    }
                    Toggle("ホストも参加する", isOn: $hostPlays)
                } header: { Text("参加者") }

                Section {
                    Picker("吹き出し表示時間", selection: $bubbleDuration) {
                        ForEach(bubbleOptions, id: \.self) { Text("\($0)秒").tag($0) }
                    }
                } header: { Text("チャット") }
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
                                durationMinutes: durationMinutes,
                                maxNameChanges: maxNameChanges,
                                bubbleDurationSeconds: bubbleDuration,
                                hostPlays: hostPlays
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
                    Button("キャンセル") { onCreate() }  // dismissed by parent
                }
            }
        }
        .presentationDetents([.medium])
        .interactiveDismissDisabled(isCreating)
    }
}
