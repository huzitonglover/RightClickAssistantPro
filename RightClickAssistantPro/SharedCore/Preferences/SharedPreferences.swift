//
//  StringExtension.swift
//  RightClickAssistantPro
//
//  Created by 老谭 on 2026/4/30.
//

import Foundation

import os.log

private enum AssistantPreferenceCatalog {
    enum Interface {
        static let contextualItemMenu = "SHOW_CONTEXTUAL_MENU_FOR_ITEM"
        static let contextualContainerMenu = "SHOW_CONTEXTUAL_MENU_FOR_CONTAINER"
        static let sidebarContextMenu = "SHOW_CONTEXTUAL_MENU_FOR_SIDEBAR"
        static let toolbarMenu = "SHOW_TOOLBAR_ITEM_MENU"
        static let extensionEnabled = "extensionEnabled"
        static let dockIcon = "SHOW_DOCK_ICON"
        static let applicationSubmenu = "SHOW_SUB_MENU_FOR_APPLICATION"
        static let actionSubmenu = "SHOW_SUB_MENU_FOR_ACTION"
        static let menuBarExtra = "showMenuBarExtra"
        static let dockPresence = "SHOW_IN_DOCK"
        static let appLanguage = "APP_LANGUAGE"
        static let launchAtLoginInitialized = "LAUNCH_AT_LOGIN_INITIALIZED"
        static let launchAtLoginUserConfigured = "LAUNCH_AT_LOGIN_USER_CONFIGURED"
        static let accessibilityPermissionEnabled = "ACCESSIBILITY_PERMISSION_ENABLED"
        static let inputMonitoringPermissionEnabled = "INPUT_MONITORING_PERMISSION_ENABLED"
        static let automationPermissionEnabled = "AUTOMATION_PERMISSION_ENABLED"
    }

    enum LaunchConfiguration {
        static let arguments = "GLOBAL_APPLICATION_ARGUMENTS_STRING"
        static let environment = "GLOBAL_APPLICATION_ENVIRONMENT_STRING"
    }

    enum TemplateCreation {
        static let separator = "COPY_SEPARATOR"
        static let name = "NEW_FILE_NAME"
        static let fileExtension = "NEW_FILE_EXTENSION"
    }

    enum Messaging {
        static let finderToMain = "RCLICK_FINDER_Main"
        static let mainToFinder = "RCLICK_MAIN_FINDER"
        static let finderExtensionHeartbeat = "RCLICK_FINDER_EXTENSION_HEARTBEAT"
    }

    enum Persistence {
        static let applications = "RCLICK_APPs"
        static let actions = "RCLICK_ACTIONS"
        static let fileTypes = "RCLICK_FILE_TYPES"
        static let folderIcons = "RCLICK_FOLDER_ICONS"
        static let authorizedDirectories = "RCLICK_PERMISSIVE_DIRS"
        static let authorizedSystemDisk = "RCLICK_AUTHORIZED_SYSTEM_DISK"
        static let favoriteDirectories = "RCLICK_COMMON_DIRS"
        static let clipboardOperation = "RCLICK_CLIPBOARD_OPERATION"
        static let undoOperation = "RCLICK_UNDO_OPERATION"
        static let accessSnapshot = "RCLICK_ACCESS_SNAPSHOT"
        static let showFolderIconImages = "RCLICK_SHOW_FOLDER_ICON_IMAGES"
        static let showNewFileTemplateImages = "RCLICK_SHOW_NEW_FILE_TEMPLATE_IMAGES"
        static let showOpenWithMenuGroup = "RCLICK_SHOW_OPEN_WITH_MENU_GROUP"
        static let showNewFileMenuGroup = "RCLICK_SHOW_NEW_FILE_MENU_GROUP"
        static let showFolderIconMenuGroup = "RCLICK_SHOW_FOLDER_ICON_MENU_GROUP"
        static let showFavoriteFoldersMenuGroup = "RCLICK_SHOW_FAVORITE_FOLDERS_MENU_GROUP"
        static let showCopyPathMenuGroup = "RCLICK_SHOW_COPY_PATH_MENU_GROUP"
        static let toolboxMenuOrder = "RCLICK_TOOLBOX_MENU_ORDER"
        static let newFileCreationSoundEnabled = "RCLICK_NEW_FILE_CREATION_SOUND_ENABLED"
        static let openNewFileAfterCreation = "RCLICK_OPEN_NEW_FILE_AFTER_CREATION"
    }
}

