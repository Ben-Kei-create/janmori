import SwiftUI

struct RoomView: View {
    @EnvironmentObject var appState: AppState
    @State private var chatText = ""
    @State private var showStampPanel = false
    @State private var showQRSheet = false
    @State private var showNameChange = false
    @State private var goToResults = false

    var body: some View {
        ZStack {
            FloatingHandsBackground()

            VStack(spacing: 0) {
                TimerHeaderSection()

                ScrollView {
                    VStack(spacing: 16) {
                        RoomCodeBadge(code: appState.roomCode, onTap: { showQRSheet = true })

                        // Names locked banner
                        if appState.namesLocked {
                            Label("名前の変更がロックされました🔒", systemImage: "lock.fill")
                                .font(.subheadline.bold())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(.red.opacity(0.8))
                                .clipShape(Capsule())
                        }

                        PlayerGridSection()
                        if appState.phase != .revealed {
                            HandSelectionSection()
                        }
                        Color.clear.frame(height: 160)
                    }
                    .padding()
                }

                ChatInputBar(chatText: $chatText)
                BottomActionBar(
                    showStampPanel: $showStampPanel,
                    showQRSheet: $showQRSheet,
                    showNameChange: $showNameChange
                )
            }

            ChatBubblesOverlay()
            FloatingStampsLayer()

            if appState.showConfetti {
                ConfettiView()
                    .transition(.opacity)
                    .zIndex(98)
            }

            if let ann = appState.announcement {
                AnnouncementBubble(announcement: ann)
                    .transition(.scale(scale: 0.2).combined(with: .opacity))
                    .zIndex(99)
            }

            if showStampPanel {
                StampPanelOverlay(showStampPanel: $showStampPanel)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(50)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("JaKePa")
        .toolbar {
            if appState.isHost && appState.phase == .lobby {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("スタート！") { appState.startTimer() }
                        if !appState.namesLocked {
                            Button("名前をロック🔒") { appState.lockNames() }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle.fill")
                            .foregroundStyle(.orange)
                    }
                }
            }
            if appState.phase == .playing && appState.isHost {
                ToolbarItem(placement: .primaryAction) {
                    Button("今すぐ発表") { appState.revealHands() }
                        .tint(.red)
                }
            }
            if appState.phase == .revealed {
                ToolbarItem(placement: .primaryAction) {
                    Button("結果を見る") { goToResults = true }
                        .bold()
                        .tint(.pink)
                }
            }
        }
        .navigationDestination(isPresented: $goToResults) {
            ResultsView()
        }
        .sheet(isPresented: $showQRSheet) {
            QRCodeSheet(roomCode: appState.roomCode)
        }
        .sheet(isPresented: $showNameChange) {
            NameChangeSheet()
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.65), value: appState.announcement?.id)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: showStampPanel)
    }
}

// MARK: - Timer Header

private struct TimerHeaderSection: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager

    private var progress: Double {
        let total = Double(appState.settings.durationMinutes * 60)
        guard total > 0 else { return 0 }
        return Double(appState.timeRemaining) / total
    }

    private var timeString: String {
        let m = appState.timeRemaining / 60
        let s = appState.timeRemaining % 60
        return String(format: "%02d:%02d", m, s)
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text(timeString)
                    .font(.system(size: 34, weight: .bold, design: .monospaced))
                Spacer()
                if appState.roundNumber > 1 {
                    Text("第\(appState.roundNumber)ラウンド")
                        .font(.caption.bold())
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(.orange.opacity(0.15))
                        .clipShape(Capsule())
                }
                let ready = appState.players.filter(\.isReady).count
                Text("\(ready) / \(appState.players.count) 準備完了")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)

            TimerBar(progress: progress, gradient: themeManager.current.timerGradient)
                .frame(height: 10)
                .padding(.horizontal)
        }
        .padding(.vertical, 10)
        .background(.thinMaterial)
    }
}

// MARK: - Room Code Badge

private struct RoomCodeBadge: View {
    let code: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: "qrcode")
                Text("ルームコード:")
                    .foregroundStyle(.secondary)
                Text(code)
                    .font(.title3.bold().monospaced())
                    .foregroundStyle(.orange)
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.orange.opacity(0.1))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Player Grid

private struct PlayerGridSection: View {
    @EnvironmentObject var appState: AppState
    @State private var shakeAmount: CGFloat = 0

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 82))], spacing: 10) {
            ForEach(appState.players) { player in
                PlayerCard(
                    player: player,
                    isMe: player.id == appState.myPlayerId,
                    revealed: appState.phase == .revealed
                )
                .modifier(ShakeEffect(animatableData: shakeAmount))
            }
        }
        .onChange(of: appState.phase) { newPhase in
            if newPhase == .revealed {
                withAnimation(.linear(duration: 0.5)) { shakeAmount = 1 }
            } else {
                shakeAmount = 0
            }
        }
    }
}

// MARK: - Hand Selection

private struct HandSelectionSection: View {
    @EnvironmentObject var appState: AppState

    private var myHand: Hand? { appState.myPlayer?.selectedHand }

