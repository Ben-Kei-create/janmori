import SwiftUI

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager

    private enum Dest: Hashable { case room, stats }
    @State private var navigateTo: Dest?
    @State private var joinCode = ""
    @State private var showSettings = false
    @State private var showJoinSheet = false
    @State private var joinError: String? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                FloatingHandsBackground()

                VStack(spacing: 40) {
                    Spacer()

                    VStack(spacing: 6) {
                        Text("JaKePa")
                            .font(.system(size: 60, weight: .black, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: themeManager.current.logoGradient,
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        Text("ジャケッパ")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 16) {
                            Text("✊").font(.system(size: 36))
                            Text("✌️").font(.system(size: 36))
                            Text("🖐️").font(.system(size: 36))
                        }
                        .padding(.top, 4)
                    }

                    Spacer()

                    VStack(spacing: 16) {
                        Button {
                            appState.isHost = true
                            showSettings = true
                        } label: {
                            Label("ルームを作る", systemImage: "plus.circle.fill")
                                .font(.title2.bold())
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(themeManager.current.primary)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        }

                        Button { showJoinSheet = true } label: {
                            Label("ルームに入る", systemImage: "arrow.right.circle.fill")
                                .font(.title2.bold())
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(themeManager.current.secondary)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        }

                        Button { navigateTo = .stats } label: {
                            Label("統計", systemImage: "chart.bar.fill")
                                .font(.subheadline.bold())
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color(.systemGray6))
                                .foregroundStyle(.primary)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 60)
                }

                if appState.isLoading {
                    Color.black.opacity(0.3).ignoresSafeArea()
                    ProgressView("接続中...")
                        .padding(24)
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
            .navigationDestination(item: $navigateTo) { dest in
                switch dest {
                case .room:  RoomView()
                case .stats: StatsView()
                }
            }
            // Host: settings sheet → creates room → navigate
            .sheet(isPresented: $showSettings) {
                SettingsView {
                    showSettings = false
                    if !appState.roomCode.isEmpty {
                        navigateTo = .room
                    }
                }
                .environmentObject(themeManager)
            }
            // Guest: join sheet
            .sheet(isPresented: $showJoinSheet) {
                JoinRoomSheet(joinCode: $joinCode, error: $joinError) {
                    Task {
                        appState.isHost = false
                        let ok = await appState.joinRoom(code: joinCode)
                        if ok {
                            joinCode = ""
                            showJoinSheet = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                navigateTo = .room
                            }
                        } else {
                            joinError = appState.errorMessage ?? "参加できませんでした"
                        }
                    }
                }
            }
            .alert("エラー", isPresented: Binding(
                get: { appState.errorMessage != nil && !showJoinSheet },
                set: { if !$0 { appState.errorMessage = nil } }
            )) {
                Button("OK") { appState.errorMessage = nil }
            } message: {
                Text(appState.errorMessage ?? "")
            }
        }
    }
}

// MARK: - Join Room Sheet

struct JoinRoomSheet: View {
    @EnvironmentObject var appState: AppState
    @Binding var joinCode: String
    @Binding var error: String?
    let onJoin: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                Text("ルームコードを入力")
                    .font(.title2.bold())

                TextField("例: JAKEP", text: $joinCode)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 32, weight: .bold, design: .monospaced))
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                if let err = error {
                    Text(err)
                        .foregroundStyle(.red)
                        .font(.subheadline)
                }

                if appState.isLoading {
                    ProgressView("確認中...")
                } else {
                    Button("入室する！") {
                        error = nil
                        onJoin()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(.purple)
                    .disabled(joinCode.trimmingCharacters(in: .whitespaces).count < 4)
                }

                Spacer()
            }
            .padding(.top, 40)
            .navigationTitle("ルームに入る")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
    }
}
