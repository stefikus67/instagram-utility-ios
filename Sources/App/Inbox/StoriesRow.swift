import SwiftUI

struct StoryRowItem: Identifiable {
    let id: String
    let name: String
    let avatarURL: URL?
    let kind: StoryCircle.Kind
}

/// Own circle first (posting arrives in milestone 5), then followed accounts' stories.
struct StoriesRow: View {
    let items: [StoryRowItem]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: Metrics.storyGap) {
                StoryCircle(name: "You", avatarURL: nil, kind: .own)
                ForEach(items) { item in
                    StoryCircle(name: item.name, avatarURL: item.avatarURL, kind: item.kind)
                }
            }
            .padding(.horizontal, Spacing.screenEdge)
        }
    }
}
