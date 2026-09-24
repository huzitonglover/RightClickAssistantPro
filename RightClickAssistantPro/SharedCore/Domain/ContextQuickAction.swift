//
//  ContextQuickAction.swift
//  RightClickAssistantPro
//
//  Created by 老谭 on 2026/4/30.
//

import Foundation

private struct AssistantActionRecipe {
    let slot: Int
    let identifier: String
    let title: String
    let symbolName: String
}

private enum ContextQuickActionCatalog {
    static let recipes: [AssistantActionRecipe] = [
        .init(slot: 0, identifier: "copy-path", title: "Copy Path", symbolName: "doc.on.doc"),
        .init(slot: 1, identifier: "copy-name", title: "Copy Name", symbolName: "doc.text"),
        .init(slot: 2, identifier: "copy-name-no-ext", title: "Copy Name Without Extension", symbolName: "textformat"),
        .init(slot: 3, identifier: "copy-parent-path", title: "Copy Parent Path", symbolName: "folder"),
        .init(slot: 4, identifier: "copy-shell-path", title: "Copy Shell Path", symbolName: "terminal"),
        .init(slot: 5, identifier: "copy-file-url", title: "Copy File URL", symbolName: "link"),
        .init(slot: 6, identifier: "send-shortcut-to-desktop", title: "发送快捷方式到桌面", symbolName: "arrow.up.doc"),
        .init(slot: 7, identifier: "lock-screen", title: "锁定屏幕", symbolName: "lock"),
        .init(slot: 8, identifier: "take-screenshot", title: "截图", symbolName: "crop"),
        .init(slot: 9, identifier: "encrypt-zip", title: "加密压缩", symbolName: "lock.doc"),
        .init(slot: 10, identifier: "extract-zip", title: "解压 ZIP", symbolName: "archivebox"),
        .init(slot: 11, identifier: "file-info", title: "File Info Center", symbolName: "info.circle"),
        .init(slot: 12, identifier: "copy-to", title: "Copy To", symbolName: "folder.badge.plus"),
        .init(slot: 13, identifier: "move-to", title: "Cut", symbolName: "scissors"),
        .init(slot: 14, identifier: "cut", title: "Cut", symbolName: "scissors"),
        .init(slot: 15, identifier: "paste", title: "Paste", symbolName: "clipboard"),
        .init(slot: 16, identifier: "undo-last", title: "Undo Last Operation", symbolName: "arrow.uturn.backward"),
        .init(slot: 17, identifier: "delete-direct", title: "Delete Direct", symbolName: "trash"),
        .init(slot: 18, identifier: "airdrop", title: "隔空投送", symbolName: "paperplane"),
        .init(slot: 19, identifier: "share", title: "分享", symbolName: "square.and.arrow.up"),
        .init(slot: 20, identifier: "batch-rename", title: "批量命名", symbolName: "pencil.line"),
        .init(slot: 21, identifier: "clean-empty-folders", title: "清理空文件夹", symbolName: "folder.badge.minus"),
        .init(slot: 22, identifier: "open-terminal", title: "在终端中打开", symbolName: "terminal"),
        .init(slot: 23, identifier: "scan-qr-code", title: "识别二维码", symbolName: "qrcode.viewfinder"),
        .init(slot: 24, identifier: "extract-image-text", title: "图片文案提取", symbolName: "character.textbox"),
        .init(slot: 25, identifier: "toggle-appearance", title: "打开外观设置", symbolName: "circle.lefthalf.filled"),
        .init(slot: 26, identifier: "hide", title: "隐藏选中文件", symbolName: "eye.slash"),
        .init(slot: 27, identifier: "unhide", title: "展示隐藏文件", symbolName: "eye"),
        .init(slot: 28, identifier: "set-folder-icon-toolbar-advanced", title: "ToolbarAdvanced 测试图标", symbolName: "folder.badge.gearshape"),
        .init(slot: 29, identifier: "clear-custom-folder-icon", title: "恢复默认图标", symbolName: "folder.badge.minus"),
        .init(slot: 30, identifier: "dissolve-folder", title: "解散文件夹", symbolName: "folder.badge.minus")
    ]

    private static let menuOnlyIdentifiers: Set<String> = [
        "copy-path",
        "copy-name-no-ext",
        "copy-parent-path",
        "copy-shell-path",
        "copy-file-url",
        "cut",
        "set-folder-icon-toolbar-advanced",
        "clear-custom-folder-icon"
    ]

    static let toolboxRecipes = recipes.filter { !menuOnlyIdentifiers.contains($0.identifier) }

    private static let recipeByIdentifier = Dictionary(
        uniqueKeysWithValues: recipes.map { ($0.identifier, $0) }
    )