private let preferenceLog = makeAssistantLogger(
    subsystem: Bundle.main.bundleIdentifier ?? "rightPro.touch.assistant",
    category: "preferences"
)

enum SharedPreferenceKey {
    static var showContextualMenuForItem: String { AssistantPreferenceCatalog.Interface.contextualItemMenu }
    static var showContextualMenuForContainer: String { AssistantPreferenceCatalog.Interface.contextualContainerMenu }
    static var showContextualMenuForSidebar: String { AssistantPreferenceCatalog.Interface.sidebarContextMenu }
    static var showToolbarItemMenu: String { AssistantPreferenceCatalog.Interface.toolbarMenu }
    static var extensionEnabled: String { AssistantPreferenceCatalog.Interface.extensionEnabled }
    static var showDockIcon: String { AssistantPreferenceCatalog.Interface.dockIcon }

    static var globalApplicationArgumentsString: String { AssistantPreferenceCatalog.LaunchConfiguration.arguments }
    static var globalApplicationEnvironmentString: String { AssistantPreferenceCatalog.LaunchConfiguration.environment }

    static var copySeparator: String { AssistantPreferenceCatalog.TemplateCreation.separator }
    static var newFileName: String { AssistantPreferenceCatalog.TemplateCreation.name }
    static var newFileExtension: String { AssistantPreferenceCatalog.TemplateCreation.fileExtension }

    static var showSubMenuForApplication: String { AssistantPreferenceCatalog.Interface.applicationSubmenu }
    static var showSubMenuForAction: String { AssistantPreferenceCatalog.Interface.actionSubmenu }
    static var messageFromFinder: String { AssistantPreferenceCatalog.Messaging.finderToMain }
    static var messageFromMain: String { AssistantPreferenceCatalog.Messaging.mainToFinder }
    static var finderExtensionHeartbeat: String { AssistantPreferenceCatalog.Messaging.finderExtensionHeartbeat }

    static var apps: String { AssistantPreferenceCatalog.Persistence.applications }
    static var actions: String { AssistantPreferenceCatalog.Persistence.actions }
    static var fileTypes: String { AssistantPreferenceCatalog.Persistence.fileTypes }
    static var folderIcons: String { AssistantPreferenceCatalog.Persistence.folderIcons }
    static var permDirs: String { AssistantPreferenceCatalog.Persistence.authorizedDirectories }
    static var authorizedSystemDisk: String { AssistantPreferenceCatalog.Persistence.authorizedSystemDisk }
    static var commonDirs: String { AssistantPreferenceCatalog.Persistence.favoriteDirectories }
    static var clipboardOperation: String { AssistantPreferenceCatalog.Persistence.clipboardOperation }
    static var undoOperation: String { AssistantPreferenceCatalog.Persistence.undoOperation }
    static var accessSnapshot: String { AssistantPreferenceCatalog.Persistence.accessSnapshot }
    static var showFolderIconImages: String { AssistantPreferenceCatalog.Persistence.showFolderIconImages }
    static var showNewFileTemplateImages: String { AssistantPreferenceCatalog.Persistence.showNewFileTemplateImages }
    static var showOpenWithMenuGroup: String { AssistantPreferenceCatalog.Persistence.showOpenWithMenuGroup }
    static var showNewFileMenuGroup: String { AssistantPreferenceCatalog.Persistence.showNewFileMenuGroup }
    static var showFolderIconMenuGroup: String { AssistantPreferenceCatalog.Persistence.showFolderIconMenuGroup }
    static var showFavoriteFoldersMenuGroup: String { AssistantPreferenceCatalog.Persistence.showFavoriteFoldersMenuGroup }
    static var showCopyPathMenuGroup: String { AssistantPreferenceCatalog.Persistence.showCopyPathMenuGroup }
    static var toolboxMenuOrder: String { AssistantPreferenceCatalog.Persistence.toolboxMenuOrder }
    static var newFileCreationSoundEnabled: String { AssistantPreferenceCatalog.Persistence.newFileCreationSoundEnabled }
    static var openNewFileAfterCreation: String { AssistantPreferenceCatalog.Persistence.openNewFileAfterCreation }
    static var showMenuBarExtra: String { AssistantPreferenceCatalog.Interface.menuBarExtra }
    static var showInDock: String { AssistantPreferenceCatalog.Interface.dockPresence }
    static var appLanguage: String { AssistantPreferenceCatalog.Interface.appLanguage }
    static var launchAtLoginInitialized: String { AssistantPreferenceCatalog.Interface.launchAtLoginInitialized }
    static var launchAtLoginUserConfigured: String { AssistantPreferenceCatalog.Interface.launchAtLoginUserConfigured }
    static var accessibilityPermissionEnabled: String { AssistantPreferenceCatalog.Interface.accessibilityPermissionEnabled }
    static var inputMonitoringPermissionEnabled: String { AssistantPreferenceCatalog.Interface.inputMonitoringPermissionEnabled }
    static var automationPermissionEnabled: String { AssistantPreferenceCatalog.Interface.automationPermissionEnabled }
}

