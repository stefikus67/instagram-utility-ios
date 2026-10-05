import SwiftUI

struct YouView: View {
    @EnvironmentObject private var session: InstagramSession
    @EnvironmentObject private var diagnostics: DiagnosticsStore
    @State private var confirmReset = false

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

                SettingsSection(title: "Web chat") {
                    Button("Open web chat") { session.openWebChat() }
                        .font(Theme.body)
                        .foregroundStyle(Theme.gold)
                }

                SettingsSection(title: "Diagnostics") {
                    ValueRow(title: "Version", value: version)
                    ValueRow(title: "Session", value: session.authState.rawValue)
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
        .task { await session.refreshAuthState() }
    }
}
