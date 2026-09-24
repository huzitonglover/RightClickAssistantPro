//
//  File.swift
//  RightClickAssistantPro
//
//  Created by 老谭 on 2026/4/30.
//

import Combine
import Foundation
import SwiftUI

@MainActor
final class AssistantRuntimeState: ObservableObject {
    static let shared = AssistantRuntimeState()

    @AssistantLogger(category: "AssistantRuntimeState")
    private var logger

    private let snapshotStore: AssistantStateSnapshotStore
    private let minimumRefreshInterval: TimeInterval
    private var activeSecurityScopedURLs: [URL] = []
    private var lastRefreshDate: Date?

    @Published var apps: [OpenWithApplication] = []
    @Published var dirs: [AuthorizedDirectory] = []
    @Published var actions: [ContextQuickAction] = []
    @Published var newFiles: [NewFileTemplate] = []
    @Published var folderIcons: [FolderIconTemplate] = []
    @Published var cdirs: [FavoriteDirectory] = []
    @Published var inExt: Bool

    @Published var showMenuBar: Bool = true

    init(
        inExt: Bool = false,
        snapshotStore: AssistantStateSnapshotStore? = nil,
        minimumRefreshInterval: TimeInterval = 0
    ) {
        self.inExt = inExt
        self.snapshotStore = snapshotStore ?? .shared
        self.minimumRefreshInterval = minimumRefreshInterval
        bootstrap()
    }

    func deleteApp(index: Int) {
        persistAfterMutation {
            apps.remove(at: index)
        }
    }

    func addApp(item: OpenWithApplication) {
        logger.info("start add app")
        persistAfterMutation {
            apps.append(item)
        }
    }

    func updateApp(id: String, itemName: String, arguments: [String], environment: [String: String]) {
        guard let appIndex = apps.firstIndex(where: { $0.id == id }) else {
            return
        }

        persistAfterMutation {
            apps[appIndex].itemName = itemName
            apps[appIndex].arguments = arguments
            apps[appIndex].environment = environment
        }
    }

    func getAppItem(rid: String) -> OpenWithApplication? {
        apps.first { rid.contains($0.id) }
    }

    func getFileType(rid: String) -> NewFileTemplate? {
        newFiles.first(where: { $0.id == rid })
    }

    func addNewFile(_ item: NewFileTemplate) {
        logger.info("start add new file type")
        persistAfterMutation {
            newFiles.append(item)
        }
    }

    func deleteNewFileTemplate(id: String) {
        persistAfterMutation {
            newFiles.removeAll { $0.id == id && !$0.id.hasPrefix("builtin-newfile-") }
        }
    }

    func getActionItem(rid: String) -> ContextQuickAction? {
        actions.first(where: { $0.id == rid })
    }

    func toggleActionItem() {
        persistState()
    }

    func resetActionItems() {
        replace(\.actions, with: ContextQuickAction.all)
    }

    func resetFiletypeItems() {
        replace(\.newFiles, with: NewFileTemplate.all)
    }

    func resetFolderIconItems() {
        replace(\.folderIcons, with: FolderIconTemplate.all)
    }

    func saveFolderIconItems() {
        persistState()
    }

    func deleteFolderIconItem(id: String) {
        persistAfterMutation {
            folderIcons.removeAll { $0.id == id && !$0.isBuiltIn }
        }
    }

    func deletePermissiveDir(index: Int) {
        persistAfterMutation {
            dirs.remove(at: index)
        }
    }

    var effectiveAuthorizedDirectories: [AuthorizedDirectory] {
        dirs
    }

    var effectiveAuthorizedDirectoryCount: Int {
        effectiveAuthorizedDirectories.count
    }

    func hasParentBookmark(of url: URL) -> Bool {
        let candidatePathComponents = normalizedPathComponents(for: url)
        return dirs.contains { directory in
            candidatePathComponents.starts(with: pathComponents(normalize: directory.url))
        }
    }

    private func save() throws {
        try snapshotStore.save(currentSnapshot())
    }

    func savePermissiveDir() throws {
        try snapshotStore.saveAuthorizedDirectories(dirs)
    }

    func saveCommonDir() throws {
        try snapshotStore.saveFavoriteDirectories(cdirs)
        logger.info("save common dirs success")
    }

    func refresh() {
        performStateOperation(label: "refresh") {
            try restoreFromPersistence()
        }
    }

    func refreshIfNeeded() {
        guard minimumRefreshInterval > 0 else {
            refresh()
            return
        }

        let now = Date()
        if let lastRefreshDate,
           now.timeIntervalSince(lastRefreshDate) < minimumRefreshInterval {
            logger.debug("skip refresh because cached state is still fresh")
            return
        }

        performStateOperation(label: "refreshIfNeeded") {
            try restoreFromPersistence()
        }
    }

