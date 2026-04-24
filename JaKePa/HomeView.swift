import SwiftUI

struct HomeView: View {
    @EnvironmentObject var appState: AppState

    private enum Dest: Hashable { case room }
    @State private var navigateTo: Dest?
    @State private var joinCode = ""
    @State private var showJoinSheet = false

    var body: some View {
        NavigationStack {
            ZStack {
                FloatingHandsBackground()

                VStack(spacing: 40) {
                    Spacer()

                    // Logo
                    VStack(spacing: 6) {
                        Text("JaKePa")
                            .font(.system(size: 60, weight: .black, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.orange, .pink, .purple],
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
                            appState.reset()
                            navigateTo = .room
                        } label: {
                            Label("ルームを作る", systemImage: "plus.circle.fill")
                                .font(.title2.bold())
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(.orange)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        }

                        Button {
                            showJoinSheet = true
                        } label: {
                            Label("ルームに入る", systemImage: "arrow.right.circle.fill")
                                .font(.title2.bold())
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(.purple)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 60)
                }
            }
            .navigationDestination(item: $navigateTo) { _ in
                RoomView()
            }
            .sheet(isPresented: $showJoinSheet) {
                JoinRoomSheet(joinCode: $joinCode) {
                    appState.isHost = false
                    appState.reset()
                    showJoinSheet = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        navigateTo = .room
                    }
                }
            }
        }
    }
}

// MARK: - Join Room Sheet

struct JoinRoomSheet: View {
    @Binding var joinCode: String
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
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Button("入室する！") { onJoin() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(.purple)
                    .disabled(joinCode.trimmingCharacters(in: .whitespaces).count < 4)

                Spacer()
            }
            .padding(.top, 40)
            .navigationTitle("ルームに入る")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
    }
}
