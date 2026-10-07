import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var session: InstagramSession
    @EnvironmentObject private var diagnostics: DiagnosticsStore
    @EnvironmentObject private var surface: WebSurfaceController
    @State private var confirmReset = false
    @State private var editingUsername = false

    private var version: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "\(v) (\(b))"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                Text("Settings").font(Theme.largeTitle).foregroundStyle(Theme.text)
                    .padding(.top, Spacing.s)

                SettingsSection(title: "Profile") {
                    ValueRow(title: "Username", value: surface.ownUsername.map { "@\($0)" } ?? "Not detected")
                    if editingUsername {
                        UsernameEntry(buttonTitle: "Save") { raw in
                            let saved = surface.setOwnUsername(raw)
                            if saved { editingUsername = false }
                            return saved
                        }
                    } else {
                        Button("Change username") { editingUsername = true }
                            .font(Theme.body)
                    }
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
        .task { await session.refreshAuthState() }
    }
}