    var body: some View {
        VStack(spacing: 14) {
            Text(myHand == nil ? "手を選んでね！🤔" : "選択中 \(myHand!.rawValue)")
                .font(.headline)

            HStack(spacing: 12) {
                ForEach(Hand.allCases) { hand in
                    Button {
                        appState.selectHand(hand)
                    } label: {
                        VStack(spacing: 4) {
                            Text(hand.rawValue).font(.system(size: 38))
                            Text(hand.displayName).font(.caption2.bold())
                        }
                        .frame(width: 70, height: 70)
                        .background(myHand == hand ? Color.orange : Color(.systemGray6))
                        .foregroundStyle(myHand == hand ? Color.white : Color.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .scaleEffect(myHand == hand ? 1.08 : 1.0)
                        .animation(.spring(response: 0.25), value: myHand)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

// MARK: - Chat Input

private struct ChatInputBar: View {
    @EnvironmentObject var appState: AppState
    @Binding var chatText: String

    var body: some View {
        HStack(spacing: 8) {
            TextField("一言どうぞ...", text: $chatText)
                .textFieldStyle(.roundedBorder)
                .submitLabel(.send)
                .onSubmit(send)

            Button(action: send) {
                Image(systemName: "paperplane.fill")
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(.blue)
                    .clipShape(Circle())
            }
            .disabled(chatText.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.thinMaterial)
    }

    private func send() {
        let t = chatText.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        appState.sendChat(t)
        chatText = ""
    }
}

// MARK: - Chat Bubbles Overlay

private struct ChatBubblesOverlay: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack {
            Spacer()
            VStack(alignment: .leading, spacing: 6) {
                ForEach(appState.chatMessages.suffix(5)) { msg in
                    HStack(alignment: .bottom, spacing: 6) {
                        Text(msg.playerAnimalEmoji).font(.title3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(msg.playerName)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(msg.text)
                                .font(.subheadline)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(.white.opacity(0.92))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .shadow(color: .black.opacity(0.06), radius: 3)
                        }
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 120)
        }
        .animation(.spring(response: 0.4), value: appState.chatMessages.map(\.id))
        .allowsHitTesting(false)
    }
}

// MARK: - Floating Stamps Layer

private struct FloatingStampsLayer: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(appState.floatingStamps) { stamp in
                    FloatingStampView(stamp: stamp)
                        .position(
                            x: min(stamp.xPosition, geo.size.width - 50),
                            y: geo.size.height - 180
                        )
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Stamp Panel Overlay

private struct StampPanelOverlay: View {
    @EnvironmentObject var appState: AppState
    @Binding var showStampPanel: Bool

    private let columns = [GridItem(.adaptive(minimum: 72))]

    var body: some View {
        VStack {
            Spacer()
            VStack(spacing: 12) {
                HStack {
                    Text("スタンプ").font(.headline)
                    Spacer()
                    Button {
                        withAnimation { showStampPanel = false }
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                }

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(Stamp.allCases) { stamp in
                        Button {
                            appState.sendStamp(stamp)
                            withAnimation { showStampPanel = false }
                        } label: {
                            VStack(spacing: 4) {
                                Text(stamp.rawValue).font(.system(size: 36))
                                Text(stamp.label).font(.caption2).foregroundStyle(.secondary)
                            }
                            .frame(width: 72, height: 72)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding()
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
    }
}

// MARK: - Bottom Action Bar

private struct BottomActionBar: View {
    @EnvironmentObject var appState: AppState
    @Binding var showStampPanel: Bool
    @Binding var showQRSheet: Bool
    @Binding var showNameChange: Bool

    private var canChangeName: Bool {
        guard !appState.namesLocked else { return false }
        guard let me = appState.myPlayer else { return false }
        return appState.settings.maxNameChanges == 0
            || me.nameChangeCount < appState.settings.maxNameChanges
    }

    var body: some View {
        HStack(spacing: 12) {
            ActionButton(emoji: "👍", label: "いいね！", color: .yellow) {
                appState.sendLike()
            }

            ActionButton(emoji: "😄", label: "スタンプ", color: .pink) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    showStampPanel.toggle()
                }
            }

            if canChangeName {
                ActionButton(systemImage: "pencil.circle.fill", label: "名前変更", color: .green) {
                    showNameChange = true
                }
            }

            Spacer()

            ActionButton(systemImage: "qrcode", label: "QRコード", color: .blue) {
                showQRSheet = true
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.thinMaterial)
    }
}

private struct ActionButton: View {
    var emoji: String?
    var systemImage: String?
    let label: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                if let e = emoji {
                    Text(e).font(.title2)
                } else if let img = systemImage {
                    Image(systemName: img).font(.title2)
                }
                Text(label).font(.caption2.bold())
            }
            .frame(width: 64, height: 54)
            .background(color.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Name Change Sheet

struct NameChangeSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @State private var newName = ""
    @State private var errorMsg: String? = nil

    private var remaining: Int {
        let max = appState.settings.maxNameChanges
        guard max > 0 else { return 99 }
        let used = appState.myPlayer?.nameChangeCount ?? 0
        return max - used
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if let me = appState.myPlayer {
                    Text("いまの名前: \(me.displayName)")
                        .foregroundStyle(.secondary)
                }

                if appState.settings.maxNameChanges > 0 {
                    Text("残り\(remaining)回変更できます")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                TextField("新しい名前", text: $newName)
                    .textFieldStyle(.roundedBorder)
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .onChange(of: newName) { _ in errorMsg = nil }

                if let err = errorMsg {
                    Text(err)
                        .foregroundStyle(.red)
                        .font(.subheadline)
                }

                Button("変更する") {
                    if let err = appState.changeName(newName) {
                        errorMsg = err
                    } else {
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)

                Spacer()
            }
            .padding(.top, 32)
            .navigationTitle("名前を変える")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - QR Code Sheet

struct QRCodeSheet: View {
    let roomCode: String
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(.systemGray6))
                        .frame(width: 240, height: 240)
                    VStack(spacing: 8) {
                        Image(systemName: "qrcode")
                            .font(.system(size: 80))
                            .foregroundStyle(.secondary)
                        Text("QR実装予定")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }

                Text(roomCode)
                    .font(.system(size: 52, weight: .black, design: .monospaced))
                    .foregroundStyle(.orange)

                Text("このコードを入力してルームに参加！")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .navigationTitle("ルームに参加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
