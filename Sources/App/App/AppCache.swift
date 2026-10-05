import Foundation

enum AppCache {
    static func make() -> DiskCache {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        if let cache = try? DiskCache(directory: base.appendingPathComponent("Cache", isDirectory: true)) {
            return cache
        }
        // Application Support is always creatable in practice; tmp keeps the app launching if it isn't.
        return try! DiskCache(directory: FileManager.default.temporaryDirectory
            .appendingPathComponent("Cache", isDirectory: true))
    }
}
