//
//  AssistantStateSnapshotStore.swift
//  RightClickAssistantPro
//
//  Created by 老谭 on 2026/4/29.
//

import Foundation
import OrderedCollections

struct AssistantStateSnapshot {
    var apps: [OpenWithApplication]
    var dirs: [AuthorizedDirectory]
    var actions: [ContextQuickAction]
    var newFiles: [NewFileTemplate]
    var folderIcons: [FolderIconTemplate]
    var cdirs: [FavoriteDirectory]
}

@MainActor
final class AssistantStateSnapshotStore {
    static let shared = AssistantStateSnapshotStore()

    @AssistantLogger(category: "AssistantStateSnapshotStore")
    private var logger

    private let defaults: UserDefaults
    private let recoveryCoordinator: AuthorizedDirectoryRecoveryCoordinator
    private let encoder = PropertyListEncoder()
    private let decoder = PropertyListDecoder()
    private let newFileDefaultEnableMigrationKey = "RCLICK_NEW_FILE_DEFAULTS_ENABLED_20260513"

    init(
        defaults: UserDefaults = .group,
        recoveryCoordinator: AuthorizedDirectoryRecoveryCoordinator = .shared
    ) {
        self.defaults = defaults
        self.recoveryCoordinator = recoveryCoordinator
    }

    func load(inExtension: Bool) throws -> AssistantStateSnapshot {
        discardLegacySystemDiskAuthorization()
        let directories = try loadAuthorizedDirectoriesIfNeeded(inExtension: inExtension)

        return AssistantStateSnapshot(
            apps: try loadApplications(),
            dirs: directories,
            actions: try loadActions(),
            newFiles: try loadNewFileTemplates(),
            folderIcons: try loadFolderIcons(),
            cdirs: try loadFavoriteDirectories()
        )
    }

    func loadAuthorizedDirectoriesForFinderScope() -> [AuthorizedDirectory] {
        discardLegacySystemDiskAuthorization()

        do {
            return try loadAuthorizedDirectoriesIfNeeded(inExtension: false)
        } catch {
            logger.warning("Failed to load authorized directories for Finder scope: \(error.localizedDescription)")
            return []
        }
    }

    func save(_ snapshot: AssistantStateSnapshot) throws {
        try persist(snapshot.apps, forKey: SharedPreferenceKey.apps)
        try persist(snapshot.actions, forKey: SharedPreferenceKey.actions)
        try persist(snapshot.newFiles, forKey: SharedPreferenceKey.fileTypes)
        try persist(snapshot.folderIcons, forKey: SharedPreferenceKey.folderIcons)
        try persist(snapshot.dirs, forKey: SharedPreferenceKey.permDirs)
        discardLegacySystemDiskAuthorization()
        try persist(snapshot.cdirs, forKey: SharedPreferenceKey.commonDirs)
    }

    func saveAuthorizedDirectories(_ directories: [AuthorizedDirectory]) throws {
        try persist(directories, forKey: SharedPreferenceKey.permDirs)
    }

    private func discardLegacySystemDiskAuthorization() {
        if defaults.object(forKey: SharedPreferenceKey.authorizedSystemDisk) != nil {
            defaults.removeObject(forKey: SharedPreferenceKey.authorizedSystemDisk)
            logger.info("Removed legacy full-file-access authorization from shared defaults")
        }
    }

    func saveFavoriteDirectories(_ directories: [FavoriteDirectory]) throws {
        try persist(directories, forKey: SharedPreferenceKey.commonDirs)
    }

    func saveFolderIcons(_ folderIcons: [FolderIconTemplate]) throws {
        try persist(folderIcons, forKey: SharedPreferenceKey.folderIcons)
    }