enum TemplateExtensionOption: String, CaseIterable, Identifiable {
    var id: String { rawValue }
    case none = "(none)"
    case swift
    case txt
}

var subsystem: String {
    Bundle.main.bundleIdentifier ?? "rightPro.touch.assistant"
}

private enum KeyValueTextCodec {
    static func decode(_ value: String, separator: Character) -> [String: String] {
        var pairs: [String: String] = [:]

        for segment in value.split(separator: separator, omittingEmptySubsequences: true) {
            guard let delimiter = segment.firstIndex(of: "=") else {
                continue
            }

            let key = segment[..<delimiter].trimmingCharacters(in: .whitespacesAndNewlines)
            let rawValue = segment[segment.index(after: delimiter)...]
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard !key.isEmpty else {
                continue
            }
            pairs[key] = rawValue
        }

        return pairs
    }

    static func encode(_ dictionary: [String: String], separator: String) -> String {
        dictionary
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: separator)
    }
}

private final class LocalizationReverseLookup {
    static let shared = LocalizationReverseLookup()

    private var cache: [String: [String: String]] = [:]

    func localizedValueToKeyMap(tableName: String, bundle: Bundle) -> [String: String] {
        let cacheKey = "\(bundle.bundlePath)#\(tableName)"
        if let cached = cache[cacheKey] {
            return cached
        }

        let fileURL = bundle.url(forResource: tableName, withExtension: "strings")
        let content = fileURL.flatMap(NSDictionary.init(contentsOf:)) as? [String: String] ?? [:]
        let reversed = content.reduce(into: [String: String]()) { result, entry in
            result[entry.value] = entry.key
        }
        cache[cacheKey] = reversed
        return reversed
    }
}

extension String {
    func toDictionary(separator: Character = " ") -> [String: String] {
        KeyValueTextCodec.decode(self, separator: separator)
    }

    static func key(forLocalizedString localizedString: String, in tableName: String, bundle: Bundle = .main) -> String? {
        LocalizationReverseLookup.shared
            .localizedValueToKeyMap(tableName: tableName, bundle: bundle)[localizedString]
    }
}

extension Dictionary where Key == String, Value == String {
    func toString(separator: String = " ") -> String {
        KeyValueTextCodec.encode(self, separator: separator)
    }
}

private enum PreferenceFallback {
    static let contextualMenuVisible = true
    static let submenuCollapsed = false
    static let defaultFileName = "Untitled"
    static let defaultSeparator = " "
    static let folderIconImagesVisible = true
    static let newFileTemplateImagesVisible = true
    static let menuGroupVisible = true
    static let newFileCreationSoundEnabled = true
    static let openNewFileAfterCreation = false
}

private struct SharedPreferenceReader {
    let defaults: UserDefaults

    func bool(_ key: String, fallback: Bool) -> Bool {
        typedValue(for: key, fallback: fallback)
    }

    func string(_ key: String, fallback: String = "") -> String {
        typedValue(for: key, fallback: fallback)
    }

