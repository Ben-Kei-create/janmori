import SwiftUI

struct ContentView: View {
    @StateObject private var appState      = AppState()
    @StateObject private var themeManager  = ThemeManager()

    var body: some View {
        HomeView()
            .environmentObject(appState)
            .environmentObject(themeManager)
    }
}

#Preview {
    ContentView()
}
