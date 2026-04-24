import SwiftUI

struct ContentView: View {
    @StateObject private var appState = AppState()

    var body: some View {
        HomeView()
            .environmentObject(appState)
    }
}

#Preview {
    ContentView()
}
