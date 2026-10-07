import SwiftUI

/// The only four destinations in the app (spec §4, plus Settings from M4). There is deliberately no feed, Explore or Reels tab.
enum AppTab: CaseIterable, Hashable {
    case messages, findPeople, you, settings

    var title: String {
        switch self {
        case .messages: return "Messages"
        case .findPeople: return "Find people"
        case .you: return "You"
        case .settings: return "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .messages: return "bubble.left.and.bubble.right"
        case .findPeople: return "magnifyingglass"
        case .you: return "person.crop.circle"
        case .settings: return "gearshape"
        }
    }
}

struct PillTabBar: View {
    @Binding var selection: AppTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                Button { selection = tab } label: {
                    VStack(spacing: Spacing.xs) {
                        Image(systemName: tab.systemImage)
                            .resizable()
                            .scaledToFit()
                            .frame(width: Metrics.tabIcon, height: Metrics.tabIcon)
                        Text(tab.title).font(Theme.tabLabel)
                    }
                    .foregroundStyle(selection == tab ? Theme.gold : Theme.text3)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
            }
        }
        .frame(height: Metrics.tabBarHeight)
        .background(Capsule().fill(Theme.raise))
        .shadow(color: Theme.bg.opacity(0.6), radius: Spacing.l, y: Spacing.s)
    }
}
