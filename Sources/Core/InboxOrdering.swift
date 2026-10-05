import Foundation

public enum InboxOrdering {
    /// Pinned chats first, then most recent activity first; ties broken by id so order is stable.
    public static func sorted(_ threads: [ThreadSummary]) -> [ThreadSummary] {
        threads.sorted { a, b in
            if a.isPinned != b.isPinned { return a.isPinned }
            if a.lastActivity != b.lastActivity { return a.lastActivity > b.lastActivity }
            return a.id < b.id
        }
    }
}