    private func loadAuthorizedDirectoriesIfNeeded(inExtension: Bool) throws -> [AuthorizedDirectory] {
        guard !inExtension else {
            return []
        }

        if let permDirsData = defaults.data(forKey: SharedPreferenceKey.permDirs) {
            let directories = try decoder.decode([AuthorizedDirectory].self, from: permDirsData)
            logger.info("Loaded authorized directories from shared defaults")
            return directories
        }

        logger.warning("Missing authorized directories in shared defaults, attempting recovery from shared model store")
        let recoveredDirectories = recoveryCoordinator.recoverDirectories()
        if !recoveredDirectories.isEmpty {
            logger.info("Recovered \(recoveredDirectories.count) authorized directories from shared model store")
            do {
                try saveAuthorizedDirectories(recoveredDirectories)
            } catch {
                logger.error("Failed to persist recovered authorized directories: \(error.localizedDescription)")
            }
        }
        return recoveredDirectories
    }

    private func loadFavoriteDirectories() throws -> [FavoriteDirectory] {
        guard let data = defaults.data(forKey: SharedPreferenceKey.commonDirs) else {
            logger.warning("Missing favorite directories, using empty state")
            return []
        }

        let directories = try decoder.decode([FavoriteDirectory].self, from: data)
        logger.info("Loaded favorite directories")
        return directories
    }

    private func loadActions() throws -> [ContextQuickAction] {
        guard let data = defaults.data(forKey: SharedPreferenceKey.actions) else {
            logger.warning("Missing quick actions, using defaults")
            return ContextQuickAction.all
        }

        let savedActions = try decoder.decode([ContextQuickAction].self, from: data)
        let mergedActions = mergeLoadedActions(savedActions)

        if mergedActions != savedActions {
            logger.info("Quick actions changed after merge; persisting updated defaults")
            try? persist(mergedActions, forKey: SharedPreferenceKey.actions)
        } else {
            logger.info("Loaded quick actions")
        }

        return mergedActions
    }

    private func loadNewFileTemplates() throws -> [NewFileTemplate] {
        guard let data = defaults.data(forKey: SharedPreferenceKey.fileTypes) else {
            logger.warning("Missing new file templates, using defaults")
            return NewFileTemplate.all
        }

        let savedTemplates = try decoder.decode([NewFileTemplate].self, from: data)
        logger.info("Loaded new file templates")
        let mergedTemplates = mergeLoadedNewFiles(savedTemplates)
        let migratedTemplates = migrateDefaultNewFileTemplatesEnabledIfNeeded(mergedTemplates)
        try? persist(migratedTemplates, forKey: SharedPreferenceKey.fileTypes)
        return migratedTemplates
    }

    private func loadFolderIcons() throws -> [FolderIconTemplate] {
        guard let data = defaults.data(forKey: SharedPreferenceKey.folderIcons) else {
            logger.warning("Missing folder icons, using defaults")
            return FolderIconTemplate.all
        }

        let savedIcons = try decoder.decode([FolderIconTemplate].self, from: data)
        logger.info("Loaded folder icons")
        return mergeLoadedFolderIcons(savedIcons)
    }

    private func loadApplications() throws -> [OpenWithApplication] {
        guard let data = defaults.data(forKey: SharedPreferenceKey.apps) else {
            logger.warning("Missing open-with apps, using defaults")
            return OpenWithApplication.defaultApps
        }

        let applications = try decoder.decode([OpenWithApplication].self, from: data)
        let mergedApplications = mergeLoadedApplications(applications)

        if mergedApplications != applications {
            logger.info("Open-with apps changed after merge; persisting updated defaults")
            try? persist(mergedApplications, forKey: SharedPreferenceKey.apps)
        } else {
            logger.info("Loaded open-with apps")
        }

        return mergedApplications
    }

    private func persist<T: Codable & Hashable>(_ items: [T], forKey key: String) throws {
        let data = try encoder.encode(OrderedSet(items))
        defaults.set(data, forKey: key)
    }

    private func mergeLoadedActions(_ loadedActions: [ContextQuickAction]) -> [ContextQuickAction] {
        let loadedByID = Dictionary(uniqueKeysWithValues: loadedActions.map { ($0.id, $0) })

        return ContextQuickAction.all.map { defaultAction in
            guard let loaded = loadedByID[defaultAction.id] else {
                return defaultAction
            }

            return ContextQuickAction(
                id: defaultAction.id,
                name: defaultAction.name,
                enabled: loaded.enabled,
                idx: defaultAction.idx,
                icon: defaultAction.icon
            )
        }
    }

