import SwiftUI

/// Find and open Instagram profiles by username.
struct FindPeopleView: View {
    @EnvironmentObject private var session: InstagramSession
    @EnvironmentObject private var surface: WebSurfaceController

    @State private var text = ""
    @State private var showError = false
    @FocusState private var focused: Bool

    var body: some View {
        if session.authState == .loggedOut {
            Theme.bg
        } else {
            VStack(spacing: Spacing.m) {
                Text("Find people").font(Theme.largeTitle).foregroundStyle(Theme.text)
                    .padding(.horizontal, Spacing.screenEdge)
                    .padding(.top, Spacing.s)
                    .frame(maxWidth: .infinity, alignment: .leading)

                SearchField(text: $text, placeholder: "Username")
                    .padding(.horizontal, Spacing.screenEdge)
                    .focused($focused)
                    .onSubmit(handleSubmit)

                if showError {
                    Text("Enter a valid Instagram username")
                        .font(Theme.preview)
                        .foregroundStyle(Theme.text3)
                        .padding(.horizontal, Spacing.screenEdge)
                }

                WebSurface()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func handleSubmit() {
        let url = InstagramRoutePolicy.profileURL(username: text)
        if let url = url {
            // Determine cleaned username for display.
            var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if cleaned.hasPrefix("@") { cleaned.removeFirst() }
            surface.show(.profile(username: cleaned))
            showError = false
        } else {
            showError = true
        }
    }
}

