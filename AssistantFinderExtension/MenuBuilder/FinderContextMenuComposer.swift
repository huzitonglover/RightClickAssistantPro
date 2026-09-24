//
//  FinderContextMenuComposer.swift
//  RightClickAssistantPro
//
//  Created by 老谭 on 2026/4/29.
//

import AppKit
import FinderSync
import Foundation
import UniformTypeIdentifiers

private let finderMenuComposerLogger = makeAssistantLogger(
    subsystem: Bundle.main.bundleIdentifier ?? "RightClickAssistantPro",
    category: "FinderMenuComposer"
)

struct FinderMenuActionTargets {
    let target: AnyObject
    let openAppSelector: Selector
    let openOpenWithSettingsSelector: Selector
    let openNewFileSettingsSelector: Selector
    let openFolderIconSettingsSelector: Selector
    let createFileSelector: Selector
    let openFavoriteFolderSelector: Selector
    let quickActionSelector: Selector
}

struct FinderCreateFileCommand {
    let templateID: String
    let targetPath: String
}

private struct FinderMenuSelectionProfile {
    let itemPaths: [String]

    var isEmpty: Bool {
        itemPaths.isEmpty
    }

    var allItemsAreFolders: Bool {
        !itemPaths.isEmpty && itemPaths.allSatisfy(isFolder)
    }

    var hasFileItems: Bool {
        itemPaths.contains { !isFolder($0) }
    }

    var allItemsAreImages: Bool {
        !itemPaths.isEmpty && itemPaths.allSatisfy(isImage)
    }

    var allItemsAreZIPArchives: Bool {
        !itemPaths.isEmpty && itemPaths.allSatisfy {
            URL(fileURLWithPath: $0).pathExtension.lowercased() == "zip"
        }
    }

    private func isFolder(_ path: String) -> Bool {
        let url = URL(fileURLWithPath: path)
        guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey, .isSymbolicLinkKey]) else {
            return false
        }

        return values.isDirectory == true
            && values.isPackage != true
            && values.isSymbolicLink != true
    }

    private func isImage(_ path: String) -> Bool {
        let url = URL(fileURLWithPath: path)
        guard let values = try? url.resourceValues(forKeys: [.contentTypeKey, .isDirectoryKey]),
              values.isDirectory != true,
              let contentType = values.contentType else {
            return false
        }

        return contentType.conforms(to: .image)
    }
}

@MainActor
struct FinderContextMenuComposer {
    private static let containerQuickActionIDs: [String] = [
        "take-screenshot",
        "lock-screen",
        "toggle-appearance",
        "paste",
        "undo-last",
        "clean-empty-folders",
        "open-terminal",
        "unhide"
    ]

    private static let hiddenQuickActionIDsForContainerMenu: Set<String> = [
        "copy-to",
        "move-to",
        "cut",
        "delete-direct",
        "airdrop",
        "batch-rename",
        "scan-qr-code",
        "encrypt-zip",
        "extract-zip",
        "extract-image-text",
        "send-shortcut-to-desktop",
        "dissolve-folder",
        "set-folder-icon-toolbar-advanced",
        "clear-custom-folder-icon"
    ]

    private static let pinnedItemQuickActionIDs: Set<String> = [
        "file-info",
        "airdrop",
        "dissolve-folder",
        "set-folder-icon-toolbar-advanced",
        "clear-custom-folder-icon",
    ]

    let appState: AssistantRuntimeState
    let menuKind: FIMenuKind
    let selectedItemPaths: [String]
    let selectedFolderPaths: [String]
    let actionTargets: FinderMenuActionTargets
    let makeTag: (String) -> Int
    let menuImage: (String, String) -> NSImage?
    let resolveCreateDestinationPath: () -> String?

    private var selectionProfile: FinderMenuSelectionProfile {
        FinderMenuSelectionProfile(itemPaths: selectedItemPaths)
    }

    private var hasUndoOperation: Bool {
        UserDefaults.group.data(forKey: SharedPreferenceKey.undoOperation) != nil
    }