    private func typedValue<T>(for key: String, fallback: T) -> T {
        guard let value = defaults.object(forKey: key) as? T else {
            preferenceLog.debug("Missing preference for \(key); using fallback value")
            return fallback
        }
        return value
    }
}

extension UserDefaults {
    private static let cachedGroupDefaults: UserDefaults = {
        guard let defaults = UserDefaults(suiteName: Constants.appGroupIdentifier) else {
            preferenceLog.error("Failed to create shared UserDefaults suite: \(Constants.appGroupIdentifier)")
            return .standard
        }

        return defaults
    }()

    static var group: UserDefaults {
        cachedGroupDefaults
    }

    var showContextualMenuForItem: Bool {
        reader.bool(SharedPreferenceKey.showContextualMenuForItem, fallback: PreferenceFallback.contextualMenuVisible)
    }

    var showContextualMenuForContainer: Bool {
        reader.bool(SharedPreferenceKey.showContextualMenuForContainer, fallback: PreferenceFallback.contextualMenuVisible)
    }

    var showContextualMenuForSidebar: Bool {
        reader.bool(SharedPreferenceKey.showContextualMenuForSidebar, fallback: PreferenceFallback.contextualMenuVisible)
    }

    var showToolbarItemMenu: Bool {
        reader.bool(SharedPreferenceKey.showToolbarItemMenu, fallback: PreferenceFallback.contextualMenuVisible)
    }

    var copySeparator: String {
        let separator = reader.string(SharedPreferenceKey.copySeparator)
        return separator.isEmpty ? PreferenceFallback.defaultSeparator : separator
    }

    var newFileName: String {
        let title = reader.string(SharedPreferenceKey.newFileName)
        return title.isEmpty ? PreferenceFallback.defaultFileName : title
    }

    var newFileExtension: TemplateExtensionOption {
        let fileExtensionRaw = reader.string(SharedPreferenceKey.newFileExtension)
        return TemplateExtensionOption(rawValue: fileExtensionRaw) ?? .none
    }

    var showFolderIconImages: Bool {
        reader.bool(SharedPreferenceKey.showFolderIconImages, fallback: PreferenceFallback.folderIconImagesVisible)
    }

    var showNewFileTemplateImages: Bool {
        reader.bool(SharedPreferenceKey.showNewFileTemplateImages, fallback: PreferenceFallback.newFileTemplateImagesVisible)
    }

    var showOpenWithMenuGroup: Bool {
        reader.bool(SharedPreferenceKey.showOpenWithMenuGroup, fallback: PreferenceFallback.menuGroupVisible)
    }

    var showNewFileMenuGroup: Bool {
        reader.bool(SharedPreferenceKey.showNewFileMenuGroup, fallback: PreferenceFallback.menuGroupVisible)
    }

    var showFolderIconMenuGroup: Bool {
        reader.bool(SharedPreferenceKey.showFolderIconMenuGroup, fallback: PreferenceFallback.menuGroupVisible)
    }

    var showFavoriteFoldersMenuGroup: Bool {
        reader.bool(SharedPreferenceKey.showFavoriteFoldersMenuGroup, fallback: PreferenceFallback.menuGroupVisible)
    }

    var showCopyPathMenuGroup: Bool {
        reader.bool(SharedPreferenceKey.showCopyPathMenuGroup, fallback: PreferenceFallback.menuGroupVisible)
    }

    var newFileCreationSoundEnabled: Bool {
        reader.bool(SharedPreferenceKey.newFileCreationSoundEnabled, fallback: PreferenceFallback.newFileCreationSoundEnabled)
    }

    var openNewFileAfterCreation: Bool {
        reader.bool(SharedPreferenceKey.openNewFileAfterCreation, fallback: PreferenceFallback.openNewFileAfterCreation)
    }

    var showSubMenuForApplication: Bool {
        reader.bool(SharedPreferenceKey.showSubMenuForApplication, fallback: PreferenceFallback.submenuCollapsed)
    }

    var showSubMenuForAction: Bool {
        reader.bool(SharedPreferenceKey.showSubMenuForAction, fallback: PreferenceFallback.submenuCollapsed)
    }

    private var reader: SharedPreferenceReader {
        SharedPreferenceReader(defaults: self)
    }
}
