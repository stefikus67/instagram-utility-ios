import SwiftUI

@main
struct InstagramUtilityApp: App {
    @StateObject private var session = InstagramSession()
    @StateObject private var inbox = InboxStore(cache: AppCache.make())

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .environmentObject(session.diagnostics)
                .environmentObject(inbox)
        }
    }
}