    func sync() {
        performStateOperation(label: "sync") {
            try save()
        }
    }

    private func bootstrap() {
        logger.info("start load")
        performStateOperation(label: "bootstrap") {
            try restoreFromPersistence()
        }
    }

    private func restoreFromPersistence() throws {
        var snapshot = try snapshotStore.load(inExtension: inExt)
        if !inExt {
            snapshot.dirs = refreshPersistedBookmarksIfNeeded(snapshot.dirs)
        }
        apply(snapshot)
        lastRefreshDate = Date()

        guard !inExt else {
            deactivateSecurityScopedAccess()
            return
        }

        activateSecurityScopedAccess(for: effectiveAuthorizedDirectories)
    }

    private func activateSecurityScopedAccess(for dirs: [AuthorizedDirectory]) {
        deactivateSecurityScopedAccess()

        activeSecurityScopedURLs = dirs.compactMap(beginSecurityScopedAccess(for:))
    }

    private func deactivateSecurityScopedAccess() {
        for url in activeSecurityScopedURLs {
            url.stopAccessingSecurityScopedResource()
        }
        activeSecurityScopedURLs.removeAll(keepingCapacity: true)
    }

    private func beginSecurityScopedAccess(for directory: AuthorizedDirectory) -> URL? {
        do {
            let resolvedURL = try resolveBookmarkURL(for: directory)
            guard resolvedURL.startAccessingSecurityScopedResource() else {
                logger.warning("fail access scope \(directory.url.path)")
                return nil
            }

            logger.info("startAccessingSecurityScopedResource success")
            return resolvedURL
        } catch {
            logger.warning("failed to resolve bookmark for \(directory.url.path): \(error.localizedDescription)")
            return nil
        }
    }

    private func resolveBookmarkURL(for directory: AuthorizedDirectory) throws -> URL {
        var isStale = false
        return try URL(
            resolvingBookmarkData: directory.bookmark,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
    }

    private func refreshPersistedBookmarksIfNeeded(_ directories: [AuthorizedDirectory]) -> [AuthorizedDirectory] {
        var changed = false

        let refreshedDirectories = directories.map { directory in
            var isStale = false

            guard let resolvedURL = try? URL(
                resolvingBookmarkData: directory.bookmark,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) else {
                return directory
            }

            guard isStale else {
                return directory
            }

            logger.info("refresh stale bookmark for \(directory.url.path)")

            do {
                let bookmark = try AuthorizedDirectory.bookmarkData(for: resolvedURL)
                changed = true
                return AuthorizedDirectory(
                    id: directory.id,
                    url: resolvedURL,
                    bookmark: bookmark
                )
            } catch {
                logger.warning("failed to refresh stale bookmark for \(directory.url.path): \(error.localizedDescription)")
                return directory
            }
        }

        guard changed else {
            return directories
        }

        do {
            try snapshotStore.saveAuthorizedDirectories(refreshedDirectories)
        } catch {
            logger.warning("failed to persist refreshed bookmarks: \(error.localizedDescription)")
        }

        return refreshedDirectories
    }

    private func normalizedPathComponents(for url: URL) -> [String] {
        pathComponents(normalize: url)
    }

    private func pathComponents(normalize url: URL) -> [String] {
        url.standardizedFileURL
            .resolvingSymlinksInPath()
            .pathComponents
    }

    private func currentSnapshot() -> AssistantStateSnapshot {
        AssistantStateSnapshot(
            apps: apps,
            dirs: dirs,
            actions: actions,
            newFiles: newFiles,
            folderIcons: folderIcons,
            cdirs: cdirs
        )
    }

    private func apply(_ snapshot: AssistantStateSnapshot) {
        apps = snapshot.apps
        dirs = snapshot.dirs
        actions = snapshot.actions
        newFiles = snapshot.newFiles
        folderIcons = snapshot.folderIcons
        cdirs = snapshot.cdirs
    }

    private func replace<Value>(_ keyPath: ReferenceWritableKeyPath<AssistantRuntimeState, Value>, with value: Value) {
        persistAfterMutation {
            self[keyPath: keyPath] = value
        }
    }

    private func persistAfterMutation(_ changes: () -> Void) {
        changes()
        persistState()
    }

    private func persistState() {
        performStateOperation(label: "save") {
            try save()
        }
    }

    private func performStateOperation(label: String, action: () throws -> Void) {
        do {
            try action()
        } catch {
            logger.warning("\(label) error: \(error.localizedDescription)")
        }
    }
}
