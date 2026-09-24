//
//  RCAAppDelegate+VisibilityAndSharing.swift
//  RightClickAssistantPro
//
//  Created by 老谭 on 2026/4/30.
//

import AppKit
import Foundation

private enum AssistantVisibilityMutation {
    static func visibleChildPaths(at directoryPath: String) throws -> [String] {
        guard !Utils.isProtectedFolder(directoryPath) else {
            return []
        }

        let directoryURL = URL(fileURLWithPath: directoryPath)
        let contents = try FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.isHiddenKey],
            options: [.skipsPackageDescendants]
        )

        return contents.compactMap { itemURL in
            guard !Utils.isProtectedFolder(itemURL.path) else {
                return nil
            }

            let values = try? itemURL.resourceValues(forKeys: [.isHiddenKey])
            return values?.isHidden == true ? nil : itemURL.path
        }
    }

    static func visibleRootPaths(in paths: [String]) -> [String] {
        paths.compactMap { path in
            guard !Utils.isProtectedFolder(path) else {
                return nil
            }

            let url = URL(fileURLWithPath: path)
            let values = try? url.resourceValues(forKeys: [.isHiddenKey])
            return values?.isHidden == true ? nil : path
        }
    }

    static func updateContentsAndRoot(at path: String, isHidden: Bool) throws {
        let fileManager = FileManager.default
        let url = URL(fileURLWithPath: path)

        guard isDirectoryPath(path, fileManager: fileManager) else {
            try updateRootOnly(at: path, isHidden: isHidden)
            return
        }

        let contents = try fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isHiddenKey],
            options: [.skipsPackageDescendants]
        )

        for var itemURL in contents where !Utils.isProtectedFolder(itemURL.path) {
            try setHiddenState(isHidden, for: &itemURL)
        }

        var rootURL = url
        try setHiddenState(isHidden, for: &rootURL)
    }

    static func updateRootOnly(at path: String, isHidden: Bool) throws {
        guard !Utils.isProtectedFolder(path) else {
            return
        }

        var url = URL(fileURLWithPath: path)
        try setHiddenState(isHidden, for: &url)
    }

    static func updateContentsOnly(at directoryPath: String, isHidden: Bool) throws {
        guard !Utils.isProtectedFolder(directoryPath) else {
            return
        }

        let fileManager = FileManager.default
        let directoryURL = URL(fileURLWithPath: directoryPath)
        let contents = try fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsPackageDescendants]
        )

        for var itemURL in contents where !Utils.isProtectedFolder(itemURL.path) {
            try setHiddenState(isHidden, for: &itemURL)
        }
    }

    private static func setHiddenState(_ isHidden: Bool, for url: inout URL) throws {
        var values = URLResourceValues()
        values.isHidden = isHidden
        try url.setResourceValues(values)
    }

    private static func isDirectoryPath(_ path: String, fileManager: FileManager) -> Bool {
        var isDirectory: ObjCBool = false
        fileManager.fileExists(atPath: path, isDirectory: &isDirectory)
        return isDirectory.boolValue
    }
}

enum AssistantShareDestination {
    case airDrop
    case mail
    case message
    case wechat
    case qq
    case notes

    var title: String {
        switch self {
        case .airDrop:
            return AssistantLocalized.text(zh: "隔空投送", en: "AirDrop")
        case .mail:
            return AssistantLocalized.text(zh: "邮件", en: "Mail")
        case .message:
            return AssistantLocalized.text(zh: "信息", en: "Messages")
        case .wechat:
            return AssistantLocalized.text(zh: "微信", en: "WeChat")
        case .qq:
            return AssistantLocalized.text(zh: "QQ", en: "QQ")
        case .notes:
            return AssistantLocalized.text(zh: "备忘录", en: "Notes")
        }
    }

    var sharingServiceName: NSSharingService.Name? {
        switch self {
        case .airDrop:
            return .sendViaAirDrop
        case .mail:
            return .composeEmail
        case .message:
            return .composeMessage
        case .wechat, .qq, .notes:
            return nil
        }
    }

    var requiresServiceLookup: Bool {
        switch self {
        case .wechat, .qq, .notes:
            return true
        case .airDrop, .mail, .message:
            return false
        }
    }

    var usesSharePickerFallback: Bool {
        switch self {
        case .wechat, .qq:
            return true
        case .airDrop, .mail, .message, .notes:
            return false
        }
    }

