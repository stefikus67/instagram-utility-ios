import SwiftUI

struct YouView: View {
    @EnvironmentObject private var session: InstagramSession
    @EnvironmentObject private var diagnostics: DiagnosticsStore
    @EnvironmentObject private var surface: WebSurfaceController
    @State private var confirmReset = false
    @State private var showCreator = false

    private var version: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "\(v) (\(b))"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                Text("You").font(Theme.largeTitle).foregroundStyle(Theme.text)
                    .padding(.top, Spacing.s)

                SettingsSection(title: "Stories") {
                    Button("Post a story") { openStoryCreator() }
                        .buttonStyle(GoldCapsuleButtonStyle())
                    Text("Opens Instagram's own story composer.")
                        .font(Theme.label)
                        .foregroundStyle(Theme.text3)
                }

                SettingsSection(title: "Diagnostics") {
                    ValueRow(title: "Version", value: version)
                    ValueRow(title: "Session", value: session.authState.rawValue)
                    ValueRow(title: "Content rules", value: surface.contentRulesActive ? "Active" : "Off")
                    ValueRow(title: "Web host", value: diagnostics.currentHost)
                    ValueRow(title: "Route", value: diagnostics.currentCategory?.rawValue ?? "-")
                    ValueRow(title: "Blocked navigations", value: String(diagnostics.blockedCount))
                    ValueRow(title: "Last blocked", value: diagnostics.lastBlockedSurface?.rawValue ?? "-")
                }

                SettingsSection(title: "Account") {
                    Button("Reset Instagram Session", role: .destructive) { confirmReset = true }
                        .font(Theme.body)
                    Text("Signs you out and deletes your Instagram session.")
                        .font(Theme.label)
                        .foregroundStyle(Theme.text3)
                }
            }
            .padding(.horizontal, Spacing.screenEdge)
        }
        .confirmationDialog("Reset Instagram session?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Reset and sign out", role: .destructive) {
                Task { await session.resetSession() }
            }
            Button("Cancel", role: .cancel) {}
        }
        .fullScreenCover(isPresented: $showCreator, onDismiss: closeStoryCreator) {
            storyCreator
        }
        .task { await session.refreshAuthState() }
    }

    /// The You tab has no web page of its own, so the composer opens full screen over it.
    private var storyCreator: some View {
        ZStack(alignment: .topTrailing) {
            Theme.bg.ignoresSafeArea()
            WebSurface()
                .environmentObject(surface)
                .environmentObject(diagnostics)
            IconButton(systemImage: "xmark") { showCreator = false }
                .padding(Spacing.m)
        }
        .preferredColorScheme(.dark)
        .tint(Theme.gold)
    }

    private func openStoryCreator() {
        surface.isPresentedFullScreen = true
        surface.show(.create)
        showCreator = true
    }

    /// Leaves the composer page (camera, upload state) and returns the web view to the inbox.
    private func closeStoryCreator() {
        surface.isPresentedFullScreen = false
        surface.silence()
        surface.show(.messages)
    }
}
