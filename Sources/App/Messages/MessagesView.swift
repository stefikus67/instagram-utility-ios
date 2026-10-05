import SwiftUI

/// Messages tab: Instagram's own inbox in the shared web surface. While signed out the login sheet owns
/// the web view, so this tab must not host it at the same time.
struct MessagesView: View {
    @EnvironmentObject private var session: InstagramSession
    @EnvironmentObject private var surface: WebSurfaceController

    var body: some View {
        if session.authState == .loggedOut {
            Theme.bg
        } else {
            VStack(spacing: 0) {
                unreadToggle
                WebSurface()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            // The page may have reloaded while another tab owned the web view; put the saved filter back.
            .onAppear { surface.reapplyUnreadOnly() }
        }
    }

    private var unreadToggle: some View {
        Toggle(isOn: Binding(get: { surface.unreadOnly }, set: { surface.setUnreadOnly($0) })) {
            Text("Unread only").font(Theme.preview).foregroundStyle(Theme.text2)
        }
        .tint(Theme.gold)
        .padding(.horizontal, Spacing.screenEdge)
        .padding(.vertical, Spacing.s)
    }
}
