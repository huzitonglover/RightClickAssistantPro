//
//  RCAAppDelegate+OperationState.swift
//  RightClickAssistantPro
//
//  Created by 老谭 on 2026/4/30.
//

import AppKit
import Foundation

extension RCAAppDelegate {
    private func authorizationPathKey(for path: String) -> String {
        let decodedPath = path.removingPercentEncoding ?? path
        return URL(fileURLWithPath: decodedPath)
            .standardizedFileURL
            .resolvingSymlinksInPath()
            .path
    }

    func decodedPaths(from target: [String]) -> [String] {
        target.map { $0.removingPercentEncoding ?? $0 }
    }

    func uniqueDecodedPaths(from target: [String]) -> [String] {
        var seen: Set<String> = []

        return decodedPaths(from: target).filter { path in
            guard !path.isEmpty else {
                return false
            }

            return seen.insert(path).inserted
        }
    }

    func matchingAuthorizedDirectory(forPath path: String) -> AuthorizedDirectory? {
        let candidatePath = authorizationPathKey(for: path)
        var matchedDirectory: AuthorizedDirectory?
        var longestPathLength = 0

        for directory in appState.effectiveAuthorizedDirectories {
            let rootPath = authorizationPathKey(for: directory.url.path)
            let prefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
            guard candidatePath == rootPath || candidatePath.hasPrefix(prefix) else {
                continue
            }

            if rootPath.count > longestPathLength {
                matchedDirectory = directory
                longestPathLength = rootPath.count
            }
        }

        return matchedDirectory
    }

    func authorizedDirectoryAccessSnapshots() -> [AuthorizedDirectoryAccessSnapshot] {
        appState.effectiveAuthorizedDirectories
            .map { AuthorizedDirectoryAccessSnapshot(rootPath: $0.url.path, bookmark: $0.bookmark) }
            .sorted(by: { $0.rootPath.count > $1.rootPath.count })
    }

    func isDirectory(atPath path: String) -> Bool {
        var isDirectory: ObjCBool = false
        FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
        return isDirectory.boolValue
    }

    func saveClipboardOperation(_ state: ClipboardOperationState) {
        AssistantOperationArchive.save(state, forKey: SharedPreferenceKey.clipboardOperation)
    }

    func loadClipboardOperation() -> ClipboardOperationState? {
        AssistantOperationArchive.load(ClipboardOperationState.self, forKey: SharedPreferenceKey.clipboardOperation)
    }

    func clearClipboardOperation() {
        AssistantOperationArchive.clear(forKey: SharedPreferenceKey.clipboardOperation)
    }

    func saveUndoOperation(_ state: UndoOperationState) {
        AssistantOperationArchive.save(state, forKey: SharedPreferenceKey.undoOperation)
    }

    func loadUndoOperation() -> UndoOperationState? {
        AssistantOperationArchive.load(UndoOperationState.self, forKey: SharedPreferenceKey.undoOperation)
    }

    func clearUndoOperation() {
        AssistantOperationArchive.clear(forKey: SharedPreferenceKey.undoOperation)
    }

    func registerUndoOperation(
        kind: UndoOperationState.Kind,
        items: [UndoOperationState.Item],
        bookmarkURLs: [URL]
    ) {
        let bookmarks = makeSecurityScopedBookmarks(forDirectories: bookmarkURLs)
        saveUndoOperation(UndoOperationState(kind: kind, items: items, accessBookmarks: bookmarks))
    }

    func makeSecurityScopedBookmarks(forDirectories directories: [URL]) -> [String: Data] {
        var result: [String: Data] = [:]

        for directory in Set(directories.map(\.standardizedFileURL)) {
            if let bookmark = try? directory.bookmarkData(options: .withSecurityScope) {
                result[directory.path] = bookmark
            }
        }

        return result
    }

    func writeClipboardString(_ value: String, successMessage: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let succeeded = pasteboard.setString(value, forType: .string)

        showAlert(
            messageText: succeeded
                ? AssistantLocalized.text(zh: "复制成功", en: "Copied")
                : AssistantLocalized.text(zh: "复制失败", en: "Copy Failed"),
            informativeText: succeeded
                ? successMessage
                : AssistantLocalized.text(zh: "未能写入剪贴板，请稍后再试。", en: "Failed to write to the clipboard. Please try again later."),
            style: succeeded ? .informational : .warning
        )
    }
}
