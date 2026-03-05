import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            Tab("시간표", systemImage: "calendar") {
                TimetableGridView()
            }
            Tab("설정", systemImage: "gearshape") {
                SettingsView()
            }
        }
    }
}