    func makeMenu() -> NSMenu {
        let menu = NSMenu(title: AssistantLocalized.appName)

        let enabledTemplateCount = appState.newFiles.filter { $0.enabled }.count
        let enabledQuickActionCount = appState.actions.filter { $0.enabled && $0.isAvailableOnCurrentSystem }.count
        finderMenuComposerLogger.info(
            "compose menu kind=\(menuKindLogName, privacy: .public) apps=\(appState.apps.count) templates=\(enabledTemplateCount) favorites=\(appState.cdirs.count) quickActions=\(enabledQuickActionCount)"
        )

        if menuKind == .contextualMenuForContainer {
            let containerItems = containerMenuItems()
            containerItems.forEach(menu.addItem)
            finderMenuComposerLogger.info(
                "compose container-only result kind=\(menuKindLogName, privacy: .public) totalItems=\(containerItems.count)"
            )
            return menu
        }

        let menuRows = itemMenuRows
        let composedItems = menuRows.flatMap(menuItems(for:))
        composedItems.forEach(menu.addItem)

        finderMenuComposerLogger.info(
            "compose result kind=\(menuKindLogName, privacy: .public) rowCount=\(menuRows.count) totalItems=\(menu.items.count)"
        )
        return menu
    }

    private var itemMenuRows: [ToolboxSettingsRow] {
        ToolboxSettingsRow.loadOrder().filter { row in
            if case .quickAction(let identifier) = row {
                return ![
                    "set-folder-icon-toolbar-advanced",
                    "clear-custom-folder-icon"
                ].contains(identifier)
            }
            return true
        }
    }

    private var containerMenuRows: [ToolboxSettingsRow] {
        ToolboxSettingsRow.loadOrder().filter { row in
            switch row {
            case .menuGroup(let group):
                return group == .newFile || group == .folderIcon || group == .favoriteFolders
            case .quickAction(let identifier):
                if identifier == "undo-last", !hasUndoOperation {
                    return false
                }

                return Self.containerQuickActionIDs.contains(identifier)
                    && appState.actions.contains { $0.id == identifier && $0.enabled && $0.isAvailableOnCurrentSystem }
            }
        }
    }

    private var menuKindLogName: String {
        switch menuKind {
        case .contextualMenuForItems:
            "contextualMenuForItems"
        case .contextualMenuForContainer:
            "contextualMenuForContainer"
        case .contextualMenuForSidebar:
            "contextualMenuForSidebar"
        case .toolbarItemMenu:
            "toolbarItemMenu"
        @unknown default:
            "unknown"
        }
    }


    private func appMenuItems() -> [NSMenuItem] {
        guard UserDefaults.group.showOpenWithMenuGroup else {
            return []
        }

        let menuItem = NSMenuItem()
        menuItem.title = AssistantLocalized.text(zh: "打开方式", en: "Open With")
        menuItem.image = menuImage("square.grid.2x2", "app")

        let submenu = NSMenu(title: "Open With submenu")
        appState.apps.map(openWithApplicationMenuItem).forEach(submenu.addItem)
        submenu.addItem(openWithSettingsMenuItem())
        menuItem.submenu = submenu
        return [menuItem]
    }

    private func openWithApplicationMenuItem(for item: OpenWithApplication) -> NSMenuItem {
        let menuItem = NSMenuItem()
        menuItem.target = actionTargets.target
        menuItem.title = item.name
        menuItem.action = actionTargets.openAppSelector
        menuItem.toolTip = item.url.path
        menuItem.tag = makeTag(item.id)
        menuItem.image = AssistantFileIconCache.icon(forPath: item.url.path)
        return menuItem
    }

    private func openWithSettingsMenuItem() -> NSMenuItem {
        let menuItem = NSMenuItem()
        menuItem.target = actionTargets.target
        menuItem.title = AssistantLocalized.text(zh: "新增默认打开方式", en: "Add Default Open-With App")
        menuItem.action = actionTargets.openOpenWithSettingsSelector
        menuItem.toolTip = AssistantLocalized.text(
            zh: "打开 App 并进入“打开方式”设置",
            en: "Open the app and jump to Open With settings"
        )
        menuItem.image = menuImage("plus.app", "plus")
        return menuItem
    }

    private func quickActionItems() -> [NSMenuItem] {
        filteredQuickActions().map { item in
            makeQuickActionMenuItem(for: item)
        }
    }

    private func quickActionMenuItem(for identifier: String) -> NSMenuItem? {
        guard shouldShowQuickAction(identifier) else {
            return nil
        }

        guard let item = filteredQuickActions(includingPinnedItems: true).first(where: { $0.id == identifier }) else {
            return nil
        }

        return makeQuickActionMenuItem(for: item)
    }

    private func containerMenuItems() -> [NSMenuItem] {
        containerMenuRows.flatMap(menuItems(for:))
    }

