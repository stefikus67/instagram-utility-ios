import SwiftUI

/// Messages tab: Instagram's own inbox in the shared web surface. While signed out the login sheet owns
/// the web view, so this tab must not host it at the same time.
struct MessagesView: View {
    @EnvironmentObject private var session: InstagramSession

    var body: some View {
        if session.authState == .loggedOut {
            Theme.bg
        } else {
            WebSurface()
        }
    }
}