    func matches(_ service: NSSharingService) -> Bool {
        let normalizedTitle = service.title.lowercased()

        switch self {
        case .wechat:
            return normalizedTitle.contains("wechat")
                || service.title.contains("微信")
        case .qq:
            return normalizedTitle == "qq"
                || normalizedTitle.contains("tencent qq")
                || normalizedTitle.contains("qq")
                || service.title.contains("QQ")
        case .notes:
            return normalizedTitle.contains("note")
                || service.title.contains("备忘录")
        case .airDrop, .mail, .message:
            return false
        }
    }
}

extension RCAAppDelegate {
    func openTerminalAtDirectory(_ target: [String], _ trigger: String) {
        if trigger == "ctx-container" {
            openTerminalApplication()
            return
        }

        let directoryURLs = resolveTerminalDirectoryURLs(from: target, trigger: trigger)
        guard !directoryURLs.isEmpty else {
            showAlert(
                messageText: AssistantLocalized.text(zh: "在终端中打开", en: "Open in Terminal"),
                informativeText: AssistantLocalized.text(
                    zh: "没有可打开的目录，请在文件夹上右键，或对文件执行父目录打开。",
                    en: "No directory is available. Right-click a folder, or open the parent folder from a file."
                ),
                style: .informational
            )
            return
        }

        guard let terminalURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Terminal") else {
            showAlert(
                messageText: AssistantLocalized.text(zh: "在终端中打开", en: "Open in Terminal"),
                informativeText: AssistantLocalized.text(zh: "未找到 Terminal 应用。", en: "The Terminal app was not found."),
                style: .warning
            )
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true

        NSWorkspace.shared.open(directoryURLs, withApplicationAt: terminalURL, configuration: configuration) { _, error in
            guard let error else {
                return
            }

            Task { @MainActor in
                self.showAlert(
                    messageText: AssistantLocalized.text(zh: "在终端中打开失败", en: "Failed to Open in Terminal"),
                    informativeText: error.localizedDescription,
                    style: .warning
                )
            }
        }
    }

    private func openTerminalApplication() {
        let title = AssistantLocalized.text(zh: "打开终端", en: "Open Terminal")
        guard let terminalURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Terminal") else {
            showAlert(
                messageText: title,
                informativeText: AssistantLocalized.text(zh: "未找到 Terminal 应用。", en: "The Terminal app was not found."),
                style: .warning
            )
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true

        NSWorkspace.shared.open([], withApplicationAt: terminalURL, configuration: configuration) { _, error in
            guard let error else {
                return
            }

            Task { @MainActor in
                self.showAlert(
                    messageText: AssistantLocalized.text(zh: "打开终端失败", en: "Failed to Open Terminal"),
                    informativeText: error.localizedDescription,
                    style: .warning
                )
            }
        }
    }

    func cleanEmptyFolders(_ target: [String], _ trigger: String) {
        let cleanupTargets = cleanupTargets(from: target, trigger: trigger)
        guard !cleanupTargets.isEmpty else {
            showAlert(
                messageText: AssistantLocalized.text(zh: "清理空文件夹", en: "Clean Empty Folders"),
                informativeText: AssistantLocalized.text(
                    zh: "请在文件夹上右键，或在当前目录空白处右键后再执行。",
                    en: "Right-click a folder or the empty area of the current folder to run this action."
                ),
                style: .informational
            )
            return
        }

        let accessSnapshots = authorizedDirectoryAccessSnapshots()

        Task.detached(priority: .userInitiated) { [cleanupTargets, accessSnapshots] in
            let result = AssistantScopedFileWorker.performEmptyFolderCleanup(
                targets: cleanupTargets.map {
                    EmptyFolderCleanupTarget(path: $0.path, preservesRoot: $0.preservesRoot)
                },
                accessSnapshots: accessSnapshots
            )

            await MainActor.run {
                if result.failedMessages.isEmpty {
                    let message = result.removedCount > 0
                        ? AssistantLocalized.text(zh: "已清理 \(result.removedCount) 个空文件夹，并移到废纸篓。", en: "Removed \(result.removedCount) empty folders and moved them to Trash.")
                        : AssistantLocalized.text(zh: "没有找到可清理的空文件夹。", en: "No empty folders were found.")
                    self.showAlert(
                        messageText: AssistantLocalized.text(zh: "清理完成", en: "Cleanup Complete"),
                        informativeText: message,
                        style: .informational
                    )
                    return
                }

                var messageLines: [String] = []
                if result.removedCount > 0 {
                    messageLines.append(AssistantLocalized.text(zh: "已清理 \(result.removedCount) 个空文件夹。", en: "Removed \(result.removedCount) empty folders."))
                }
                messageLines.append(contentsOf: result.failedMessages)

                self.showAlert(
                    messageText: result.removedCount > 0
                        ? AssistantLocalized.text(zh: "清理部分失败", en: "Cleanup Partially Failed")
                        : AssistantLocalized.text(zh: "清理失败", en: "Cleanup Failed"),
                    informativeText: messageLines.joined(separator: "\n"),
                    style: .warning
                )
            }
        }
    }