    static func action(for identifier: String) -> ContextQuickAction {
        guard let recipe = recipeByIdentifier[identifier] else {
            preconditionFailure("Unknown quick action identifier: \(identifier)")
        }
        return makeAction(from: recipe)
    }

    static func makeAction(from recipe: AssistantActionRecipe) -> ContextQuickAction {
        ContextQuickAction(
            id: recipe.identifier,
            name: recipe.title,
            idx: recipe.slot,
            icon: recipe.symbolName
        )
    }

    static func localizedTitle(for identifier: String, fallback: String) -> String {
        switch identifier {
        case "copy-path":
            AssistantLocalized.text(zh: "复制路径", en: "Copy Path")
        case "copy-name":
            AssistantLocalized.text(zh: "复制名称", en: "Copy Name")
        case "copy-name-no-ext":
            AssistantLocalized.text(zh: "复制名称（不含后缀）", en: "Copy Name Without Extension")
        case "copy-parent-path":
            AssistantLocalized.text(zh: "复制父目录路径", en: "Copy Parent Path")
        case "copy-shell-path":
            AssistantLocalized.text(zh: "复制 Shell 转义路径", en: "Copy Shell Path")
        case "copy-file-url":
            AssistantLocalized.text(zh: "复制 file:// URL", en: "Copy file:// URL")
        case "file-info":
            AssistantLocalized.text(zh: "文件信息中心", en: "File Info Center")
        case "copy-to":
            AssistantLocalized.text(zh: "复制到", en: "Copy To")
        case "move-to":
            AssistantLocalized.text(zh: "剪切", en: "Cut")
        case "cut":
            AssistantLocalized.text(zh: "剪切", en: "Cut")
        case "paste":
            AssistantLocalized.text(zh: "粘贴", en: "Paste")
        case "undo-last":
            AssistantLocalized.text(zh: "撤销上次操作", en: "Undo Last Operation")
        case "delete-direct":
            AssistantLocalized.text(zh: "直接删除", en: "Delete Direct")
        case "airdrop":
            AssistantLocalized.text(zh: "隔空投送", en: "AirDrop")
        case "hide":
            AssistantLocalized.text(zh: "隐藏选中文件", en: "Hide Selected Files")
        case "unhide":
            AssistantLocalized.text(zh: "展示隐藏文件", en: "Show Hidden Files")
        case "send-shortcut-to-desktop":
            AssistantLocalized.text(zh: "发送快捷方式到桌面", en: "Send Shortcut to Desktop")
        case "batch-rename":
            AssistantLocalized.text(zh: "批量命名", en: "Batch Rename")
        case "clean-empty-folders":
            AssistantLocalized.text(zh: "清理空文件夹", en: "Clean Empty Folders")
        case "open-terminal":
            AssistantLocalized.text(zh: "在终端中打开", en: "Open in Terminal")
        case "scan-qr-code":
            AssistantLocalized.text(zh: "识别二维码", en: "Scan QR Code")
        case "encrypt-zip":
            AssistantLocalized.text(zh: "加密压缩", en: "Encrypt ZIP")
        case "extract-zip":
            AssistantLocalized.text(zh: "解压 ZIP", en: "Extract ZIP")
        case "extract-image-text":
            AssistantLocalized.text(zh: "图片文案提取", en: "Extract Image Text")
        case "take-screenshot":
            AssistantLocalized.text(zh: "截图", en: "Screenshot")
        case "lock-screen":
            AssistantLocalized.text(zh: "锁定屏幕", en: "Lock Screen")
        case "toggle-appearance":
            AssistantLocalized.text(zh: "打开外观设置", en: "Open Appearance Settings")
        case "set-folder-icon-toolbar-advanced":
            AssistantLocalized.text(zh: "ToolbarAdvanced 测试图标", en: "ToolbarAdvanced Test Icon")
        case "clear-custom-folder-icon":
            AssistantLocalized.text(zh: "恢复默认图标", en: "Restore Default Icon")
        case "dissolve-folder":
            AssistantLocalized.text(zh: "解散文件夹", en: "Dissolve Folder")
        case "share":
            AssistantLocalized.text(zh: "分享", en: "Share")
        default:
            fallback
        }
    }

    static func isVisibleInToolbox(_ identifier: String) -> Bool {
        !menuOnlyIdentifiers.contains(identifier)
    }
}

enum AssistantSystemFeatureAvailability {
    static func isQuickActionAvailable(identifier: String) -> Bool {
        true
    }
}

enum ToolboxSettingsRow: Identifiable, Hashable {
    case menuGroup(ToolboxMenuGroup)
    case quickAction(String)

