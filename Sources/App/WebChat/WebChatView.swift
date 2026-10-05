import SwiftUI

/// Instagram's web chat as a full-screen fallback. Full screen means the tab bar can never cover Send.
struct WebChatView: View {
    @EnvironmentObject private var session: InstagramSession
    @EnvironmentObject private var diagnostics: DiagnosticsStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            // No .ignoresSafeArea here. The POC's `.ignoresSafeArea(edges: .bottom)` also ignored the
            // keyboard region, which is why the message field ended up under the keyboard.
            InstagramWebView(webView: session.webView)
                .navigationTitle("Web chat")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Done") { dismiss() }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        if diagnostics.currentCategory == .mediaAllowed {
                            Button("Back to chat") { session.backToConversation() }
                        } else {
                            Button("Inbox") { session.loadInbox() }
                        }
                    }
                }
                .toolbarBackground(Theme.bg, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
        }
        .tint(Theme.gold)
    }
}
