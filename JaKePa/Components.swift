import SwiftUI

// MARK: - Floating Hands Background

struct FloatingHandsBackground: View {
    private let items = FloatingHandItem.generate()

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(.systemBackground).ignoresSafeArea()
                ForEach(items) { item in
                    FloatingHandItemView(item: item, containerSize: geo.size)
                }
            }
        }
        .ignoresSafeArea()
    }
}

struct FloatingHandItem: Identifiable {
    let id = UUID()
    let emoji: String
    let x: CGFloat
    let y: CGFloat
    let size: CGFloat
    let duration: Double
    let delay: Double

    static func generate() -> [FloatingHandItem] {
        let emojis = ["✊", "✌️", "🖐️"]
        return (0..<15).map { i in
            FloatingHandItem(
                emoji: emojis[i % 3],
                x: CGFloat.random(in: 0.05...0.95),
                y: CGFloat.random(in: 0.05...0.95),
                size: CGFloat.random(in: 26...54),
                duration: Double.random(in: 5...12),
                delay: Double.random(in: 0...8)
            )
        }
    }
}

struct FloatingHandItemView: View {
    let item: FloatingHandItem
    let containerSize: CGSize
    @State private var driftOffset = CGSize.zero

    var body: some View {
        Text(item.emoji)
            .font(.system(size: item.size))
            .opacity(0.07)
            .position(
                x: item.x * containerSize.width,
                y: item.y * containerSize.height
            )
            .offset(driftOffset)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: item.duration)
                        .repeatForever(autoreverses: true)
                        .delay(item.delay)
                ) {
                    driftOffset = CGSize(
                        width: CGFloat.random(in: -28...28),
                        height: CGFloat.random(in: -28...28)
                    )
                }
            }
    }
}

// MARK: - Timer Bar

struct TimerBar: View {
    let progress: Double // 0.0 → 1.0

    @State private var shimmerOffset: CGFloat = -1.0

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color(.systemGray5))

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [.orange, .pink, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(geo.size.width * progress, 0))
                    .overlay(
                        // Shimmer
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [.clear, .white.opacity(0.5), .clear],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * 0.3)
                            .offset(x: shimmerOffset * geo.size.width)
                    )
                    .clipShape(Capsule())
                    .animation(.linear(duration: 1.0), value: progress)
            }
        }
        .onAppear {
            withAnimation(
                .linear(duration: 2.0)
                    .repeatForever(autoreverses: false)
            ) {
                shimmerOffset = 1.3
            }
        }
    }
}

// MARK: - Spiky Announcement Bubble

struct SpikyBubbleShape: Shape {
    let spikes: Int

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerR = min(rect.width, rect.height) * 0.5
        let innerR = outerR * 0.82
        let angleStep = (2 * Double.pi) / Double(spikes * 2)

        var path = Path()
        for i in 0..<(spikes * 2) {
            let angle = Double(i) * angleStep - Double.pi / 2
            let r = i.isMultiple(of: 2) ? outerR : innerR
            let x = center.x + CGFloat(cos(angle)) * r
            let y = center.y + CGFloat(sin(angle)) * r
            if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
            else       { path.addLine(to: CGPoint(x: x, y: y)) }
        }
        path.closeSubpath()
        return path
    }
}

struct AnnouncementBubble: View {
    let announcement: Announcement
    @State private var scale: CGFloat = 0.3
    @State private var rotation: Double = -8

    var body: some View {
        ZStack {
            SpikyBubbleShape(spikes: 16)
                .fill(announcement.isUrgent
                      ? LinearGradient(colors: [.red, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
                      : LinearGradient(colors: [.orange, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 280, height: 280)
                .shadow(color: .black.opacity(0.3), radius: 12)
                .rotationEffect(.degrees(rotation))

            Text(announcement.text)
                .font(.system(size: 36, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .shadow(color: .black.opacity(0.4), radius: 2)
                .padding(32)
        }
        .scaleEffect(scale)
        .onAppear {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.45)) {
                scale = 1.0
            }
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                rotation = 8
            }
        }
    }
}

// MARK: - Player Card

struct PlayerCard: View {
    let player: Player
    let isMe: Bool
    let revealed: Bool

    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .topTrailing) {
                Circle()
                    .fill(isMe ? Color.orange.opacity(0.2) : Color(.systemGray6))
                    .frame(width: 54, height: 54)

                Text(player.animal.emoji)
                    .font(.system(size: 30))
                    .frame(width: 54, height: 54)

                if player.isReady {
                    Circle()
                        .fill(.green)
                        .frame(width: 14, height: 14)
                        .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 2))
                        .offset(x: 3, y: -3)
                }
            }

            Text(player.displayName)
                .font(.caption2.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            if revealed, let hand = player.selectedHand {
                Text(hand.rawValue)
                    .font(.title2)
                    .transition(.scale.combined(with: .opacity))
            } else if !revealed && player.isReady {
                Image(systemName: "lock.fill")
                    .font(.caption2)
                    .foregroundStyle(.green)
            }
        }
        .frame(width: 80)
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isMe ? Color.orange.opacity(0.12) : Color(.systemBackground).opacity(0.85))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isMe ? Color.orange : Color.clear, lineWidth: 2)
        )
    }
}

// MARK: - Floating Stamp View

struct FloatingStampView: View {
    let stamp: FloatingStamp
    @State private var yOffset: CGFloat = 0
    @State private var opacity: Double = 1

    var body: some View {
        VStack(spacing: 2) {
            Text(stamp.emoji)
                .font(.system(size: 44))
            Text(stamp.fromName)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .offset(y: yOffset)
        .opacity(opacity)
        .onAppear {
            withAnimation(.easeOut(duration: 2.5)) {
                yOffset = -200
                opacity = 0
            }
        }
    }
}
