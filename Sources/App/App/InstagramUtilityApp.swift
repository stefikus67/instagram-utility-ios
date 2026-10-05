import SwiftUI

@main
struct InstagramUtilityApp: App {
    @StateObject private var session = InstagramSession()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .environmentObject(session.diagnostics)
                .environmentObject(session.surface)
        }
    }
}
