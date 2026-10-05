import SwiftUI

/// The shared Instagram web view as a screen. No `.ignoresSafeArea` here: ignoring the bottom edge would
/// also ignore the keyboard region and put the message field under the keyboard.
struct WebSurface: View {
    @EnvironmentObject private var controller: WebSurfaceController
    @EnvironmentObject private var diagnostics: DiagnosticsStore

    var body: some View {
        InstagramWebView(webView: controller.webView)
            .overlay(alignment: .top) {
                // Media opened from a DM is a one-shot view; this is the way back to the conversation.
                if diagnostics.currentCategory == .mediaAllowed {
                    Button { controller.returnToConversation() } label: {
                        Label("Back to chat", systemImage: "chevron.left")
                    }
                    .buttonStyle(GoldCapsuleButtonStyle())
                    .padding(.top, Spacing.s)
                }
            }
    }
}
