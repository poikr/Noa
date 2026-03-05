import SwiftUI

@main
struct NoaApp: App {
    init() {
        _ = ConnectivityManager.shared
        NotificationManager.shared.requestPermission()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
