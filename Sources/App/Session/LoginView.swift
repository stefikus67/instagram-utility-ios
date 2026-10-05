import SwiftUI

/// Instagram's own login page, shown whenever there is no session. Cannot be swiped away.
struct LoginView: View {
    @EnvironmentObject private var session: InstagramSession

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: Spacing.xs) {
                Text("Log in to Instagram").font(Theme.name).foregroundStyle(Theme.text)
                Text("This is Instagram's own page. Your password goes only to Instagram.")
                    .font(Theme.label)
                    .foregroundStyle(Theme.text2)
                    .multilineTextAlignment(.center)
            }
            .padding(Spacing.l)
            InstagramWebView(webView: session.webView)
        }
        .background(Theme.bg)
    }
}
