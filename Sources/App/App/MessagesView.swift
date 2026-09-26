import SwiftUI

struct MessagesView: View {
    @EnvironmentObject private var session: InstagramSession
    @EnvironmentObject private var diagnostics: DiagnosticsStore

    var body: some View {
        NavigationStack {
            InstagramWebView(webView: session.webView)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle("Instagram Utility")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        if diagnostics.currentCategory == .dmMediaAllowedOnce {
                            Button("Back to chat") { session.backToConversation() }
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Inbox") { session.loadInbox() }
                    }
                }
        }
        .task { session.startIfNeeded() }
    }
}
