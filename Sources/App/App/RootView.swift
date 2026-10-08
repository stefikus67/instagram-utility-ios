import SwiftUI

/// App shell: four tabs in a floating pill, login sheet when signed out. One web view is shared and
/// re-pointed per tab through `WebSurfaceController.show(_:)`.
struct RootView: View {
    @EnvironmentObject private var session: InstagramSession
    @EnvironmentObject private var surface: WebSurfaceController
    @State private var tab: AppTab = .messages

    private var loginRequired: Binding<Bool> {
        // Not while the story composer cover is up: the login sheet must never stack on it.
        Binding(get: { session.authState == .loggedOut && !surface.composerOpen }, set: { _ in })
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
        .onChange(of: tab) { newTab in
            if newTab == .messages { surface.show(.messages) } else { surface.silence() }
        }
        .onChange(of: surface.composerOpen) { open in
            // Closing the composer hands the web view back to Messages, so show that tab.
            if !open { tab = .messages }
        }
        .onChange(of: session.authState) { state in
            // After login (or Reset then login) the web view is still on Instagram's login flow.
            if state == .authenticated { surface.show(.messages) }
        }
        .task { await session.start() }
    }

    @ViewBuilder private var screen: some View {
        switch tab {
        case .messages: MessagesView()
        case .findPeople: FindPeopleView()
        case .you: YouView()
        case .settings: SettingsView()
        }
    }
}
