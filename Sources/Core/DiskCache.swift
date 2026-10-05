import Foundation

/// Small JSON-file cache. One file per key inside `directory`. On iOS files are encrypted by the
/// system until the phone is first unlocked after boot.
public final class DiskCache {
    private let directory: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(directory: URL) throws {
        self.directory = directory
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    public func save<T: Encodable>(_ value: T, forKey key: String) throws {
        let data = try encoder.encode(value)
        #if os(iOS)
        try data.write(to: url(for: key), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        #else
        try data.write(to: url(for: key), options: .atomic)
        #endif
    }

    /// Missing or unreadable entries return nil; a stale cache must never crash the app.
    public func load<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = try? Data(contentsOf: url(for: key)) else { return nil }
        return try? decoder.decode(type, from: data)
    }

    public func removeAll() throws {
        let items = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        for item in items { try FileManager.default.removeItem(at: item) }
    }

    private func url(for key: String) -> URL {
        directory.appendingPathComponent(key + ".json")
    }
}