    private func menuItems(for row: ToolboxSettingsRow) -> [NSMenuItem] {
        switch row {
        case .menuGroup(let group):
            switch group {
            case .openWith:
                return appMenuItems()
            case .newFile:
                return newFileMenuItems()
            case .folderIcon:
                return folderIconMenuItem().map { [$0] } ?? []
            case .favoriteFolders:
                return favoriteFoldersMenuItem().map { [$0] } ?? []
            case .copyPath:
                return copyPathMenuItem().map { [$0] } ?? []
            }

        case .quickAction(let identifier):
            if identifier == "dissolve-folder" {
                return dissolveFolderMenuItem().map { [$0] } ?? []
            }

            if identifier == "copy-name" {
                return copyNameMenuItem().map { [$0] } ?? []
            }

            if identifier == "share" {
                return shareMenuItem().map { [$0] } ?? []
            }

            return quickActionMenuItem(for: identifier).map { [$0] } ?? []
        }
    }

    private func makeQuickActionMenuItem(for item: ContextQuickAction) -> NSMenuItem {
        let menuItem = NSMenuItem()
        menuItem.target = actionTargets.target
        menuItem.title = menuTitle(for: item)
        menuItem.action = actionTargets.quickActionSelector
        menuItem.toolTip = item.displayName
        menuItem.tag = makeTag(item.id)
        menuItem.image = menuImage(item.icon, "doc")
        return menuItem
    }

    private func menuTitle(for item: ContextQuickAction) -> String {
        if menuKind == .contextualMenuForContainer, item.id == "open-terminal" {
            return AssistantLocalized.text(zh: "打开终端", en: "Open Terminal")
        }

        return item.displayName
    }

    private func shouldShowQuickAction(_ identifier: String) -> Bool {
        if menuKind == .contextualMenuForContainer {
            if identifier == "undo-last" {
                return hasUndoOperation
            }

            return Self.containerQuickActionIDs.contains(identifier)
        }

        let profile = selectionProfile
        switch identifier {
        case "scan-qr-code", "extract-image-text":
            return profile.allItemsAreImages
        case "extract-zip":
            return profile.allItemsAreZIPArchives
        default:
            return true
        }
    }

    private func filteredQuickActions(includingPinnedItems: Bool = false) -> [ContextQuickAction] {
        var enabledActions = appState.actions
            .filter(\.enabled)
            .filter(\.isAvailableOnCurrentSystem)
        if !includingPinnedItems {
            enabledActions.removeAll { Self.pinnedItemQuickActionIDs.contains($0.id) }
        }

        guard menuKind == .contextualMenuForContainer else {
            let enabledIDs = enabledActions.map(\.id).joined(separator: ",")
            finderMenuComposerLogger.debug(
                "quick actions unchanged kind=\(menuKindLogName, privacy: .public) ids=\(enabledIDs, privacy: .public)"
            )
            return enabledActions
        }

        let hiddenIDs = enabledActions
            .map(\.id)
            .filter { Self.hiddenQuickActionIDsForContainerMenu.contains($0) }
        let visibleActions = enabledActions.filter { !Self.hiddenQuickActionIDsForContainerMenu.contains($0.id) }
        let hiddenIDLog = hiddenIDs.joined(separator: ",")
        let visibleIDLog = visibleActions.map(\.id).joined(separator: ",")

        finderMenuComposerLogger.info(
            "container filter hidden=\(hiddenIDLog, privacy: .public) visible=\(visibleIDLog, privacy: .public)"
        )
        return visibleActions
    }

    private func copyNameMenuItem() -> NSMenuItem? {
        guard shouldShowQuickAction("copy-name"),
              filteredQuickActions(includingPinnedItems: true).contains(where: { $0.id == "copy-name" }) else {
            return nil
        }

        let profile = selectionProfile
        guard profile.hasFileItems else {
            return quickActionMenuItem(for: "copy-name")
        }

        let menuItem = NSMenuItem()
        menuItem.title = AssistantLocalized.text(zh: "复制名称", en: "Copy Name")
        menuItem.image = menuImage("doc.text", "doc")

        let submenu = NSMenu(title: "Copy Name submenu")

        let withoutExtensionItem = makeQuickActionMenuItem(for: ContextQuickAction.copyNameWithoutExtension)
        withoutExtensionItem.title = AssistantLocalized.text(zh: "复制名称", en: "Copy Name")
        withoutExtensionItem.toolTip = withoutExtensionItem.title
        submenu.addItem(withoutExtensionItem)

        let withExtensionItem = makeQuickActionMenuItem(for: ContextQuickAction.copyName)
        withExtensionItem.title = AssistantLocalized.text(zh: "复制名称（含后缀）", en: "Copy Name With Extension")
        withExtensionItem.toolTip = withExtensionItem.title
        submenu.addItem(withExtensionItem)

        menuItem.submenu = submenu
        return menuItem
    }

