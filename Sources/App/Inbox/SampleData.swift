import Foundation

/// Fake chats for checking the design on the phone before the live inbox exists.
/// Stored under a separate cache key so it can never mix with real data.
struct SampleInboxSource: InboxSource {
    func fetchInbox() async throws -> InboxSnapshot {
        let now = Date()
        func ago(_ minutes: Double) -> Date { now.addingTimeInterval(-minutes * 60) }
        return InboxSnapshot(threads: [
            ThreadSummary(id: "s1", title: "Ana", avatarURL: nil, lastMessagePreview: "sent you a reel",
                          lastActivity: ago(4), isUnread: true, isPinned: false),
            ThreadSummary(id: "s2", title: "Luka", avatarURL: nil, lastMessagePreview: "Voice message · 0:14",
                          lastActivity: ago(41), isUnread: false, isPinned: false),
            ThreadSummary(id: "s3", title: "Maja", avatarURL: nil, lastMessagePreview: "haha ok see you there",
                          lastActivity: ago(60 * 26), isUnread: false, isPinned: false),
            ThreadSummary(id: "s4", title: "Tim", avatarURL: nil, lastMessagePreview: "You: sent a photo",
                          lastActivity: ago(60 * 50), isUnread: false, isPinned: false),
            ThreadSummary(id: "s5", title: "Nika", avatarURL: nil, lastMessagePreview: "ok 👍",
                          lastActivity: ago(60 * 24 * 9), isUnread: false, isPinned: true),
        ], fetchedAt: now)
    }
}

enum SampleStories {
    static let items: [StoryRowItem] = [
        StoryRowItem(id: "s1", name: "Ana", avatarURL: nil, kind: .unseen),
        StoryRowItem(id: "s2", name: "Luka", avatarURL: nil, kind: .unseen),
        StoryRowItem(id: "s3", name: "Maja", avatarURL: nil, kind: .seen),
        StoryRowItem(id: "s4", name: "Tim", avatarURL: nil, kind: .seen),
    ]
}
