import AppKit
import Foundation

public enum Utils {
    public static func isProtectedFolder(_ path: String) -> Bool {
        let candidate = normalizedDirectoryPath(path)
        return Constants.protectedDirs.contains(candidate)
    }

    public static func getRealHomeDir() -> String {
        FileManager.default.homeDirectoryForCurrentUser
            .standardizedFileURL
            .path
    }

    private static func normalizedDirectoryPath(_ path: String) -> String {
        let candidate = URL(fileURLWithPath: path, isDirectory: true)
            .standardizedFileURL
            .path
        return candidate.hasSuffix("/") ? candidate : candidate + "/"
    }
}

enum AssistantFileIconCache {
    private static let workspace = NSWorkspace.shared
    private static let cache = NSCache<NSString, NSImage>()

    static func icon(forPath path: String) -> NSImage {
        let cacheKey = path as NSString
        if let cachedIcon = cache.object(forKey: cacheKey) {
            return cachedIcon
        }

        let icon = workspace.icon(forFile: path)
        cache.setObject(icon, forKey: cacheKey)
        return icon
    }
}
