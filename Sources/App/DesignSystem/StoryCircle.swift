import SwiftUI

struct StoryCircle: View {
    enum Kind { case unseen, seen, own }

    let name: String
    let avatarURL: URL?
    let kind: Kind

    var body: some View {
        VStack(spacing: Metrics.storyLabelGap) {
            circle.frame(width: Metrics.storyCircle, height: Metrics.storyCircle)
            Text(name)
                .font(Theme.label)
                .foregroundStyle(Theme.text2)
                .lineLimit(1)
                .frame(width: Metrics.storyCircle)
        }
    }

    @ViewBuilder private var circle: some View {
        switch kind {
        case .own:
            Avatar(url: avatarURL, size: Metrics.storyCircle)
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "plus")
                        .font(.system(size: TypeScale.label, weight: .bold))
                        .foregroundStyle(Theme.goldInk)
                        .frame(width: Metrics.plusBadge, height: Metrics.plusBadge)
                        .background(Circle().fill(Theme.gold))
                        .overlay(Circle().stroke(Theme.bg, lineWidth: Metrics.plusBadgeBorder))
                }
        case .unseen, .seen:
            ZStack {
                Circle().fill(kind == .unseen ? AnyShapeStyle(Theme.storyRingGradient) : AnyShapeStyle(Theme.seenRing))
                Circle().fill(Theme.bg)
                    .frame(width: Metrics.storyCircle - 2 * Metrics.storyRing,
                           height: Metrics.storyCircle - 2 * Metrics.storyRing)
                Avatar(url: avatarURL, size: Metrics.storyAvatar)
            }
        }
    }
}