    private func mergeLoadedNewFiles(_ loadedNewFiles: [NewFileTemplate]) -> [NewFileTemplate] {
        let loadedByID = Dictionary(uniqueKeysWithValues: loadedNewFiles.map { ($0.id, $0) })
        let loadedByExtension = Dictionary(
            loadedNewFiles.map { (normalizeFileExtension($0.ext), $0) },
            uniquingKeysWith: { first, _ in first }
        )

        let mergedDefaults = NewFileTemplate.all.map { defaultTemplate in
            let loaded = loadedByID[defaultTemplate.id]
                ?? loadedByExtension[normalizeFileExtension(defaultTemplate.ext)]

            guard let loaded else {
                return defaultTemplate
            }

            var merged = defaultTemplate
            merged.name = loaded.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? defaultTemplate.name
                : loaded.name
            merged.enabled = loaded.enabled
            merged.openApp = loaded.openApp
            merged.template = loaded.template
            merged.showInMainMenu = loaded.showInMainMenu
            return merged
        }

        let defaultExtensions = Set(NewFileTemplate.all.map { normalizeFileExtension($0.ext) })
        let customTemplates = loadedNewFiles
            .filter { !defaultExtensions.contains(normalizeFileExtension($0.ext)) }
            .filter { !$0.id.hasPrefix("builtin-newfile-") }
            .map { item in
                var normalized = item
                normalized.ext = normalizeFileExtension(item.ext)
                return normalized
            }

        return mergedDefaults + customTemplates
    }

    private func migrateDefaultNewFileTemplatesEnabledIfNeeded(_ templates: [NewFileTemplate]) -> [NewFileTemplate] {
        guard !defaults.bool(forKey: newFileDefaultEnableMigrationKey) else {
            return templates
        }

        var updatedTemplates = templates
        for index in updatedTemplates.indices where updatedTemplates[index].id.hasPrefix("builtin-newfile-") {
            updatedTemplates[index].enabled = true
        }
        defaults.set(true, forKey: newFileDefaultEnableMigrationKey)
        return updatedTemplates
    }

    private func mergeLoadedFolderIcons(_ loadedIcons: [FolderIconTemplate]) -> [FolderIconTemplate] {
        let loadedByID = Dictionary(uniqueKeysWithValues: loadedIcons.map { ($0.id, $0) })
        let mergedDefaults = FolderIconTemplate.all.map { defaultIcon in
            guard let loaded = loadedByID[defaultIcon.id] else {
                return defaultIcon
            }

            return FolderIconTemplate(
                id: defaultIcon.id,
                name: loaded.name,
                enabled: loaded.enabled,
                assetName: defaultIcon.assetName,
                imagePath: defaultIcon.imagePath,
                pixelSize: defaultIcon.pixelSize,
                idx: defaultIcon.idx,
                isBuiltIn: defaultIcon.isBuiltIn
            )
        }

        let defaultIDs = Set(FolderIconTemplate.all.map(\.id))
        let customIcons = loadedIcons.filter { !defaultIDs.contains($0.id) }
        return mergedDefaults + customIcons
    }

    private func mergeLoadedApplications(_ loadedApplications: [OpenWithApplication]) -> [OpenWithApplication] {
        var mergedApplications = loadedApplications
        var knownApplicationPaths = Set(loadedApplications.map { $0.url.standardizedFileURL.path })

        for defaultApplication in OpenWithApplication.defaultApps {
            let path = defaultApplication.url.standardizedFileURL.path
            guard !knownApplicationPaths.contains(path) else {
                continue
            }

            mergedApplications.append(defaultApplication)
            knownApplicationPaths.insert(path)
        }

        return mergedApplications
    }

    private func normalizeFileExtension(_ ext: String) -> String {
        let trimmed = ext.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return trimmed }
        return trimmed.hasPrefix(".") ? trimmed : "." + trimmed
    }
}
