//
//  AssistantOperationStateSupport.swift
//  RightClickAssistantPro
//
//  Created by 老谭 on 2026/4/30.
//

import AppKit
import Foundation

struct ClipboardOperationState: Codable, Sendable {
    let mode: Mode
    let sourcePaths: [String]

    enum Mode: String, Codable, Sendable {
        case copy
        case cut
    }
}

struct UndoOperationState: Codable, Sendable {
    let kind: Kind
    let items: [Item]
    let accessBookmarks: [String: Data]

    enum Kind: String, Codable, Sendable {
        case move
        case copy
        case create
        case rename
        case hide
    }

    struct Item: Codable, Sendable {
        let originalPath: String?
        let currentPath: String
    }
}

struct AuthorizedDirectoryAccessSnapshot: Sendable {
    let rootPath: String
    let bookmark: Data
}

struct FileTransferExecutionResult: Sendable {
    let failedMessages: [String]
    let undoItems: [UndoOperationState.Item]
    let bookmarkURLs: [URL]
    let shouldClearClipboard: Bool
}

struct UndoExecutionResult: Sendable {
    let failedMessages: [String]
    let remainingItems: [UndoOperationState.Item]
}

struct BatchFileOperationResult: Sendable {
    let failedMessages: [String]
}

struct EmptyFolderCleanupResult: Sendable {
    let removedCount: Int
    let failedMessages: [String]
}

struct EmptyFolderCleanupTarget: Sendable {
    let path: String
    let preservesRoot: Bool
}

struct FolderDissolveResult: Sendable {
    let dissolvedFolderCount: Int
    let movedItemCount: Int
    let failedMessages: [String]
    let undoItems: [UndoOperationState.Item]
    let bookmarkURLs: [URL]
}

struct BatchRenameExecutionResult: Sendable {
    let failedMessages: [String]
    let undoItems: [UndoOperationState.Item]
    let bookmarkURLs: [URL]
}

struct ArchiveCompressionExecutionResult: Sendable {
    let archiveURL: URL?
    let failedMessages: [String]
}

struct ArchiveExtractionExecutionResult: Sendable {
    let extractedDirectories: [URL]
    let failedMessages: [String]
    let passwordProtectedArchivePaths: [String]
}

struct FolderIconUpdateResult: Sendable {
    let updatedCount: Int
    let failedMessages: [String]
}

struct ShortcutCreationResult: Sendable {
    let createdURLs: [URL]
    let failedMessages: [String]
}

private struct AssistantBatchRenameWorkRecord: Sendable {
    let sourceURL: URL
    let temporaryURL: URL
    let destinationURL: URL
}

private struct AssistantCommandExecutionResult: Sendable {
    let terminationStatus: Int32
    let output: String
}

enum AssistantOperationArchive {
    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()

    static func save<State: Codable>(_ state: State, forKey key: String, defaults: UserDefaults = .group) {
        guard let data = try? encoder.encode(state) else {
            return
        }
        defaults.set(data, forKey: key)
    }

    static func load<State: Codable>(_ stateType: State.Type, forKey key: String, defaults: UserDefaults = .group) -> State? {
        guard let data = defaults.data(forKey: key) else {
            return nil
        }
        return try? decoder.decode(stateType, from: data)
    }

    static func clear(forKey key: String, defaults: UserDefaults = .group) {
        defaults.removeObject(forKey: key)
    }
}

enum AssistantScopedFileWorker {
    static func applyCustomIcon(
        icon: NSImage?,
        folderPaths: [String],
        accessSnapshots: [AuthorizedDirectoryAccessSnapshot]
    ) -> FolderIconUpdateResult {
        let workspace = NSWorkspace.shared
        let fileManager = FileManager.default
        let sortedSnapshots = sorted(accessSnapshots)
        var updatedCount = 0
        var failedMessages: [String] = []

        for folderPath in folderPaths {
            let folderURL = URL(fileURLWithPath: folderPath, isDirectory: true)
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: folderURL.path, isDirectory: &isDirectory), isDirectory.boolValue else {
                failedMessages.append(
                    AssistantLocalized.text(
                        zh: "\(folderURL.lastPathComponent)：只能给文件夹更换图标。",
                        en: "\(folderURL.lastPathComponent): Only folders can use this icon action."
                    )
                )
                continue
            }

            if Utils.isProtectedFolder(folderURL.path) {
                failedMessages.append(
                    AssistantLocalized.text(
                        zh: "跳过受保护路径：\(folderURL.lastPathComponent)",
                        en: "Skipped protected path: \(folderURL.lastPathComponent)"
                    )
                )
                continue
            }

            let didUpdateIcon: Bool = {
                let stopAccess = startScopedAccess(for: folderURL, primarySnapshots: sortedSnapshots)
                defer { stopAccess?() }
                return workspace.setIcon(icon, forFile: folderURL.path, options: [])
            }()

            guard didUpdateIcon else {
                failedMessages.append(
                    AssistantLocalized.text(
                        zh: "\(folderURL.lastPathComponent)：图标写入失败。",
                        en: "\(folderURL.lastPathComponent): Failed to write the icon."
                    )
                )
                continue
            }

            updatedCount += 1
        }