    private static let legacyCopyPathActionIDs: Set<String> = [
        "copy-path",
        "copy-parent-path",
        "copy-shell-path",
        "copy-file-url"
    ]

    static let defaultOrder: [Self] = [
        .menuGroup(.openWith),
        .menuGroup(.newFile),
        .quickAction("dissolve-folder"),
        .menuGroup(.folderIcon),
        .quickAction("file-info"),
        .quickAction("airdrop"),
        .menuGroup(.favoriteFolders),
        .menuGroup(.copyPath),
        .quickAction("copy-name"),
        .quickAction("send-shortcut-to-desktop"),
        .quickAction("lock-screen"),
        .quickAction("take-screenshot"),
        .quickAction("encrypt-zip"),
        .quickAction("extract-zip"),
        .quickAction("copy-to"),
        .quickAction("move-to"),
        .quickAction("paste"),
        .quickAction("undo-last"),
        .quickAction("delete-direct"),
        .quickAction("batch-rename"),
        .quickAction("clean-empty-folders"),
        .quickAction("open-terminal"),
        .quickAction("share"),
        .quickAction("scan-qr-code"),
        .quickAction("extract-image-text"),
        .quickAction("toggle-appearance"),
        .quickAction("hide"),
        .quickAction("unhide")
    ]

    var id: String {
        switch self {
        case .menuGroup(let group):
            return group.id
        case .quickAction(let identifier):
            return identifier
        }
    }

    static func loadOrder(defaults: UserDefaults = .group) -> [Self] {
        let rawOrder = defaults.stringArray(forKey: SharedPreferenceKey.toolboxMenuOrder) ?? []
        return normalizedOrder(from: rawOrder.compactMap(Self.init(storageID:)))
    }

    static func saveOrder(_ rows: [Self], defaults: UserDefaults = .group) {
        defaults.set(normalizedOrder(from: rows).map(\.storageID), forKey: SharedPreferenceKey.toolboxMenuOrder)
    }

    static func resetOrder(defaults: UserDefaults = .group) {
        defaults.removeObject(forKey: SharedPreferenceKey.toolboxMenuOrder)
    }

    private static func normalizedOrder(from rows: [Self]) -> [Self] {
        var seen: Set<String> = []
        var normalized: [Self] = []

        for row in rows + defaultOrder {
            guard defaultOrder.contains(row), seen.insert(row.storageID).inserted else {
                continue
            }
            normalized.append(row)
        }

        return normalized
    }

    private init?(storageID: String) {
        let menuPrefix = "menu."
        let actionPrefix = "action."

        if storageID.hasPrefix(menuPrefix) {
            let rawGroup = String(storageID.dropFirst(menuPrefix.count))
            if let group = ToolboxMenuGroup(rawValue: rawGroup) {
                self = .menuGroup(group)
                return
            }
        }

        if storageID.hasPrefix(actionPrefix) {
            let actionID = String(storageID.dropFirst(actionPrefix.count))
            if Self.legacyCopyPathActionIDs.contains(actionID) {
                self = .menuGroup(.copyPath)
                return
            }

            if actionID == "copy-name-no-ext" {
                self = .quickAction("copy-name")
                return
            }

            if actionID == "cut" {
                self = .quickAction("move-to")
                return
            }

            if !actionID.isEmpty {
                self = .quickAction(actionID)
                return
            }
        }

        return nil
    }

    private var storageID: String {
        switch self {
        case .menuGroup(let group):
            return "menu.\(group.rawValue)"
        case .quickAction(let identifier):
            return "action.\(identifier)"
        }
    }
}

enum ToolboxMenuGroup: String, CaseIterable, Identifiable {
    case openWith
    case newFile
    case folderIcon
    case favoriteFolders
    case copyPath

    var id: String {
        "menu-group-\(rawValue)"
    }

    var title: String {
        switch self {
        case .openWith:
            return AssistantLocalized.text(zh: "打开方式", en: "Open With")
        case .newFile:
            return AssistantLocalized.text(zh: "新建文件", en: "New File")
        case .folderIcon:
            return AssistantLocalized.text(zh: "文件(夹)图标", en: "File/Folder Icon")
        case .favoriteFolders:
            return AssistantLocalized.text(zh: "常用目录", en: "Favorite Folders")
        case .copyPath:
            return AssistantLocalized.text(zh: "复制路径", en: "Copy Path")
        }
    }

