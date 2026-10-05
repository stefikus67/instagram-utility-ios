import Foundation

public enum InboxSearch {
    /// Case- and diacritic-insensitive match on the chat name or the last message ("ziga" finds "Žiga").
    /// Blank query returns everything.
    public static func filter(_ threads: [ThreadSummary], query: String) -> [ThreadSummary] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return threads }
        let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
        return threads.filter {
            $0.title.range(of: q, options: options) != nil || $0.lastMessagePreview.range(of: q, options: options) != nil
        }
    }
}
