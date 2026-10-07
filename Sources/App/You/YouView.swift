import SwiftUI

/// You: the signed-in user's own Instagram profile in the shared web surface. The username is auto-detected
/// from Instagram's page (see `InjectedScripts.ownProfileJS`); typing it in is only the fallback.
struct YouView: View {
    @EnvironmentObject private var session: InstagramSession
    @EnvironmentObject private var surface: WebSurfaceController

    var body: some View {
        if session.authState == .loggedOut {
            Theme.bg
        } else if surface.ownUsername != nil {
            VStack(spacing: 0) {
                header
                    .padding(.horizontal, Spacing.screenEdge)
                    .padding(.vertical, Spacing.s)
                    .frame(maxWidth: .infinity, alignment: .leading)
                WebSurface()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .coversInstagramNav()
            }
            // Reload: browsing from the profile to another profile leaves the surface value unchanged, so a plain
            // show(.ownProfile) would be skipped as already-current (same reason as Find people).
            .onAppear { surface.show(.ownProfile, reload: true) }
            .onChange(of: surface.ownUsername) { _ in surface.show(.ownProfile, reload: true) }
        } else {
            fallback
        }
    }

    private var header: some View {
        Text("You").font(Theme.largeTitle).foregroundStyle(Theme.text)
    }

    /// No username known yet: Messages has not been opened since install/Reset, or detection failed.
    private var fallback: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            header
            Text("Open Messages once so Killagram can find your profile, or type your username:")
                .font(Theme.preview)
                .foregroundStyle(Theme.text2)
            UsernameEntry(buttonTitle: "Open profile") { surface.setOwnUsername($0) }
            Spacer()
        }
        .padding(.horizontal, Spacing.screenEdge)
        .padding(.top, Spacing.s)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
