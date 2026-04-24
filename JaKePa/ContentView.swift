import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 24) {
            Text("JaKePa")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("ジャケッパ")
                .font(.title2)
                .foregroundStyle(.secondary)

            HStack(spacing: 32) {
                Text("✊")
                Text("✌️")
                Text("🖐️")
            }
            .font(.system(size: 64))
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