        return FolderIconUpdateResult(updatedCount: updatedCount, failedMessages: failedMessages)
    }

    static func performTransfer(
        sourcePaths: [String],
        destinationURL: URL,
        moveItems: Bool,
        clearClipboardOnSuccess: Bool,
        accessSnapshots: [AuthorizedDirectoryAccessSnapshot]
    ) -> FileTransferExecutionResult {
        let fileManager = FileManager.default
        let sortedSnapshots = sorted(accessSnapshots)
        var failedMessages: [String] = []
        var undoItems: [UndoOperationState.Item] = []
        var bookmarkURLs: [URL] = [destinationURL]

        let destinationStopAccess = startScopedAccess(for: destinationURL, primarySnapshots: sortedSnapshots)
        defer { destinationStopAccess?() }

        for sourcePath in sourcePaths {
            let sourceURL = URL(fileURLWithPath: sourcePath)

            if Utils.isProtectedFolder(sourcePath) {
                failedMessages.append("跳过受保护路径：\(sourceURL.lastPathComponent)")
                continue
            }

            let sourceStopAccess = startScopedAccess(for: sourceURL, primarySnapshots: sortedSnapshots)
            defer { sourceStopAccess?() }

            let targetURL = uniqueDestinationURL(for: sourceURL, in: destinationURL, fileManager: fileManager)

            do {
                if moveItems {
                    try fileManager.moveItem(at: sourceURL, to: targetURL)
                    undoItems.append(.init(originalPath: sourceURL.path, currentPath: targetURL.path))
                    bookmarkURLs.append(sourceURL.deletingLastPathComponent())
                } else {
                    try fileManager.copyItem(at: sourceURL, to: targetURL)
                    undoItems.append(.init(originalPath: nil, currentPath: targetURL.path))
                }
            } catch {
                failedMessages.append("\(sourceURL.lastPathComponent)：\(error.localizedDescription)")
            }
        }

        return FileTransferExecutionResult(
            failedMessages: failedMessages,
            undoItems: undoItems,
            bookmarkURLs: bookmarkURLs,
            shouldClearClipboard: clearClipboardOnSuccess && failedMessages.isEmpty
        )
    }

    static func performUndo(
        state: UndoOperationState,
        authorizedSnapshots: [AuthorizedDirectoryAccessSnapshot]
    ) -> UndoExecutionResult {
        let fileManager = FileManager.default
        let undoSnapshots = bookmarkSnapshots(from: state.accessBookmarks)
        let fallbackSnapshots = sorted(authorizedSnapshots)
        var failedMessages: [String] = []
        var remainingItems: [UndoOperationState.Item] = []

        for item in state.items {
            switch state.kind {
            case .move, .rename:
                guard let originalPath = item.originalPath else { continue }

                let currentURL = URL(fileURLWithPath: item.currentPath)
                let originalURL = URL(fileURLWithPath: originalPath)
                let originalParentURL = originalURL.deletingLastPathComponent()

                let currentStopAccess = startScopedAccess(
                    for: currentURL.deletingLastPathComponent(),
                    primarySnapshots: undoSnapshots,
                    fallbackSnapshots: fallbackSnapshots
                )
                defer { currentStopAccess?() }

                let originalStopAccess = startScopedAccess(
                    for: originalParentURL,
                    primarySnapshots: undoSnapshots,
                    fallbackSnapshots: fallbackSnapshots
                )
                defer { originalStopAccess?() }

                do {
                    guard fileManager.fileExists(atPath: currentURL.path) else { continue }

                    if !fileManager.fileExists(atPath: originalParentURL.path) {
                        try fileManager.createDirectory(at: originalParentURL, withIntermediateDirectories: true)
                    }

                    if fileManager.fileExists(atPath: originalURL.path) {
                        failedMessages.append("\(originalURL.lastPathComponent)：原位置已存在同名项目")
                        remainingItems.append(item)
                        continue
                    }

                    try fileManager.moveItem(at: currentURL, to: originalURL)
                } catch {
                    failedMessages.append("\(currentURL.lastPathComponent)：\(error.localizedDescription)")
                    remainingItems.append(item)
                }

            case .copy, .create:
                let currentURL = URL(fileURLWithPath: item.currentPath)
                let stopAccess = startScopedAccess(
                    for: currentURL.deletingLastPathComponent(),
                    primarySnapshots: undoSnapshots,
                    fallbackSnapshots: fallbackSnapshots
                )
                defer { stopAccess?() }

                do {
                    guard fileManager.fileExists(atPath: currentURL.path) else { continue }
                    try fileManager.removeItem(at: currentURL)
                } catch {
                    failedMessages.append("\(currentURL.lastPathComponent)：\(error.localizedDescription)")
                    remainingItems.append(item)
                }

            case .hide:
                var currentURL = URL(fileURLWithPath: item.currentPath)
                let stopAccess = startScopedAccess(
                    for: currentURL.deletingLastPathComponent(),
                    primarySnapshots: undoSnapshots,
                    fallbackSnapshots: fallbackSnapshots
                )
                defer { stopAccess?() }

                do {
                    guard fileManager.fileExists(atPath: currentURL.path) else { continue }
                    var values = URLResourceValues()
                    values.isHidden = false
                    try currentURL.setResourceValues(values)
                } catch {
                    failedMessages.append("\(currentURL.lastPathComponent)：\(error.localizedDescription)")
                    remainingItems.append(item)
                }
            }
        }

        return UndoExecutionResult(failedMessages: failedMessages, remainingItems: remainingItems)
    }

    static func performDelete(
        paths: [String],
        accessSnapshots: [AuthorizedDirectoryAccessSnapshot]
    ) -> BatchFileOperationResult {
        let fileManager = FileManager.default
        let sortedSnapshots = sorted(accessSnapshots)
        var failedMessages: [String] = []

        for path in paths {
            let fileURL = URL(fileURLWithPath: path)

            if Utils.isProtectedFolder(path) {
                failedMessages.append("无法删除系统保护文件夹：\(path)")
                continue
            }

            let stopAccess = startScopedAccess(for: fileURL, primarySnapshots: sortedSnapshots)
            defer { stopAccess?() }

            do {
                try fileManager.removeItem(at: fileURL)
            } catch {
                failedMessages.append("\(fileURL.lastPathComponent)：\(error.localizedDescription)")
            }
        }

        return BatchFileOperationResult(failedMessages: failedMessages)
    }

    static func createDesktopAliases(
        sourcePaths: [String],
        desktopURL: URL,
        accessSnapshots: [AuthorizedDirectoryAccessSnapshot]
    ) -> ShortcutCreationResult {
        let fileManager = FileManager.default
        let sortedSnapshots = sorted(accessSnapshots)
        let sourceURLs = uniqueStandardizedFileURLs(from: sourcePaths)
        var createdURLs: [URL] = []
        var failedMessages: [String] = []

        guard !sourceURLs.isEmpty else {
            return ShortcutCreationResult(
                createdURLs: [],
                failedMessages: [
                    AssistantLocalized.text(
                        zh: "没有可创建快捷方式的文件或文件夹。",
                        en: "There are no files or folders available for shortcut creation."
                    )
                ]
            )
        }

        let desktopStopAccess = startScopedAccess(for: desktopURL, primarySnapshots: sortedSnapshots)
        defer { desktopStopAccess?() }

        do {
            try fileManager.createDirectory(at: desktopURL, withIntermediateDirectories: true)
        } catch {
            return ShortcutCreationResult(
                createdURLs: [],
                failedMessages: [
                    AssistantLocalized.text(
                        zh: "桌面目录不可用：\(error.localizedDescription)",
                        en: "The Desktop folder is unavailable: \(error.localizedDescription)"
                    )
                ]
            )
        }

        for sourceURL in sourceURLs {
            guard fileManager.fileExists(atPath: sourceURL.path) else {
                failedMessages.append(
                    AssistantLocalized.text(
                        zh: "\(sourceURL.lastPathComponent)：原项目不存在。",
                        en: "\(sourceURL.lastPathComponent): The source item no longer exists."
                    )
                )
                continue
            }

            let sourceStopAccess = startScopedAccess(for: sourceURL, primarySnapshots: sortedSnapshots)
            defer { sourceStopAccess?() }

            let aliasURL = uniqueAliasURL(for: sourceURL, in: desktopURL, fileManager: fileManager)

            do {
                let bookmark = try sourceURL.bookmarkData(options: .suitableForBookmarkFile)
                try URL.writeBookmarkData(bookmark, to: aliasURL)
                createdURLs.append(aliasURL)
            } catch {
                failedMessages.append("\(sourceURL.lastPathComponent)：\(error.localizedDescription)")
            }
        }

        return ShortcutCreationResult(createdURLs: createdURLs, failedMessages: failedMessages)
    }

    static func performBatchRename(
        operations: [BatchRenameOperation],
        accessSnapshots: [AuthorizedDirectoryAccessSnapshot]
    ) -> BatchRenameExecutionResult {
        guard !operations.isEmpty else {
            return BatchRenameExecutionResult(
                failedMessages: [],
                undoItems: [],
                bookmarkURLs: []
            )
        }

        let fileManager = FileManager.default
        let sortedSnapshots = sorted(accessSnapshots)
        let selectedSourceKeys = Set(operations.map { canonicalPathKey(for: $0.sourcePath) })
        let targetKeyCounts = Dictionary(
            operations.map { (canonicalPathKey(for: $0.destinationPath), 1) },
            uniquingKeysWith: +
        )

        var stopAccessors: [() -> Void] = []
        let directoryURLs = Set(
            operations.flatMap { operation in
                [
                    URL(fileURLWithPath: operation.sourcePath).deletingLastPathComponent().standardizedFileURL,
                    URL(fileURLWithPath: operation.destinationPath).deletingLastPathComponent().standardizedFileURL
                ]
            }
        )

        for directoryURL in directoryURLs.sorted(by: { $0.path.count > $1.path.count }) {
            if let stopAccess = startScopedAccess(for: directoryURL, primarySnapshots: sortedSnapshots) {
                stopAccessors.append(stopAccess)
            }
        }
        defer {
            for stopAccess in stopAccessors.reversed() {
                stopAccess()
            }
        }

        var preflightFailures: [String] = []
        var workRecords: [AssistantBatchRenameWorkRecord] = []
        workRecords.reserveCapacity(operations.count)

        for operation in operations {
            let sourceURL = URL(fileURLWithPath: operation.sourcePath).standardizedFileURL
            let destinationURL = URL(fileURLWithPath: operation.destinationPath).standardizedFileURL

            guard sourceURL.path != destinationURL.path else {
                continue
            }

            let destinationKey = canonicalPathKey(for: destinationURL.path)
            if targetKeyCounts[destinationKey, default: 0] > 1 {
                preflightFailures.append("\(sourceURL.lastPathComponent)：目标名称重复")
                continue
            }

            guard fileManager.fileExists(atPath: sourceURL.path) else {
                preflightFailures.append("\(sourceURL.lastPathComponent)：原项目不存在")
                continue
            }

            if fileManager.fileExists(atPath: destinationURL.path),
               !selectedSourceKeys.contains(destinationKey) {
                preflightFailures.append("\(sourceURL.lastPathComponent)：目标名称已存在")
                continue
            }

            workRecords.append(
                AssistantBatchRenameWorkRecord(
                    sourceURL: sourceURL,
                    temporaryURL: uniqueTemporaryRenameURL(for: sourceURL, fileManager: fileManager),
                    destinationURL: destinationURL
                )
            )
        }

        guard preflightFailures.isEmpty else {
            return BatchRenameExecutionResult(
                failedMessages: preflightFailures,
                undoItems: [],
                bookmarkURLs: []
            )
        }

        var stagedRecords: [AssistantBatchRenameWorkRecord] = []
        stagedRecords.reserveCapacity(workRecords.count)

        for record in workRecords {
            do {
                try fileManager.moveItem(at: record.sourceURL, to: record.temporaryURL)
                stagedRecords.append(record)
            } catch {
                let rollbackMessages = rollbackRenameRecords(
                    finalizedRecords: [],
                    stagedRecords: ArraySlice(stagedRecords),
                    fileManager: fileManager
                )

                return BatchRenameExecutionResult(
                    failedMessages: ["\(record.sourceURL.lastPathComponent)：\(error.localizedDescription)"] + rollbackMessages,
                    undoItems: [],
                    bookmarkURLs: []
                )
            }
        }

        var finalizedRecords: [AssistantBatchRenameWorkRecord] = []
        finalizedRecords.reserveCapacity(stagedRecords.count)

        for index in stagedRecords.indices {
            let record = stagedRecords[index]

            do {
                try fileManager.moveItem(at: record.temporaryURL, to: record.destinationURL)
                finalizedRecords.append(record)
            } catch {
                let rollbackMessages = rollbackRenameRecords(
                    finalizedRecords: finalizedRecords,
                    stagedRecords: stagedRecords[index...],
                    fileManager: fileManager
                )

                return BatchRenameExecutionResult(
                    failedMessages: ["\(record.sourceURL.lastPathComponent)：\(error.localizedDescription)"] + rollbackMessages,
                    undoItems: [],
                    bookmarkURLs: []
                )
            }
        }

        let undoItems = finalizedRecords.map {
            UndoOperationState.Item(
                originalPath: $0.sourceURL.path,
                currentPath: $0.destinationURL.path
            )
        }
        let bookmarkURLs = finalizedRecords.flatMap {
            [
                $0.sourceURL.deletingLastPathComponent(),
                $0.destinationURL.deletingLastPathComponent()
            ]
        }

        return BatchRenameExecutionResult(
            failedMessages: [],
            undoItems: undoItems,
            bookmarkURLs: bookmarkURLs
        )
    }

    static func performEmptyFolderCleanup(
        targets: [EmptyFolderCleanupTarget],
        accessSnapshots: [AuthorizedDirectoryAccessSnapshot]
    ) -> EmptyFolderCleanupResult {
        let fileManager = FileManager.default
        let sortedSnapshots = sorted(accessSnapshots)
        let cleanupTargets = targets.compactMap { target -> (url: URL, preservesRoot: Bool)? in
            let url = URL(fileURLWithPath: target.path).standardizedFileURL
            guard fileManager.fileExists(atPath: url.path) else {
                return nil
            }
            return (url, target.preservesRoot)
        }

        var stopAccessors: [() -> Void] = []
        for target in cleanupTargets.sorted(by: { $0.url.path.count > $1.url.path.count }) {
            if let stopAccess = startScopedAccess(for: target.url, primarySnapshots: sortedSnapshots) {
                stopAccessors.append(stopAccess)
            }
        }
        defer {
            for stopAccess in stopAccessors.reversed() {
                stopAccess()
            }
        }

        var removedCount = 0
        var failedMessages: [String] = []

        for target in cleanupTargets {
            let rootURL = target.url
            guard fileManager.fileExists(atPath: rootURL.path) else {
                continue
            }

            guard !Utils.isProtectedFolder(rootURL.path) else {
                failedMessages.append("已跳过系统保护目录：\(rootURL.path)")
                continue
            }

            do {
                removedCount += try removeEmptyFoldersAtCurrentLevel(
                    in: rootURL,
                    preservingRoot: target.preservesRoot,
                    fileManager: fileManager
                )
            } catch {
                failedMessages.append("\(rootURL.lastPathComponent)：\(error.localizedDescription)")
            }
        }

        return EmptyFolderCleanupResult(
            removedCount: removedCount,
            failedMessages: failedMessages
        )
    }

    static func dissolveFolders(
        folderPaths: [String],
        accessSnapshots: [AuthorizedDirectoryAccessSnapshot]
    ) -> FolderDissolveResult {
        let fileManager = FileManager.default
        let sortedSnapshots = sorted(accessSnapshots)
        let folderURLs = uniqueStandardizedFileURLs(from: folderPaths)
        var dissolvedFolderCount = 0
        var movedItemCount = 0
        var failedMessages: [String] = []
        var undoItems: [UndoOperationState.Item] = []
        var bookmarkURLs: [URL] = []

        for folderURL in folderURLs {
            let parentURL = folderURL.deletingLastPathComponent().standardizedFileURL
            var stopAccessors: [() -> Void] = []
            if let stopAccess = startScopedAccess(for: folderURL, primarySnapshots: sortedSnapshots) {
                stopAccessors.append(stopAccess)
            }
            if let stopAccess = startScopedAccess(for: parentURL, primarySnapshots: sortedSnapshots) {
                stopAccessors.append(stopAccess)
            }
            defer {
                for stopAccess in stopAccessors.reversed() {
                    stopAccess()
                }
            }

            guard let folderValues = try? folderURL.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey, .isSymbolicLinkKey]),
                  folderValues.isDirectory == true,
                  folderValues.isPackage != true,
                  folderValues.isSymbolicLink != true else {
                failedMessages.append(
                    AssistantLocalized.text(
                        zh: "\(folderURL.lastPathComponent)：只能解散普通文件夹。",
                        en: "\(folderURL.lastPathComponent): Only regular folders can be dissolved."
                    )
                )
                continue
            }

            guard !Utils.isProtectedFolder(folderURL.path) else {
                failedMessages.append(
                    AssistantLocalized.text(
                        zh: "跳过受保护路径：\(folderURL.lastPathComponent)",
                        en: "Skipped protected path: \(folderURL.lastPathComponent)"
                    )
                )
                continue
            }

            let children: [URL]
            do {
                children = try fileManager.contentsOfDirectory(
                    at: folderURL,
                    includingPropertiesForKeys: nil,
                    options: []
                )
            } catch {
                failedMessages.append("\(folderURL.lastPathComponent)：\(error.localizedDescription)")
                continue
            }

            if children.isEmpty {
                do {
                    try fileManager.removeItem(at: folderURL)
                    dissolvedFolderCount += 1
                    bookmarkURLs.append(parentURL)
                } catch {
                    failedMessages.append("\(folderURL.lastPathComponent)：\(error.localizedDescription)")
                }
                continue
            }

            var movedChildrenInFolder = 0
            for childURL in children {
                let destinationURL = parentURL.appendingPathComponent(childURL.lastPathComponent)
                guard canonicalPathKey(for: childURL.path) != canonicalPathKey(for: destinationURL.path) else {
                    continue
                }

                if fileManager.fileExists(atPath: destinationURL.path) {
                    if isDisposableFinderMetadata(childURL) {
                        try? fileManager.removeItem(at: childURL)
                        continue
                    }

                    failedMessages.append(
                        AssistantLocalized.text(
                            zh: "\(folderURL.lastPathComponent)/\(childURL.lastPathComponent)：上级目录已有同名项目，已跳过。",
                            en: "\(folderURL.lastPathComponent)/\(childURL.lastPathComponent): An item with the same name already exists in the parent folder."
                        )
                    )
                    continue
                }

                do {
                    try fileManager.moveItem(at: childURL, to: destinationURL)
                    movedChildrenInFolder += 1
                    movedItemCount += 1
                    undoItems.append(.init(originalPath: childURL.path, currentPath: destinationURL.path))
                } catch {
                    failedMessages.append("\(folderURL.lastPathComponent)/\(childURL.lastPathComponent)：\(error.localizedDescription)")
                }
            }

            do {
                let remainingChildren = try fileManager.contentsOfDirectory(
                    at: folderURL,
                    includingPropertiesForKeys: nil,
                    options: []
                )
                guard remainingChildren.isEmpty else {
                    if movedChildrenInFolder > 0 {
                        failedMessages.append(
                            AssistantLocalized.text(
                                zh: "\(folderURL.lastPathComponent)：仍有未移出的项目，已保留原文件夹。",
                                en: "\(folderURL.lastPathComponent): Some items remain, so the original folder was kept."
                            )
                        )
                    }
                    bookmarkURLs.append(folderURL)
                    bookmarkURLs.append(parentURL)
                    continue
                }

                try fileManager.removeItem(at: folderURL)
                dissolvedFolderCount += 1
                bookmarkURLs.append(folderURL)
                bookmarkURLs.append(parentURL)
            } catch {
                failedMessages.append("\(folderURL.lastPathComponent)：\(error.localizedDescription)")
                bookmarkURLs.append(folderURL)
                bookmarkURLs.append(parentURL)
            }
        }

        return FolderDissolveResult(
            dissolvedFolderCount: dissolvedFolderCount,
            movedItemCount: movedItemCount,
            failedMessages: failedMessages,
            undoItems: undoItems,
            bookmarkURLs: bookmarkURLs
        )
    }

    static func performZIPCompression(
        sourcePaths: [String],
        password: String?,
        accessSnapshots: [AuthorizedDirectoryAccessSnapshot]
    ) -> ArchiveCompressionExecutionResult {
        let fileManager = FileManager.default
        let sortedSnapshots = sorted(accessSnapshots)
        let sourceURLs = uniqueStandardizedFileURLs(from: sourcePaths)

        guard !sourceURLs.isEmpty else {
            return ArchiveCompressionExecutionResult(
                archiveURL: nil,
                failedMessages: [AssistantLocalized.text(zh: "没有可压缩的文件或文件夹。", en: "There are no files or folders available to compress.")]
            )
        }

        guard let destinationDirectoryURL = sharedParentDirectoryURL(for: sourceURLs) else {
            return ArchiveCompressionExecutionResult(
                archiveURL: nil,
                failedMessages: [
                    AssistantLocalized.text(
                        zh: "请在同一文件夹内选择要压缩的项目。",
                        en: "Select items from the same folder before creating the archive."
                    )
                ]
            )
        }

        let duplicateNames = duplicateArchiveEntryNames(in: sourceURLs)
        guard duplicateNames.isEmpty else {
            return ArchiveCompressionExecutionResult(
                archiveURL: nil,
                failedMessages: duplicateNames.map {
                    AssistantLocalized.text(
                        zh: "检测到重复名称，无法一起压缩：\($0)",
                        en: "A duplicate archive entry name was found, so these items cannot be compressed together: \($0)"
                    )
                }
            )
        }

        let destinationURL = uniqueArchiveURL(for: sourceURLs, in: destinationDirectoryURL, fileManager: fileManager)
        var stopAccessors: [() -> Void] = []

        if let stopAccess = startScopedAccess(for: destinationDirectoryURL, primarySnapshots: sortedSnapshots) {
            stopAccessors.append(stopAccess)
        }

        for sourceURL in sourceURLs.sorted(by: { $0.path.count > $1.path.count }) {
            if Utils.isProtectedFolder(sourceURL.path) {
                continue
            }

            if let stopAccess = startScopedAccess(for: sourceURL, primarySnapshots: sortedSnapshots) {
                stopAccessors.append(stopAccess)
            }
        }

        defer {
            for stopAccess in stopAccessors.reversed() {
                stopAccess()
            }
        }

        for sourceURL in sourceURLs where !fileManager.fileExists(atPath: sourceURL.path) {
            return ArchiveCompressionExecutionResult(
                archiveURL: nil,
                failedMessages: ["\(sourceURL.lastPathComponent)：\(AssistantLocalized.text(zh: "原项目不存在。", en: "The source item no longer exists."))"]
            )
        }

        let relativeSourceNames = sourceURLs.map { sanitizedArchiveInputName(for: $0.lastPathComponent) }
        let normalizedPassword = password?.trimmingCharacters(in: .whitespacesAndNewlines)
        let archivePassword = normalizedPassword?.isEmpty == false ? normalizedPassword : nil
        var compressionArguments = [
            "-r",
            "-q",
            "-X"
        ]
        if let archivePassword {
            compressionArguments += ["-P", archivePassword]
        }
        compressionArguments += [
            destinationURL.path,
            "--"
        ] + relativeSourceNames

        let commandResult = runCommand(
            launchPath: "/usr/bin/zip",
            arguments: compressionArguments,
            currentDirectoryURL: destinationDirectoryURL
        )

        guard commandResult.terminationStatus == 0 else {
            if fileManager.fileExists(atPath: destinationURL.path) {
                try? fileManager.removeItem(at: destinationURL)
            }

            let message = commandResult.output.trimmingCharacters(in: .whitespacesAndNewlines)
            return ArchiveCompressionExecutionResult(
                archiveURL: nil,
                failedMessages: [
                    message.isEmpty
                        ? AssistantLocalized.text(zh: "压缩失败。", en: "Failed to create the archive.")
                        : message
                ]
            )
        }

        if archivePassword != nil, !zipArchiveRequiresPassword(at: destinationURL) {
            if fileManager.fileExists(atPath: destinationURL.path) {
                try? fileManager.removeItem(at: destinationURL)
            }

            return ArchiveCompressionExecutionResult(
                archiveURL: nil,
                failedMessages: [
                    AssistantLocalized.text(
                        zh: "加密压缩失败：生成的 ZIP 未检测到密码保护。",
                        en: "Encrypted archive failed: the generated ZIP was not detected as password-protected."
                    )
                ]
            )
        }

        return ArchiveCompressionExecutionResult(
            archiveURL: destinationURL,
            failedMessages: []
        )
    }

    static func performZIPExtraction(
        sourcePaths: [String],
        password: String?,
        accessSnapshots: [AuthorizedDirectoryAccessSnapshot]
    ) -> ArchiveExtractionExecutionResult {
        let fileManager = FileManager.default
        let sortedSnapshots = sorted(accessSnapshots)
        let sourceURLs = uniqueStandardizedFileURLs(from: sourcePaths)
        var extractedDirectories: [URL] = []
        var failedMessages: [String] = []
        var passwordProtectedArchivePaths: [String] = []

        for sourceURL in sourceURLs {
            guard sourceURL.pathExtension.lowercased() == "zip" else {
                failedMessages.append(
                    AssistantLocalized.text(
                        zh: "\(sourceURL.lastPathComponent)：只支持 ZIP 压缩包。",
                        en: "\(sourceURL.lastPathComponent): Only ZIP archives are supported."
                    )
                )
                continue
            }

            guard fileManager.fileExists(atPath: sourceURL.path) else {
                failedMessages.append(
                    AssistantLocalized.text(
                        zh: "\(sourceURL.lastPathComponent)：压缩包不存在。",
                        en: "\(sourceURL.lastPathComponent): The archive no longer exists."
                    )
                )
                continue
            }

            if password == nil, zipArchiveRequiresPassword(at: sourceURL) {
                passwordProtectedArchivePaths.append(sourceURL.path)
                continue
            }

            let destinationParentURL = sourceURL.deletingLastPathComponent()
            let destinationDirectoryURL = uniqueExtractionDirectoryURL(for: sourceURL, in: destinationParentURL, fileManager: fileManager)
            var stopAccessors: [() -> Void] = []

            if let stopAccess = startScopedAccess(for: sourceURL, primarySnapshots: sortedSnapshots) {
                stopAccessors.append(stopAccess)
            }

            if let stopAccess = startScopedAccess(for: destinationParentURL, primarySnapshots: sortedSnapshots) {
                stopAccessors.append(stopAccess)
            }

            defer {
                for stopAccess in stopAccessors.reversed() {
                    stopAccess()
                }
            }

            do {
                try fileManager.createDirectory(at: destinationDirectoryURL, withIntermediateDirectories: true)
            } catch {
                failedMessages.append("\(sourceURL.lastPathComponent)：\(error.localizedDescription)")
                continue
            }

            var extractionArguments: [String] = []
            if let password {
                extractionArguments += ["--passphrase", password]
            }
            extractionArguments += [
                "-xf",
                sourceURL.path,
                "-C",
                destinationDirectoryURL.path
            ]

            let commandResult = runCommand(
                launchPath: "/usr/bin/bsdtar",
                arguments: extractionArguments
            )

            guard commandResult.terminationStatus == 0 else {
                try? fileManager.removeItem(at: destinationDirectoryURL)
                let message = commandResult.output.trimmingCharacters(in: .whitespacesAndNewlines)
                if password == nil, looksLikeArchivePasswordFailure(message) {
                    passwordProtectedArchivePaths.append(sourceURL.path)
                    continue
                }

                failedMessages.append(
                    message.isEmpty
                        ? AssistantLocalized.text(
                            zh: "\(sourceURL.lastPathComponent)：解压失败。",
                            en: "\(sourceURL.lastPathComponent): Failed to extract the archive."
                        )
                        : "\(sourceURL.lastPathComponent)：\(message)"
                )
                continue
            }

            extractedDirectories.append(destinationDirectoryURL)
        }

        return ArchiveExtractionExecutionResult(
            extractedDirectories: extractedDirectories,
            failedMessages: failedMessages,
            passwordProtectedArchivePaths: passwordProtectedArchivePaths
        )
    }

    private static func looksLikeArchivePasswordFailure(_ message: String) -> Bool {
        let lowercasedMessage = message.lowercased()
        return lowercasedMessage.contains("password")
            || lowercasedMessage.contains("passphrase")
            || lowercasedMessage.contains("encrypted")
            || lowercasedMessage.contains("encryption")
            || lowercasedMessage.contains("incorrect")
            || lowercasedMessage.contains("authentication")
            || message.contains("密码")
            || message.contains("加密")
    }

    private static func zipArchiveRequiresPassword(at archiveURL: URL) -> Bool {
        let commandResult = runCommand(
            launchPath: "/usr/bin/zipinfo",
            arguments: ["-l", archiveURL.path]
        )

        guard commandResult.terminationStatus == 0 else {
            return false
        }

        return commandResult.output.split(whereSeparator: \.isNewline).contains { line in
            let columns = line.split(whereSeparator: \.isWhitespace)
            guard columns.count >= 8 else {
                return false
            }

            return columns[4].contains("l")
        }
    }

    private static func bookmarkSnapshots(from accessBookmarks: [String: Data]) -> [AuthorizedDirectoryAccessSnapshot] {
        sorted(accessBookmarks.map { AuthorizedDirectoryAccessSnapshot(rootPath: $0.key, bookmark: $0.value) })
    }

    private static func sorted(_ snapshots: [AuthorizedDirectoryAccessSnapshot]) -> [AuthorizedDirectoryAccessSnapshot] {
        snapshots.sorted(by: { canonicalPathKey(for: $0.rootPath).count > canonicalPathKey(for: $1.rootPath).count })
    }

    private static func startScopedAccess(
        for url: URL,
        primarySnapshots: [AuthorizedDirectoryAccessSnapshot],
        fallbackSnapshots: [AuthorizedDirectoryAccessSnapshot] = []
    ) -> (() -> Void)? {
        if let accessStopper = startScopedAccessUsingSnapshots(for: url, snapshots: primarySnapshots) {
            return accessStopper
        }

        if let accessStopper = startScopedAccessUsingSnapshots(for: url, snapshots: fallbackSnapshots) {
            return accessStopper
        }

        guard url.startAccessingSecurityScopedResource() else {
            return nil
        }

        return { url.stopAccessingSecurityScopedResource() }
    }

    private static func startScopedAccessUsingSnapshots(
        for url: URL,
        snapshots: [AuthorizedDirectoryAccessSnapshot]
    ) -> (() -> Void)? {
        guard let snapshot = matchingSnapshot(forPath: url.path, in: snapshots) else {
            return nil
        }

        var isStale = false
        do {
            let scopedURL = try URL(
                resolvingBookmarkData: snapshot.bookmark,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            guard scopedURL.startAccessingSecurityScopedResource() else {
                return nil
            }

            return { scopedURL.stopAccessingSecurityScopedResource() }
        } catch {
            return nil
        }
    }

    private static func matchingSnapshot(
        forPath path: String,
        in snapshots: [AuthorizedDirectoryAccessSnapshot]
    ) -> AuthorizedDirectoryAccessSnapshot? {
        let candidatePath = canonicalPathKey(for: path)
        return snapshots.first { snapshot in
            let rootPath = canonicalPathKey(for: snapshot.rootPath)
            let prefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
            return candidatePath == rootPath || candidatePath.hasPrefix(prefix)
        }
    }

    private static func uniqueDestinationURL(
        for sourceURL: URL,
        in destinationDirectoryURL: URL,
        fileManager: FileManager
    ) -> URL {
        let fileExtension = sourceURL.pathExtension
        let baseName = sourceURL.deletingPathExtension().lastPathComponent

        var candidateURL = destinationDirectoryURL.appendingPathComponent(sourceURL.lastPathComponent)
        var index = 1

        while fileManager.fileExists(atPath: candidateURL.path) {
            let suffix = " copy \(index)"
            let filename = fileExtension.isEmpty ? "\(baseName)\(suffix)" : "\(baseName)\(suffix).\(fileExtension)"
            candidateURL = destinationDirectoryURL.appendingPathComponent(filename)
            index += 1
        }

        return candidateURL
    }

    private static func uniqueArchiveURL(
        for sourceURLs: [URL],
        in destinationDirectoryURL: URL,
        fileManager: FileManager
    ) -> URL {
        let baseName: String
        if sourceURLs.count == 1, let sourceURL = sourceURLs.first {
            baseName = sourceURL.lastPathComponent
        } else {
            baseName = AssistantLocalized.text(zh: "加密压缩包", en: "Encrypted Archive")
        }

        var candidateURL = destinationDirectoryURL
            .appendingPathComponent(baseName)
            .appendingPathExtension("zip")
        var index = 1

        while fileManager.fileExists(atPath: candidateURL.path) {
            candidateURL = destinationDirectoryURL
                .appendingPathComponent("\(baseName) \(index)")
                .appendingPathExtension("zip")
            index += 1
        }

        return candidateURL
    }

    private static func uniqueAliasURL(
        for sourceURL: URL,
        in desktopURL: URL,
        fileManager: FileManager
    ) -> URL {
        let baseName = sourceURL.lastPathComponent.isEmpty
            ? AssistantLocalized.text(zh: "快捷方式", en: "Shortcut")
            : sourceURL.lastPathComponent
        var candidateURL = desktopURL
            .appendingPathComponent(baseName)
            .appendingPathExtension("alias")
        var index = 1

        while fileManager.fileExists(atPath: candidateURL.path) {
            candidateURL = desktopURL
                .appendingPathComponent("\(baseName) \(index)")
                .appendingPathExtension("alias")
            index += 1
        }

        return candidateURL
    }

    private static func uniqueExtractionDirectoryURL(
        for sourceURL: URL,
        in destinationParentURL: URL,
        fileManager: FileManager
    ) -> URL {
        let baseName = sourceURL.deletingPathExtension().lastPathComponent
        let folderName = baseName.isEmpty
            ? AssistantLocalized.text(zh: "已解压文件", en: "Extracted Files")
            : baseName

        var candidateURL = destinationParentURL.appendingPathComponent(folderName, isDirectory: true)
        var index = 1

        while fileManager.fileExists(atPath: candidateURL.path) {
            candidateURL = destinationParentURL.appendingPathComponent("\(folderName) \(index)", isDirectory: true)
            index += 1
        }

        return candidateURL
    }

    private static func sharedParentDirectoryURL(for sourceURLs: [URL]) -> URL? {
        guard let firstParentURL = sourceURLs.first?.deletingLastPathComponent().standardizedFileURL else {
            return nil
        }

        guard sourceURLs.dropFirst().allSatisfy({
            $0.deletingLastPathComponent().standardizedFileURL.path == firstParentURL.path
        }) else {
            return nil
        }

        return firstParentURL
    }

    private static func duplicateArchiveEntryNames(in sourceURLs: [URL]) -> [String] {
        let counts = Dictionary(sourceURLs.map { ($0.lastPathComponent.lowercased(), 1) }, uniquingKeysWith: +)
        let originalNames = Dictionary(uniqueKeysWithValues: sourceURLs.map { ($0.lastPathComponent.lowercased(), $0.lastPathComponent) })

        return counts
            .filter { $0.value > 1 }
            .compactMap { originalNames[$0.key] }
            .sorted()
    }

    private static func sanitizedArchiveInputName(for lastPathComponent: String) -> String {
        lastPathComponent.hasPrefix("-") ? "./" + lastPathComponent : lastPathComponent
    }

    private static func canonicalPathKey(for path: String) -> String {
        URL(fileURLWithPath: path).standardizedFileURL.path.lowercased()
    }

    private static func uniqueStandardizedFileURLs(from sourcePaths: [String]) -> [URL] {
        var seen: Set<String> = []

        return sourcePaths.compactMap { path in
            guard !path.isEmpty else {
                return nil
            }

            let url = URL(fileURLWithPath: path).standardizedFileURL
            let key = canonicalPathKey(for: url.path)
            guard seen.insert(key).inserted else {
                return nil
            }

            return url
        }
    }

    private static func runCommand(
        launchPath: String,
        arguments: [String],
        standardInput: String? = nil,
        currentDirectoryURL: URL? = nil
    ) -> AssistantCommandExecutionResult {
        let process = Process()
        let outputPipe = Pipe()
        let inputPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments
        process.currentDirectoryURL = currentDirectoryURL
        process.standardOutput = outputPipe
        process.standardError = outputPipe
        process.standardInput = inputPipe

        do {
            try process.run()

            if let standardInput {
                inputPipe.fileHandleForWriting.write(Data(standardInput.utf8))
            }
            try? inputPipe.fileHandleForWriting.close()

            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            return AssistantCommandExecutionResult(
                terminationStatus: process.terminationStatus,
                output: String(decoding: outputData, as: UTF8.self)
            )
        } catch {
            try? inputPipe.fileHandleForWriting.close()
            return AssistantCommandExecutionResult(
                terminationStatus: -1,
                output: error.localizedDescription
            )
        }
    }

    private static func uniqueTemporaryRenameURL(
        for sourceURL: URL,
        fileManager: FileManager
    ) -> URL {
        let directoryURL = sourceURL.deletingLastPathComponent()
        let baseName = ".assistant-renaming-\(UUID().uuidString)"
        var candidateURL = directoryURL.appendingPathComponent(baseName)
        var index = 1

        while fileManager.fileExists(atPath: candidateURL.path) {
            candidateURL = directoryURL.appendingPathComponent("\(baseName)-\(index)")
            index += 1
        }

        return candidateURL
    }

    private static func rollbackRenameRecords(
        finalizedRecords: [AssistantBatchRenameWorkRecord],
        stagedRecords: ArraySlice<AssistantBatchRenameWorkRecord>,
        fileManager: FileManager
    ) -> [String] {
        var rollbackMessages: [String] = []

        for record in finalizedRecords.reversed() {
            do {
                guard fileManager.fileExists(atPath: record.destinationURL.path) else {
                    continue
                }

                if fileManager.fileExists(atPath: record.sourceURL.path) {
                    rollbackMessages.append("\(record.sourceURL.lastPathComponent)：回滚时原名称已被占用")
                    continue
                }

                try fileManager.moveItem(at: record.destinationURL, to: record.sourceURL)
            } catch {
                rollbackMessages.append("\(record.sourceURL.lastPathComponent)：回滚失败，\(error.localizedDescription)")
            }
        }

        for record in stagedRecords.reversed() {
            do {
                guard fileManager.fileExists(atPath: record.temporaryURL.path) else {
                    continue
                }

                if fileManager.fileExists(atPath: record.sourceURL.path) {
                    rollbackMessages.append("\(record.sourceURL.lastPathComponent)：临时回滚时原名称已被占用")
                    continue
                }

                try fileManager.moveItem(at: record.temporaryURL, to: record.sourceURL)
            } catch {
                rollbackMessages.append("\(record.sourceURL.lastPathComponent)：临时回滚失败，\(error.localizedDescription)")
            }
        }

        return rollbackMessages
    }

    private static func removeEmptyFoldersAtCurrentLevel(
        in directoryURL: URL,
        preservingRoot: Bool,
        fileManager: FileManager
    ) throws -> Int {
        guard !Utils.isProtectedFolder(directoryURL.path) else {
            return 0
        }

        let resourceKeys: Set<URLResourceKey> = [
            .isDirectoryKey,
            .isPackageKey,
            .isSymbolicLinkKey
        ]

        let children = try fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: Array(resourceKeys),
            options: [.skipsPackageDescendants]
        )

        var removedCount = 0
        if preservingRoot {
            for childURL in children {
                let values = try childURL.resourceValues(forKeys: resourceKeys)
                guard values.isDirectory == true else {
                    continue
                }

                if values.isPackage == true || values.isSymbolicLink == true {
                    continue
                }

                if try isEmptyDirectory(childURL, fileManager: fileManager) {
                    try fileManager.trashItem(at: childURL, resultingItemURL: nil)
                    removedCount += 1
                }
            }
            return removedCount
        }

        guard try isEmptyDirectory(directoryURL, fileManager: fileManager) else {
            return removedCount
        }

        try fileManager.trashItem(at: directoryURL, resultingItemURL: nil)
        return removedCount + 1
    }

    private static func isEmptyDirectory(_ directoryURL: URL, fileManager: FileManager) throws -> Bool {
        let remainingChildren = try fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil,
            options: [.skipsPackageDescendants]
        )

        let blockingChildren = remainingChildren.filter { !isDisposableFinderMetadata($0) }
        return blockingChildren.isEmpty
    }

    private static func isDisposableFinderMetadata(_ url: URL) -> Bool {
        url.lastPathComponent == ".DS_Store"
    }
}
