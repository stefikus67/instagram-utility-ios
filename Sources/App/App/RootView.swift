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
        .fullScreenCover(isPresented: $session.webChatPresented) {
            WebChatView()
        }
        .task { await session.start() }
    }

    @ViewBuilder private var screen: some View {
        switch tab {
        case .messages: InboxView()
        case .findPeople: FindPeopleView()
        case .you: YouView()
        }
    }
}
