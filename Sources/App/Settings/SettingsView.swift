import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var session: InstagramSession
    @EnvironmentObject private var diagnostics: DiagnosticsStore
    @State private var confirmReset = false

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }
    private var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Diagnostics") {
                    row("App version", "\(version) (\(build))")
                    row("Session", session.authState.rawValue)
                    row("Current host", diagnostics.currentHost)
                    row("Route category", diagnostics.currentCategory?.rawValue ?? "-")
                    row("Blocked navigations", String(diagnostics.blockedCount))
                    row("Last blocked", diagnostics.lastBlockedSurface?.rawValue ?? "-")
                }
                Section {
                    Button("Reset Instagram Session", role: .destructive) { confirmReset = true }
                } footer: {
                    Text("Signs you out and clears Instagram web data stored by this app.")
                }
            }
            .navigationTitle("Settings")
            .confirmationDialog("Reset Instagram session?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Reset and sign out", role: .destructive) { Task { await session.resetSession() } }
                Button("Cancel", role: .cancel) {}
            }
            .task { await session.refreshAuthState() }
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack { Text(title); Spacer(); Text(value).foregroundStyle(.secondary) }
    }
}
