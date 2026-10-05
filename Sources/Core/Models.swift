import Foundation

/// One row of the inbox. Holds only what the inbox screen shows.
public struct ThreadSummary: Codable, Equatable, Identifiable {
    public let id: String
    public var title: String
    public var avatarURL: URL?
    public var lastMessagePreview: String
    public var lastActivity: Date
    public var isUnread: Bool
    public var isPinned: Bool

    public init(id: String, title: String, avatarURL: URL?, lastMessagePreview: String,
                lastActivity: Date, isUnread: Bool, isPinned: Bool) {
        self.id = id
        self.title = title
        self.avatarURL = avatarURL
        self.lastMessagePreview = lastMessagePreview
        self.lastActivity = lastActivity
        self.isUnread = isUnread
        self.isPinned = isPinned
    }
}

public struct InboxSnapshot: Codable, Equatable {
    public var threads: [ThreadSummary]
    public var fetchedAt: Date

    public init(threads: [ThreadSummary], fetchedAt: Date) {
        self.threads = threads
        self.fetchedAt = fetchedAt
    }
}

/// Where inbox data comes from. The live implementation arrives with InstagramClient (next plan).
public protocol InboxSource {
    func fetchInbox() async throws -> InboxSnapshot
}
