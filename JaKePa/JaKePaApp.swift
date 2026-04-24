import SwiftUI
import FirebaseCore

@main
struct JaKePaApp: App {
    init() {
        // Firebase only activates when GoogleService-Info.plist has real credentials
        if let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
           let plist = NSDictionary(contentsOfFile: path),
           let projectId = plist["PROJECT_ID"] as? String,
           !projectId.hasPrefix("your-") {
            FirebaseApp.configure()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
