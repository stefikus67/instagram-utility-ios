import SwiftUI

/// You: the signed-in user's own Instagram profile in the shared web surface. The username is auto-detected
/// from Instagram's page (see `InjectedScripts.ownProfileJS`); typing it in is only the fallback.
/// The + button opens the story composer: a full-screen cover where Instagram's home page is allowed (feed hidden).
struct YouView: View {
    @EnvironmentObject private var session: InstagramSession
    @EnvironmentObject private var surface: WebSurfaceController

    var body: some View {
        if session.authState == .loggedOut {
            Theme.bg
        } else if surface.ownUsername != nil {
            VStack(spacing: 0) {
                profileHeader
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
            .fullScreenCover(isPresented: composerPresented) { composerCover }
        } else {
            fallback
        }
    }

    private var header: some View {
        Text("You").font(Theme.largeTitle).foregroundStyle(Theme.text)
    }

    private var profileHeader: some View {
        HStack {
            header
            Spacer(minLength: Spacing.s)
            IconButton(systemImage: "plus") { surface.startComposer() }
                .accessibilityLabel("Post story")
        }
    }

    /// Closing goes through `endComposer()` so the web view is always handed back to Messages.
    private var composerPresented: Binding<Bool> {
        Binding(get: { surface.composerOpen }, set: { if !$0 { surface.endComposer() } })
    }

    private var composerCover: some View {
        ZStack(alignment: .topTrailing) {
            Theme.bg.ignoresSafeArea()
            WebSurface()
            if surface.composerVeiled {
                // Covers Instagram's home until the + menu is open, so the feed never flashes.
                Theme.bg.ignoresSafeArea()
                    .overlay { ProgressView().tint(Theme.gold) }
            }
            IconButton(systemImage: "xmark") { surface.endComposer() }
                .accessibilityLabel("Close")
                .padding(Spacing.s)
        }
        .overlay(alignment: .bottom) {
            if let hint = surface.composerHint {
                Text(hint)
                    .font(Theme.label)
                    .foregroundStyle(Theme.text)
                    .padding(.horizontal, Spacing.l)
                    .padding(.vertical, Spacing.s)
                    .background(Capsule().fill(Theme.raise))
                    .padding(.bottom, Spacing.xl)
            }
        }
        .preferredColorScheme(.dark)
        .tint(Theme.gold)
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