    private func shareMenuItem() -> NSMenuItem? {
        guard shouldShowQuickAction("share"),
              filteredQuickActions(includingPinnedItems: true).contains(where: { $0.id == "share" }) else {
            return nil
        }

        let menuItem = NSMenuItem()
        menuItem.title = AssistantLocalized.text(zh: "分享", en: "Share")
        menuItem.image = menuImage("square.and.arrow.up", "share")

        let submenu = NSMenu(title: "Share submenu")
        [
            ("share-airdrop", AssistantLocalized.text(zh: "隔空投送", en: "AirDrop"), "paperplane"),
            ("share-mail", AssistantLocalized.text(zh: "邮件", en: "Mail"), "envelope"),
            ("share-message", AssistantLocalized.text(zh: "信息", en: "Messages"), "message"),
            ("share-wechat", AssistantLocalized.text(zh: "微信", en: "WeChat"), "message.badge"),
            ("share-qq", AssistantLocalized.text(zh: "QQ", en: "QQ"), "bubble.left.and.bubble.right"),
            ("share-notes", AssistantLocalized.text(zh: "备忘录", en: "Notes"), "note.text")
        ].map(shareChildMenuItem).forEach(submenu.addItem)

        menuItem.submenu = submenu
        return menuItem
    }

    private func shareChildMenuItem(identifier: String, title: String, icon: String) -> NSMenuItem {
        let item = NSMenuItem()
        item.target = actionTargets.target
        item.title = title
        item.action = actionTargets.quickActionSelector
        item.toolTip = title
        item.tag = makeTag(identifier)
        item.image = menuImage(icon, "share")
        return item
    }

    private var shouldShowDissolveFolderMenu: Bool {
        menuKind == .contextualMenuForItems && !selectedFolderPaths.isEmpty
    }

    private func copyPathMenuItem() -> NSMenuItem? {
        guard UserDefaults.group.showCopyPathMenuGroup else {
            return nil
        }

        let menuItem = NSMenuItem()
        menuItem.title = AssistantLocalized.text(zh: "复制路径", en: "Copy Path")
        menuItem.image = menuImage("doc.on.doc", "doc")

        let submenu = NSMenu(title: "Copy Path submenu")
        [
            ContextQuickAction.copyPath,
            ContextQuickAction.copyParentPath,
            ContextQuickAction.copyShellPath,
            ContextQuickAction.copyFileURL
        ].map(makeQuickActionMenuItem).forEach(submenu.addItem)

        menuItem.submenu = submenu
        return menuItem
    }

    private func dissolveFolderMenuItem() -> NSMenuItem? {
        guard shouldShowDissolveFolderMenu else {
            return nil
        }

        return quickActionMenuItem(for: "dissolve-folder")
    }

    private var shouldShowFolderIconMenu: Bool {
        menuKind == .contextualMenuForItems && !selectedFolderPaths.isEmpty
    }

    private func folderIconMenuItem() -> NSMenuItem? {
        guard UserDefaults.group.showFolderIconMenuGroup, shouldShowFolderIconMenu else {
            return nil
        }

        let enabledIcons = appState.folderIcons
            .filter(\.enabled)
            .sorted { $0.idx < $1.idx }

        let menuItem = NSMenuItem()
        menuItem.title = AssistantLocalized.text(zh: "文件(夹)图标", en: "File/Folder Icon")
        menuItem.image = menuImage("folder", "folder")

        let submenu = NSMenu(title: "File and folder icon menu")
        enabledIcons.map(folderIconTemplateMenuItem).forEach(submenu.addItem)
        submenu.addItem(clearCustomFolderIconMenuItem())
        submenu.addItem(addCustomFolderIconMenuItem())
        menuItem.submenu = submenu
        return menuItem
    }

    private func clearCustomFolderIconMenuItem() -> NSMenuItem {
        let menuItem = NSMenuItem()
        menuItem.target = actionTargets.target
        menuItem.title = AssistantLocalized.text(zh: "恢复默认图标", en: "Restore Default Icon")
        menuItem.action = actionTargets.quickActionSelector
        menuItem.toolTip = menuItem.title
        menuItem.tag = makeTag("clear-custom-folder-icon")
        menuItem.image = menuImage("folder.badge.minus", "folder")
        return menuItem
    }

