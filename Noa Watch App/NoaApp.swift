import SwiftUI

@main
struct Noa_Watch_AppApp: App {
    init() {
        _ = ConnectivityManager.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
