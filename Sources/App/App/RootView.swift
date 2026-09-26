import SwiftUI

/// App shell. Only two destinations exist by design: Messages and Settings.
struct RootView: View {
    var body: some View {
        TabView {
            MessagesView()
                .tabItem { Label("Messages", systemImage: "bubble.left.and.bubble.right") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}