    private func addCustomFolderIconMenuItem() -> NSMenuItem {
        let menuItem = NSMenuItem()
        menuItem.target = actionTargets.target
        menuItem.title = AssistantLocalized.text(zh: "新增自定义图标", en: "Add Custom Icon")
        menuItem.action = actionTargets.openFolderIconSettingsSelector
        menuItem.toolTip = AssistantLocalized.text(
            zh: "打开 App 并进入“文件(夹)图标”设置",
            en: "Open the app and jump to File/Folder Icon settings"
        )
        menuItem.image = menuImage("plus.app", "plus")
        return menuItem
    }

    private func folderIconTemplateMenuItem(for item: FolderIconTemplate) -> NSMenuItem {
        let menuItem = NSMenuItem()
        menuItem.target = actionTargets.target
        menuItem.title = item.displayName
        menuItem.action = actionTargets.quickActionSelector
        menuItem.toolTip = item.displayName
        menuItem.tag = makeTag(item.actionIdentifier)
        menuItem.image = folderIconImage(for: item)
        return menuItem
    }

    private func folderIconImage(for item: FolderIconTemplate) -> NSImage? {
        guard UserDefaults.group.showFolderIconImages else {
            return menuImage("folder", "folder")
        }

        if let imagePath = item.imagePath,
           let image = NSImage(contentsOfFile: imagePath) {
            return image
        }

        if let image = NSImage(named: item.assetName) {
            image.isTemplate = false
            return image
        }

        return menuImage("folder", "folder")
    }

    private func favoriteFoldersMenuItem() -> NSMenuItem? {
        guard UserDefaults.group.showFavoriteFoldersMenuGroup else {
            return nil
        }

        let favoriteFolders = appState.cdirs
        guard !favoriteFolders.isEmpty else {
            return nil
        }

        let menuItem = NSMenuItem()
        menuItem.title = AssistantLocalized.text(zh: "常用目录", en: "Favorite Folders")
        menuItem.image = menuImage("folder.badge.questionmark", "folder")

        let submenu = NSMenu(title: "Favorite Folders submenu")
        favoriteFolders.forEach { directory in
            let child = NSMenuItem()
            child.target = actionTargets.target
            child.title = directory.name
            child.action = actionTargets.openFavoriteFolderSelector
            child.toolTip = directory.url.path
            child.tag = makeTag(directory.id)
            child.image = menuImage("folder", "folder")
            submenu.addItem(child)
        }

        menuItem.submenu = submenu
        return menuItem
    }

    private func newFileMenuItems() -> [NSMenuItem] {
        guard UserDefaults.group.showNewFileMenuGroup else {
            return []
        }

        let enabledTemplates = appState.newFiles.filter(\.enabled)

        let menuItem = NSMenuItem()
        menuItem.title = AssistantLocalized.text(zh: "新建文件", en: "New File")
        menuItem.image = menuImage("doc.badge.plus", "doc")

        let submenu = NSMenu(title: "file create menu")
        let createTargetPath = resolveCreateDestinationPath()
        enabledTemplates
            .map { makeNewFileChildMenuItem(for: $0, targetPath: createTargetPath) }
            .forEach(submenu.addItem)
        submenu.addItem(addCustomNewFileTemplateMenuItem())

        menuItem.submenu = submenu
        return [menuItem]
    }

    private func addCustomNewFileTemplateMenuItem() -> NSMenuItem {
        let child = NSMenuItem()
        child.target = actionTargets.target
        child.title = AssistantLocalized.text(zh: "新建自定义模版", en: "Add Custom Template")
        child.action = actionTargets.openNewFileSettingsSelector
        child.toolTip = AssistantLocalized.text(
            zh: "打开 App 并进入“新建文件”设置",
            en: "Open the app and jump to New File settings"
        )
        child.image = menuImage("plus.app", "plus")
        return child
    }

    private func makeNewFileChildMenuItem(for item: NewFileTemplate, targetPath: String?) -> NSMenuItem {
        let child = NSMenuItem()
        child.target = actionTargets.target
        child.title = item.displayName
        child.action = actionTargets.createFileSelector
        child.toolTip = item.displayName
        child.tag = makeTag(item.id)
        if let targetPath {
            child.representedObject = FinderCreateFileCommand(
                templateID: item.id,
                targetPath: targetPath
            )
        }

        guard UserDefaults.group.showNewFileTemplateImages else {
            return child
        }

        if let app = item.openApp {
            child.image = AssistantFileIconCache.icon(forPath: app.path)
            child.image?.isTemplate = true
        } else if item.icon.starts(with: "icon-"), let image = NSImage(named: item.icon) {
            child.image = image
            child.image?.isTemplate = true
        } else {
            child.image = menuImage(item.icon, "doc")
        }

        return child
    }
}