    func showAirDrop(_ target: [String], _ trigger: String) {
        shareItems(target, trigger, using: .airDrop)
    }

    func showSystemShare(_ target: [String], _ trigger: String) {
        let title = AssistantLocalized.text(zh: "分享", en: "Share")
        let fileURLs = shareableFileURLs(from: target, trigger: trigger, title: title)
        guard !fileURLs.isEmpty else { return }

        NSApp.activate(ignoringOtherApps: true)
        guard showSharingPicker(for: fileURLs) else {
            showAlert(
                messageText: title,
                informativeText: AssistantLocalized.text(zh: "当前没有可用的系统分享服务。", en: "No system sharing service is available."),
                style: .informational
            )
            return
        }
    }

    func shareItems(_ target: [String], _ trigger: String, using destination: AssistantShareDestination) {
        let fileURLs = shareableFileURLs(from: target, trigger: trigger, title: destination.title)
        guard !fileURLs.isEmpty else { return }

        guard let service = sharingService(for: destination, items: fileURLs) else {
            if destination.usesSharePickerFallback, showSharingPicker(for: fileURLs) {
                logger.info("\(destination.title, privacy: .public) share service was not directly available; presented system share picker.")
                return
            }

            showAlert(
                messageText: destination.title,
                informativeText: AssistantLocalized.text(
                    zh: "当前没有可用的\(destination.title)分享服务。",
                    en: "The \(destination.title) sharing service is not available."
                ),
                style: .informational
            )
            return
        }

        service.perform(withItems: fileURLs)
        logger.info("shared via \(destination.title, privacy: .public): \(fileURLs.map(\.path).joined(separator: ", "), privacy: .public)")
    }

    @discardableResult
    private func showSharingPicker(for fileURLs: [URL]) -> Bool {
        let picker = NSSharingServicePicker(items: fileURLs)
        if let keyWindow = NSApp.keyWindow,
           let contentView = keyWindow.contentView {
            picker.show(relativeTo: contentView.bounds, of: contentView, preferredEdge: .minY)
            return true
        }

        let anchorWindow = NSWindow(
            contentRect: NSRect(x: NSScreen.main?.visibleFrame.midX ?? 0, y: NSScreen.main?.visibleFrame.midY ?? 0, width: 1, height: 1),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        anchorWindow.isOpaque = false
        anchorWindow.backgroundColor = .clear
        anchorWindow.hasShadow = false
        anchorWindow.level = .popUpMenu
        anchorWindow.collectionBehavior = [.transient, .canJoinAllSpaces, .ignoresCycle]

        let anchorView = NSView(frame: NSRect(x: 0, y: 0, width: 1, height: 1))
        anchorWindow.contentView = anchorView
        sharingPickerAnchorWindow = anchorWindow

        NSApp.activate(ignoringOtherApps: true)
        anchorWindow.orderFrontRegardless()
        picker.show(relativeTo: anchorView.bounds, of: anchorView, preferredEdge: .minY)

        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self, weak anchorWindow] in
            guard self?.sharingPickerAnchorWindow === anchorWindow else {
                return
            }
            anchorWindow?.orderOut(nil)
            self?.sharingPickerAnchorWindow = nil
        }

