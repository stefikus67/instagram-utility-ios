import Foundation

public enum InboxSearch {
    /// Case-insensitive match on the chat name or the last message. Blank query returns everything.
    public static func filter(_ threads: [ThreadSummary], query: String) -> [ThreadSummary] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return threads }
        return threads.filter {
            $0.title.localizedCaseInsensitiveContains(q) || $0.lastMessagePreview.localizedCaseInsensitiveContains(q)
        }
    }
}
