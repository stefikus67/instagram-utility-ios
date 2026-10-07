import SwiftUI

/// Find people: Instagram's own account-search page in the shared web surface. The user types in Instagram's
/// search box and gets its live suggestions; tapping a result opens the profile (allowed by the route policy).
/// (`InstagramRoutePolicy.profileURL` is no longer used by the UI; it stays, tested, for callers that need it.)
struct FindPeopleView: View {
    @EnvironmentObject private var session: InstagramSession
    @EnvironmentObject private var surface: WebSurfaceController

    var body: some View {
        if session.authState == .loggedOut {
            Theme.bg
        } else {
            VStack(spacing: 0) {
                Text("Find people").font(Theme.largeTitle).foregroundStyle(Theme.text)
                    .padding(.horizontal, Spacing.screenEdge)
                    .padding(.vertical, Spacing.s)
                    .frame(maxWidth: .infinity, alignment: .leading)
                WebSurface()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .coversInstagramNav()
            }
            // Reload: tapping a result navigates the shared web view to a profile while the surface stays .search,
            // so a plain show(.search) would be skipped as already-current and return to that profile.
            .onAppear { surface.show(.search, reload: true) }
        }
    }
}