        return true
    }

    private func shareableFileURLs(from target: [String], trigger: String, title: String) -> [URL] {
        guard trigger != "ctx-container" else {
            showAlert(
                messageText: title,
                informativeText: AssistantLocalized.text(zh: "请先选择文件或子文件夹再分享。", en: "Select files or subfolders before sharing."),
                style: .informational
            )
            return []
        }

        let fileURLs = decodedPaths(from: target).compactMap { path -> URL? in
            guard !Utils.isProtectedFolder(path) else {
                showAlert(
                    messageText: title,
                    informativeText: AssistantLocalized.text(zh: "无法分享系统保护路径：\(path)", en: "Protected system paths cannot be shared: \(path)"),
                    style: .warning
                )
                return nil
            }

            guard FileManager.default.fileExists(atPath: path) else {
                return nil
            }

            return URL(fileURLWithPath: path)
        }

        guard !fileURLs.isEmpty else {
            showAlert(
                messageText: title,
                informativeText: AssistantLocalized.text(zh: "没有可分享的文件或文件夹。", en: "There are no files or folders available to share."),
                style: .informational
            )
            return []
        }

        return fileURLs
    }

    private func sharingService(for destination: AssistantShareDestination, items: [URL]) -> NSSharingService? {
        if let sharingServiceName = destination.sharingServiceName,
           let service = NSSharingService(named: sharingServiceName),
           service.canPerform(withItems: items) {
            return service
        }

        guard destination.requiresServiceLookup else {
            return nil
        }

        return NSSharingService.sharingServices(forItems: items).first { service in
            destination.matches(service)
        }
    }
    func unhideFilesAndDirs(_ target: [String], _ trigger: String) {
        let paths = decodedPaths(from: target)
        logger.info("开始取消隐藏文件和目录，目标路径: \(paths)")

        guard let firstPath = paths.first else {
            return
        }

        do {
            try AssistantVisibilityMutation.updateContentsAndRoot(at: firstPath, isHidden: false)
            logger.info("取消隐藏操作完成，共处理目录: \(firstPath)")
        } catch {
            logger.error("取消隐藏失败: \(error.localizedDescription)")
        }
    }

    func hideFilesAndDirs(_ target: [String], _ trigger: String) {
        let paths = decodedPaths(from: target)
        logger.info("开始隐藏文件和目录，目标路径: \(paths), 触发器: \(trigger)")

        do {
            let hiddenPaths: [String]
            if trigger == "ctx-container", let firstPath = paths.first {
                hiddenPaths = try AssistantVisibilityMutation.visibleChildPaths(at: firstPath)
                try AssistantVisibilityMutation.updateContentsOnly(at: firstPath, isHidden: true)
            } else {
                hiddenPaths = AssistantVisibilityMutation.visibleRootPaths(in: paths)
                for path in paths {
                    try AssistantVisibilityMutation.updateRootOnly(at: path, isHidden: true)
                }
            }

            if !hiddenPaths.isEmpty {
                registerUndoOperation(
                    kind: .hide,
                    items: hiddenPaths.map { UndoOperationState.Item(originalPath: nil, currentPath: $0) },
                    bookmarkURLs: Array(Set(hiddenPaths.map { URL(fileURLWithPath: $0).deletingLastPathComponent() }))
                )
            }
        } catch {
            logger.error("隐藏失败: \(error.localizedDescription)")
        }

        logger.info("隐藏操作完成")
    }

    func copyPath(_ target: [String]) {
        guard let firstPath = target.first else {
            return
        }

        writeClipboardString(
            firstPath.removingPercentEncoding ?? firstPath,
            successMessage: AssistantLocalized.text(zh: "文件路径已复制到剪贴板。", en: "The file path was copied to the clipboard.")
        )
    }

    func deleteFoldorFile(_ target: [String], _ trigger: String) {
        logger.info("---- deleteFoldorFile  trigger:\(trigger)")

        guard trigger != "ctx-container" else {
            showAlert(
                messageText: AssistantLocalized.text(zh: "警告", en: "Warning"),
                informativeText: AssistantLocalized.text(zh: "无法删除当前文件夹，请选择文件或子文件夹进行删除。", en: "The current folder cannot be deleted. Select files or subfolders instead."),
                style: .warning
            )
            return
        }

        let paths = decodedPaths(from: target)
        guard confirmDirectDelete(paths) else {
            return
        }

        let accessSnapshots = authorizedDirectoryAccessSnapshots()

        Task.detached(priority: .userInitiated) { [paths, accessSnapshots] in
            let result = AssistantScopedFileWorker.performDelete(
                paths: paths,
                accessSnapshots: accessSnapshots
            )

            await MainActor.run {
                if !result.failedMessages.isEmpty {
                    self.showAlert(
                        messageText: AssistantLocalized.text(zh: "删除部分失败", en: "Delete Partially Failed"),
                        informativeText: result.failedMessages.joined(separator: "\n"),
                        style: .warning
                    )
                }
            }
        }
    }

    private func confirmDirectDelete(_ paths: [String]) -> Bool {
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = AssistantLocalized.text(zh: "确认直接删除？", en: "Delete Permanently?")
        let sampleNames = paths.prefix(5).map { URL(fileURLWithPath: $0).lastPathComponent }.joined(separator: "\n")
        let overflowText = paths.count > 5
            ? AssistantLocalized.text(zh: "\n以及另外 \(paths.count - 5) 个项目", en: "\nand \(paths.count - 5) more item(s)")
            : ""
        alert.informativeText = AssistantLocalized.text(
            zh: "此操作不会移到废纸篓，删除后只能依赖你自己的备份恢复。\n\n\(sampleNames)\(overflowText)",
            en: "This will not move items to Trash. Recovery depends on your own backups.\n\n\(sampleNames)\(overflowText)"
        )
        alert.addButton(withTitle: AssistantLocalized.text(zh: "直接删除", en: "Delete Permanently"))
        alert.addButton(withTitle: AssistantLocalized.text(zh: "取消", en: "Cancel"))

        return alert.runModal() == .alertFirstButtonReturn
    }

    func showAlert(
        messageText: String,
        informativeText: String,
        style: NSAlert.Style,
        delivery: AssistantFeedbackDelivery = .banner
    ) {
        switch delivery {
        case .banner:
            AssistantBannerNotificationCenter.shared.post(
                title: messageText,
                body: informativeText
            )
        case .modal:
            let alert = NSAlert()
            alert.messageText = messageText
            alert.informativeText = informativeText
            alert.alertStyle = style
            alert.addButton(withTitle: AssistantLocalized.text(zh: "确定", en: "OK"))
            alert.runModal()
        }
    }

    private func resolveTerminalDirectoryURLs(from target: [String], trigger: String) -> [URL] {
        let rawPaths = uniqueDecodedPaths(from: target)
        guard !rawPaths.isEmpty else {
            return []
        }

        let directories = rawPaths.map { path in
            let itemURL = URL(fileURLWithPath: path)
            if trigger == "ctx-container" || isDirectory(atPath: path) {
                return itemURL.standardizedFileURL
            }
            return itemURL.deletingLastPathComponent().standardizedFileURL
        }

        return deduplicatedURLs(directories)
    }

    private struct EmptyFolderCleanupMenuTarget {
        let path: String
        let preservesRoot: Bool
    }

    private func cleanupTargets(from target: [String], trigger: String) -> [EmptyFolderCleanupMenuTarget] {
        let rawPaths = uniqueDecodedPaths(from: target)
        guard !rawPaths.isEmpty else {
            return []
        }

        if trigger == "ctx-container", let firstPath = rawPaths.first {
            let candidate = URL(fileURLWithPath: firstPath).standardizedFileURL.path
            return isDirectory(atPath: candidate)
                ? [.init(path: candidate, preservesRoot: true)]
                : []
        }

        var roots: [(path: String, preservesRoot: Bool)] = rawPaths
            .filter { isDirectory(atPath: $0) }
            .map { (URL(fileURLWithPath: $0).standardizedFileURL.path, false) }

        if roots.isEmpty {
            let parentPaths = Set(
                rawPaths.map {
                    URL(fileURLWithPath: $0).deletingLastPathComponent().standardizedFileURL.path
                }
            )

            if parentPaths.count == 1, let onlyParent = parentPaths.first {
                roots = [(onlyParent, true)]
            }
        }

        return collapseNestedCleanupTargets(roots)
    }

    private func collapseNestedCleanupTargets(_ targets: [(path: String, preservesRoot: Bool)]) -> [EmptyFolderCleanupMenuTarget] {
        var targetByPath: [String: Bool] = [:]
        for target in targets {
            targetByPath[target.path] = (targetByPath[target.path] ?? true) && target.preservesRoot
        }

        let sortedTargets = targetByPath
            .map { (path: $0.key, preservesRoot: $0.value) }
            .sorted { lhs, rhs in
                if lhs.path.count == rhs.path.count {
                    return lhs.path < rhs.path
                }
                return lhs.path.count < rhs.path.count
            }

        var roots: [EmptyFolderCleanupMenuTarget] = []
        for target in sortedTargets {
            let path = target.path
            let prefixedPath = path.hasSuffix("/") ? path : path + "/"
            let alreadyCovered = roots.contains { root in
                let prefixedRoot = root.path.hasSuffix("/") ? root.path : root.path + "/"
                return path == root.path || prefixedPath.hasPrefix(prefixedRoot)
            }

            if !alreadyCovered {
                roots.append(.init(path: path, preservesRoot: target.preservesRoot))
            }
        }

        return roots
    }

    private func deduplicatedURLs(_ urls: [URL]) -> [URL] {
        var seen: Set<String> = []
        var results: [URL] = []

        for url in urls {
            let normalizedURL = url.standardizedFileURL
            if seen.insert(normalizedURL.path).inserted {
                results.append(normalizedURL)
            }
        }

        return results
    }
}