    var subtitle: String {
        switch self {
        case .openWith:
            return AssistantLocalized.text(zh: "显示所有已配置的打开应用", en: "Shows configured open-with apps")
        case .newFile:
            return AssistantLocalized.text(zh: "显示新建文件模板菜单", en: "Shows the new-file template menu")
        case .folderIcon:
            return AssistantLocalized.text(zh: "显示文件夹图标菜单", en: "Shows the folder icon menu")
        case .favoriteFolders:
            return AssistantLocalized.text(zh: "显示常用目录快捷入口", en: "Shows favorite folder shortcuts")
        case .copyPath:
            return AssistantLocalized.text(zh: "显示路径复制相关操作", en: "Shows path-copying actions")
        }
    }

    var icon: String {
        switch self {
        case .openWith:
            return "square.grid.2x2"
        case .newFile:
            return "doc.badge.plus"
        case .folderIcon:
            return "folder"
        case .favoriteFolders:
            return "folder.badge.questionmark"
        case .copyPath:
            return "doc.on.doc"
        }
    }
}

struct ContextQuickAction: AssistantModelIdentity {
    var id: String
    var name: String
    var enabled = true
    var idx: Int
    var icon: String

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension ContextQuickAction {
    var displayName: String {
        ContextQuickActionCatalog.localizedTitle(for: id, fallback: name)
    }

    var isAvailableOnCurrentSystem: Bool {
        Self.isAvailableOnCurrentSystem(id)
    }

    static func isAvailableOnCurrentSystem(_ id: String) -> Bool {
        AssistantSystemFeatureAvailability.isQuickActionAvailable(identifier: id)
    }

    static var copyPath: Self { ContextQuickActionCatalog.action(for: "copy-path") }
    static var copyName: Self { ContextQuickActionCatalog.action(for: "copy-name") }
    static var copyNameWithoutExtension: Self { ContextQuickActionCatalog.action(for: "copy-name-no-ext") }
    static var copyParentPath: Self { ContextQuickActionCatalog.action(for: "copy-parent-path") }
    static var copyShellPath: Self { ContextQuickActionCatalog.action(for: "copy-shell-path") }
    static var copyFileURL: Self { ContextQuickActionCatalog.action(for: "copy-file-url") }
    static var fileInfoCenter: Self { ContextQuickActionCatalog.action(for: "file-info") }
    static var copyTo: Self { ContextQuickActionCatalog.action(for: "copy-to") }
    static var moveTo: Self { ContextQuickActionCatalog.action(for: "move-to") }
    static var cut: Self { ContextQuickActionCatalog.action(for: "cut") }
    static var paste: Self { ContextQuickActionCatalog.action(for: "paste") }
    static var undoLastOperation: Self { ContextQuickActionCatalog.action(for: "undo-last") }
    static var deleteDirect: Self { ContextQuickActionCatalog.action(for: "delete-direct") }
    static var airdrop: Self { ContextQuickActionCatalog.action(for: "airdrop") }
    static var hideFileDir: Self { ContextQuickActionCatalog.action(for: "hide") }
    static var unhideFileDir: Self { ContextQuickActionCatalog.action(for: "unhide") }
    static var batchRename: Self { ContextQuickActionCatalog.action(for: "batch-rename") }
    static var cleanEmptyFolders: Self { ContextQuickActionCatalog.action(for: "clean-empty-folders") }
    static var openTerminal: Self { ContextQuickActionCatalog.action(for: "open-terminal") }
    static var scanQRCode: Self { ContextQuickActionCatalog.action(for: "scan-qr-code") }
    static var encryptZIP: Self { ContextQuickActionCatalog.action(for: "encrypt-zip") }
    static var extractZIP: Self { ContextQuickActionCatalog.action(for: "extract-zip") }
    static var extractImageText: Self { ContextQuickActionCatalog.action(for: "extract-image-text") }
    static var takeScreenshot: Self { ContextQuickActionCatalog.action(for: "take-screenshot") }
    static var lockScreen: Self { ContextQuickActionCatalog.action(for: "lock-screen") }
    static var toggleAppearance: Self { ContextQuickActionCatalog.action(for: "toggle-appearance") }
    static var sendShortcutToDesktop: Self { ContextQuickActionCatalog.action(for: "send-shortcut-to-desktop") }
    static var setFolderIconToolbarAdvanced: Self { ContextQuickActionCatalog.action(for: "set-folder-icon-toolbar-advanced") }
    static var clearCustomFolderIcon: Self { ContextQuickActionCatalog.action(for: "clear-custom-folder-icon") }
    static var dissolveFolder: Self { ContextQuickActionCatalog.action(for: "dissolve-folder") }
    static var share: Self { ContextQuickActionCatalog.action(for: "share") }

    var isVisibleInToolbox: Bool {
        ContextQuickActionCatalog.isVisibleInToolbox(id)
    }

    static var all: [Self] {
        ContextQuickActionCatalog.toolboxRecipes.map(ContextQuickActionCatalog.makeAction)
    }
}
