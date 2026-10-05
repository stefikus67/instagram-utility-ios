import SwiftUI

/// App shell: three tabs in a floating pill, login sheet when signed out, web chat as a full-screen cover.
struct RootView: View {
    @EnvironmentObject private var session: InstagramSession
    @State private var tab: AppTab = .messages

    private var loginRequired: Binding<Bool> {
        // While web chat is open, Instagram's login page shows inside it; the sheet appears after Done.
        Binding(get: { session.authState == .loggedOut && !session.webChatPresented }, set: { _ in })
    }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            screen
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                // Keep the last row scrollable above the floating bar.
                .safeAreaInset(edge: .bottom) {
                    Color.clear.frame(height: Metrics.tabBarHeight + Spacing.s)
                }
            VStack {
                Spacer()
                PillTabBar(selection: $tab)
                    .padding(.horizontal, Metrics.tabBarSide)
                    .padding(.bottom, Metrics.tabBarBottom)
            }
            .ignoresSafeArea(.container, edges: .bottom)
            .ignoresSafeArea(.keyboard)
        }
        .preferredColorScheme(.dark)
        .tint(Theme.gold)
        .sheet(isPresented: loginRequired) {
            LoginView().interactiveDismissDisabled()
        }
        .fullScreenCover(isPresented: $session.webChatPresented, onDismiss: { session.parkWebView() }) {
            WebChatView()
        }
        .task { await session.start() }
    }

    @ViewBuilder private var screen: some View {
        switch tab {
        case .messages: MessagesPlaceholderView()
        case .findPeople: FindPeopleView()
        case .you: YouView()
        }
    }
}

/// Temporary Messages tab body until the web surface is wired in (milestone 2, task 5).
private struct MessagesPlaceholderView: View {
    @EnvironmentObject private var session: InstagramSession

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            Text("Messages").font(Theme.largeTitle).foregroundStyle(Theme.text)
            Button("Open web chat") { session.openWebChat() }
                .font(Theme.body)
                .foregroundStyle(Theme.gold)
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.screenEdge)
        .padding(.top, Spacing.s)
    }
}
