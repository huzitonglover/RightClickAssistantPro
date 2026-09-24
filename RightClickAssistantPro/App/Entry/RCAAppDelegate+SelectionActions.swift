//
//  RCAAppDelegate+SelectionActions.swift
//  RightClickAssistantPro
//
//  Created by 老谭 on 2026/4/30.
//

import AppKit
import SwiftUI

private final class ArchivePasswordPromptController: NSObject {
    let panel: NSPanel
    let passwordField = NSSecureTextField(frame: .zero)
    private var modalResponse: NSApplication.ModalResponse = .cancel

    init(
        title: String,
        informativeText: String,
        passwordPlaceholder: String
    ) {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 180),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        super.init()

        panel.title = title
        panel.isFloatingPanel = true
        panel.level = .modalPanel
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true

        let contentView = NSView(frame: panel.contentRect(forFrameRect: panel.frame))
        contentView.translatesAutoresizingMaskIntoConstraints = false
        panel.contentView = contentView

        let infoLabel = NSTextField(wrappingLabelWithString: informativeText)
        infoLabel.translatesAutoresizingMaskIntoConstraints = false
        infoLabel.maximumNumberOfLines = 0

        let passwordLabel = NSTextField(labelWithString: AssistantLocalized.text(zh: "密码", en: "Password"))
        passwordLabel.translatesAutoresizingMaskIntoConstraints = false
        passwordField.translatesAutoresizingMaskIntoConstraints = false
        passwordField.placeholderString = passwordPlaceholder

        let okButton = NSButton(title: AssistantLocalized.text(zh: "确定", en: "OK"), target: self, action: #selector(confirm))
        okButton.translatesAutoresizingMaskIntoConstraints = false
        okButton.keyEquivalent = "\r"

        let cancelButton = NSButton(title: AssistantLocalized.text(zh: "取消", en: "Cancel"), target: self, action: #selector(cancel))
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.keyEquivalent = "\u{1b}"

        contentView.addSubview(infoLabel)
        contentView.addSubview(passwordLabel)
        contentView.addSubview(passwordField)
        contentView.addSubview(okButton)
        contentView.addSubview(cancelButton)

        NSLayoutConstraint.activate([
            infoLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            infoLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            infoLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            passwordLabel.topAnchor.constraint(equalTo: infoLabel.bottomAnchor, constant: 16),
            passwordLabel.leadingAnchor.constraint(equalTo: infoLabel.leadingAnchor),
            passwordLabel.trailingAnchor.constraint(equalTo: infoLabel.trailingAnchor),

            passwordField.topAnchor.constraint(equalTo: passwordLabel.bottomAnchor, constant: 6),
            passwordField.leadingAnchor.constraint(equalTo: infoLabel.leadingAnchor),
            passwordField.trailingAnchor.constraint(equalTo: infoLabel.trailingAnchor),

            cancelButton.topAnchor.constraint(greaterThanOrEqualTo: passwordField.bottomAnchor, constant: 20),
            cancelButton.trailingAnchor.constraint(equalTo: okButton.leadingAnchor, constant: -12),
            cancelButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),

            okButton.centerYAnchor.constraint(equalTo: cancelButton.centerYAnchor),
            okButton.trailingAnchor.constraint(equalTo: infoLabel.trailingAnchor),
            okButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])
    }

    func runModal() -> NSApplication.ModalResponse {
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(passwordField)
        return NSApp.runModal(for: panel)
    }

    @objc
    private func confirm() {
        modalResponse = .OK
        closePanel()
    }

    @objc
    private func cancel() {
        modalResponse = .cancel
        closePanel()
    }

    private func closePanel() {
        panel.orderOut(nil)
        NSApp.stopModal(withCode: modalResponse)
    }
}

private enum AssistantSelectionCommand: String {
    case copyPath = "copy-path"
    case copyName = "copy-name"
    case copyNameWithoutExtension = "copy-name-no-ext"
    case copyParentPath = "copy-parent-path"
    case copyShellPath = "copy-shell-path"
    case copyFileURL = "copy-file-url"
    case newFolder = "new-folder"
    case fileInfoCenter = "file-info"
    case batchRename = "batch-rename"
    case cleanEmptyFolders = "clean-empty-folders"
    case openTerminal = "open-terminal"
    case scanQRCode = "scan-qr-code"
    case extractImageText = "extract-image-text"
    case takeScreenshot = "take-screenshot"
    case lockScreen = "lock-screen"
    case toggleAppearance = "toggle-appearance"
    case sendShortcutToDesktop = "send-shortcut-to-desktop"
    case encryptZIP = "encrypt-zip"
    case extractZIP = "extract-zip"
    case copyTo = "copy-to"
    case moveTo = "move-to"
    case cut = "cut"
    case paste = "paste"
    case undoLastOperation = "undo-last"
    case deleteDirect = "delete-direct"
    case airdrop
    case share
    case shareAirDrop = "share-airdrop"
    case shareMail = "share-mail"
    case shareMessage = "share-message"
    case shareWeChat = "share-wechat"
    case shareQQ = "share-qq"
    case shareNotes = "share-notes"
    case hide
    case unhide
    case setFolderIconToolbarAdvanced = "set-folder-icon-toolbar-advanced"
    case clearCustomFolderIcon = "clear-custom-folder-icon"
    case dissolveFolder = "dissolve-folder"

    @MainActor
    static func command(for rid: String, in appState: AssistantRuntimeState) -> AssistantSelectionCommand? {
        if FolderIconTemplate.templateID(fromActionIdentifier: rid) != nil {
            return .setFolderIconToolbarAdvanced
        }

        if let command = AssistantSelectionCommand(rawValue: rid), command.isMenuOnlyCommand {
            return command
        }

        guard let selectedAction = appState.getActionItem(rid: rid) else {
            return nil
        }
        return AssistantSelectionCommand(rawValue: selectedAction.id)
    }

    private var isMenuOnlyCommand: Bool {
        switch self {
        case .copyPath,
             .copyNameWithoutExtension,
             .copyParentPath,
             .copyShellPath,
             .copyFileURL,
             .shareAirDrop,
             .shareMail,
             .shareMessage,
             .shareWeChat,
             .shareQQ,
             .shareNotes,
             .setFolderIconToolbarAdvanced,
             .clearCustomFolderIcon,
             .newFolder:
            return true
        default:
            return false
        }
    }

    var featureAccessName: String {
        switch self {
        case .setFolderIconToolbarAdvanced, .clearCustomFolderIcon:
            return AssistantLocalized.text(zh: "文件(夹)图标", en: "File/Folder Icon")
        case .newFolder:
            return AssistantLocalized.text(zh: "新建文件夹", en: "New Folder")
        default:
            return AssistantLocalized.text(zh: "工具箱功能", en: "Toolbox Feature")
        }
    }

    @MainActor
    func perform(on delegate: RCAAppDelegate, target: [String], trigger: String) {
        switch self {
        case .copyPath:
            delegate.copyPath(target)
        case .copyName:
            delegate.copyItemName(target, includeExtension: true)
        case .copyNameWithoutExtension:
            delegate.copyItemName(target, includeExtension: false)
        case .copyParentPath:
            delegate.copyParentPath(target)
        case .copyShellPath:
            delegate.copyShellEscapedPath(target)
        case .copyFileURL:
            delegate.copyFileURLString(target)
        case .newFolder:
            delegate.createFolder(target, trigger)
        case .fileInfoCenter:
            delegate.showFileInfoCenter(target, trigger)
        case .batchRename:
            delegate.showBatchRenameCenter(target, trigger)
        case .cleanEmptyFolders:
            delegate.cleanEmptyFolders(target, trigger)
        case .openTerminal:
            delegate.openTerminalAtDirectory(target, trigger)
        case .scanQRCode:
            delegate.showQRCodeRecognitionCenter(target, trigger)
        case .extractImageText:
            delegate.showImageTextRecognitionCenter(target, trigger)
        case .takeScreenshot:
            delegate.takeScreenshot(target, trigger)
        case .lockScreen:
            delegate.lockScreen(target, trigger)
        case .toggleAppearance:
            delegate.toggleSystemAppearance(target, trigger)
        case .sendShortcutToDesktop:
            delegate.sendShortcutToDesktop(target, trigger)
        case .encryptZIP:
            delegate.encryptItemsAsZIP(target, trigger)
        case .extractZIP:
            delegate.extractZIPArchives(target, trigger)
        case .copyTo:
            delegate.copyItemsToDirectory(target, trigger)
        case .moveTo:
            delegate.moveItemsToDirectory(target, trigger)
        case .cut:
            delegate.cutItems(target, trigger)
        case .paste:
            delegate.pasteItems(target, trigger)
        case .undoLastOperation:
            delegate.undoLastOperation()
        case .deleteDirect:
            delegate.deleteFoldorFile(target, trigger)
        case .airdrop:
            delegate.showAirDrop(target, trigger)
        case .share:
            delegate.showSystemShare(target, trigger)
        case .shareAirDrop:
            delegate.shareItems(target, trigger, using: .airDrop)
        case .shareMail:
            delegate.shareItems(target, trigger, using: .mail)
        case .shareMessage:
            delegate.shareItems(target, trigger, using: .message)
        case .shareWeChat:
            delegate.shareItems(target, trigger, using: .wechat)
        case .shareQQ:
            delegate.shareItems(target, trigger, using: .qq)
        case .shareNotes:
            delegate.shareItems(target, trigger, using: .notes)
        case .hide:
            delegate.hideFilesAndDirs(target, trigger)
        case .unhide:
            delegate.unhideFilesAndDirs(target, trigger)
        case .setFolderIconToolbarAdvanced:
            delegate.setFolderIconToolbarAdvanced(target, trigger)
        case .clearCustomFolderIcon:
            delegate.clearCustomFolderIcon(target, trigger)
        case .dissolveFolder:
            delegate.dissolveFolders(target, trigger)
        }
    }
}

extension RCAAppDelegate {
    func actionHandler(rid: String, target: [String], trigger: String) {
        Task { @MainActor in
            logger.info(
                "Quick action requested rid=\(rid, privacy: .public) trigger=\(trigger, privacy: .public) targetCount=\(target.count, privacy: .public)"
            )

            guard let command = AssistantSelectionCommand.command(for: rid, in: appState) else {
                logger.warning("Quick action not found rid=\(rid, privacy: .public)")
                return
            }

            logger.info(
                "Quick action resolved rid=\(rid, privacy: .public) command=\(command.rawValue, privacy: .public) trigger=\(trigger, privacy: .public)"
            )
            if let templateID = FolderIconTemplate.templateID(fromActionIdentifier: rid) {
                setFolderIcon(templateID: templateID, target: target, trigger: trigger)
            } else {
                command.perform(on: self, target: target, trigger: trigger)
            }
        }
    }

    func copyItemName(_ target: [String], includeExtension: Bool) {
        let paths = decodedPaths(from: target)
        guard !paths.isEmpty else {
            showAlert(
                messageText: AssistantLocalized.text(zh: "提示", en: "Notice"),
                informativeText: AssistantLocalized.text(zh: "没有可复制的文件名称。", en: "There are no file names available to copy."),
                style: .informational
            )
            return
        }

        let names = paths.map { path in
            let fileURL = URL(fileURLWithPath: path)
            if includeExtension || isFolder(fileURL) {
                return fileURL.lastPathComponent
            }

            return fileURL.deletingPathExtension().lastPathComponent
        }

        writeClipboardString(
            names.joined(separator: "\n"),
            successMessage: includeExtension
                ? AssistantLocalized.text(zh: "文件名称（含后缀）已复制到剪贴板。", en: "File names with extensions were copied to the clipboard.")
                : AssistantLocalized.text(zh: "文件名称（不含后缀）已复制到剪贴板。", en: "File names without extensions were copied to the clipboard.")
            )
    }

    private func isFolder(_ url: URL) -> Bool {
        let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey, .isSymbolicLinkKey])
        return values?.isDirectory == true
            && values?.isPackage != true
            && values?.isSymbolicLink != true
    }

    func copyParentPath(_ target: [String]) {
        let paths = decodedPaths(from: target)
        guard !paths.isEmpty else {
            showAlert(
                messageText: AssistantLocalized.text(zh: "提示", en: "Notice"),
                informativeText: AssistantLocalized.text(zh: "没有可复制的父目录路径。", en: "There is no parent path available to copy."),
                style: .informational
            )
            return
        }

        let parentPaths = paths.map {
            URL(fileURLWithPath: $0).deletingLastPathComponent().standardizedFileURL.path
        }
        writeClipboardString(
            parentPaths.joined(separator: "\n"),
            successMessage: AssistantLocalized.text(zh: "父目录路径已复制到剪贴板。", en: "Parent paths were copied to the clipboard.")
        )
    }

    func copyShellEscapedPath(_ target: [String]) {
        let paths = decodedPaths(from: target)
        guard !paths.isEmpty else {
            showAlert(
                messageText: AssistantLocalized.text(zh: "提示", en: "Notice"),
                informativeText: AssistantLocalized.text(zh: "没有可复制的路径。", en: "There are no paths available to copy."),
                style: .informational
            )
            return
        }

        let escapedPaths = paths.map(shellEscapedPath)
        writeClipboardString(
            escapedPaths.joined(separator: "\n"),
            successMessage: AssistantLocalized.text(zh: "Shell 转义路径已复制到剪贴板。", en: "Shell-escaped paths were copied to the clipboard.")
        )
    }

    func copyFileURLString(_ target: [String]) {
        let paths = decodedPaths(from: target)
        guard !paths.isEmpty else {
            showAlert(
                messageText: AssistantLocalized.text(zh: "提示", en: "Notice"),
                informativeText: AssistantLocalized.text(zh: "没有可复制的 file:// URL。", en: "There are no file:// URLs available to copy."),
                style: .informational
            )
            return
        }

        let urls = paths.map { URL(fileURLWithPath: $0).absoluteString }
        writeClipboardString(
            urls.joined(separator: "\n"),
            successMessage: AssistantLocalized.text(zh: "file:// URL 已复制到剪贴板。", en: "file:// URLs were copied to the clipboard.")
        )
    }

    func copyItemsToDirectory(_ target: [String], _ trigger: String) {
        let title = AssistantLocalized.text(zh: "复制到", en: "Copy To")
        guard validateSelectionActionTargets(target, trigger, title: title) else { return }
        guard let destinationURL = chooseDestinationDirectory(title: title) else { return }
        transferItems(target, destinationURL: destinationURL, moveItems: false)
    }

    func moveItemsToDirectory(_ target: [String], _ trigger: String) {
        let title = AssistantLocalized.text(zh: "剪切", en: "Cut")
        guard validateSelectionActionTargets(target, trigger, title: title) else { return }
        guard let destinationURL = chooseDestinationDirectory(title: title) else { return }
        transferItems(target, destinationURL: destinationURL, moveItems: true)
    }

    func cutItems(_ target: [String], _ trigger: String) {
        guard validateSelectionActionTargets(target, trigger, title: AssistantLocalized.text(zh: "剪切", en: "Cut")) else { return }

        let sourcePaths = decodedPaths(from: target)
        guard !sourcePaths.isEmpty else {
            showAlert(
                messageText: AssistantLocalized.text(zh: "提示", en: "Notice"),
                informativeText: AssistantLocalized.text(zh: "没有可剪切的文件或文件夹。", en: "There are no files or folders available to cut."),
                style: .informational
            )
            return
        }

        saveClipboardOperation(ClipboardOperationState(mode: .cut, sourcePaths: sourcePaths))
        logger.info("Cut recorded \(sourcePaths.count) item(s) for later paste")
    }

    func pasteItems(_ target: [String], _ trigger: String) {
        let systemClipboardFilePaths = filePathsFromSystemClipboard()
        let clipboardImageData = systemClipboardFilePaths.isEmpty ? pngImageDataFromSystemClipboard() : nil
        let state = systemClipboardFilePaths.isEmpty && clipboardImageData == nil ? loadClipboardOperation() : nil

        guard !systemClipboardFilePaths.isEmpty || clipboardImageData != nil || state != nil else {
            showAlert(
                messageText: AssistantLocalized.text(zh: "提示", en: "Notice"),
                informativeText: AssistantLocalized.text(zh: "当前剪贴板没有可粘贴的文件或图片。", en: "There are no files or images available to paste from the clipboard."),
                style: .informational
            )
            return
        }

        guard let destinationURL = resolvePasteDestination(target, trigger) else {
            showAlert(
                messageText: AssistantLocalized.text(zh: "提示", en: "Notice"),
                informativeText: AssistantLocalized.text(
                    zh: "请在目标文件夹空白处右键，或直接对目标文件夹执行粘贴。",
                    en: "Right-click the empty area of the destination folder, or paste directly onto the folder."
                ),
                style: .informational
            )
            return
        }

        if !systemClipboardFilePaths.isEmpty {
            transferItems(
                systemClipboardFilePaths,
                destinationURL: destinationURL,
                moveItems: false,
                clearClipboardOnSuccess: false
            )
        } else if let clipboardImageData {
            pasteImageData(
                clipboardImageData,
                to: destinationURL
            )
        } else if state?.mode == .copy {
            transferItems(
                state?.sourcePaths ?? [],
                destinationURL: destinationURL,
                moveItems: false,
                clearClipboardOnSuccess: false
            )
        } else if state?.mode == .cut {
            transferItems(
                state?.sourcePaths ?? [],
                destinationURL: destinationURL,
                moveItems: true,
                clearClipboardOnSuccess: true
            )
        }
    }

    func setFolderIconToolbarAdvanced(_ target: [String], _ trigger: String) {
        if let firstIcon = appState.folderIcons.first(where: \.enabled) {
            setFolderIcon(templateID: firstIcon.id, target: target, trigger: trigger)
            return
        }

        setFolderIcon(
            image: NSImage(named: "FolderIconToolbarAdvanced"),
            missingAssetMessage: AssistantLocalized.text(
                zh: "没有找到可用的文件夹图标素材。",
                en: "No available folder icon asset was found."
            ),
            target: target,
            trigger: trigger,
            successTitle: AssistantLocalized.text(zh: "文件夹图标已更换", en: "Folder Icon Changed")
        )
    }

    func setFolderIcon(templateID: String, target: [String], trigger: String) {
        let title = AssistantLocalized.text(zh: "文件(夹)图标", en: "File/Folder Icon")

        guard let template = appState.folderIcons.first(where: { $0.id == templateID && $0.enabled }) else {
            logger.warning("Folder icon template not found or disabled id=\(templateID, privacy: .public)")
            showAlert(
                messageText: title,
                informativeText: AssistantLocalized.text(
                    zh: "没有找到这个文件夹图标配置，请在设置中检查是否已启用。",
                    en: "This folder icon configuration was not found. Check whether it is enabled in Settings."
                ),
                style: .warning
            )
            return
        }

        setFolderIcon(
            image: image(for: template),
            missingAssetMessage: AssistantLocalized.text(
                zh: "没有找到“\(template.displayName)”图标素材。",
                en: "The icon asset for \(template.displayName) could not be found."
            ),
            target: target,
            trigger: trigger,
            successTitle: AssistantLocalized.text(zh: "文件夹图标已更换", en: "Folder Icon Changed")
        )
    }

    private func setFolderIcon(
        image: NSImage?,
        missingAssetMessage: String,
        target: [String],
        trigger: String,
        successTitle: String
    ) {
        let title = AssistantLocalized.text(zh: "文件(夹)图标", en: "File/Folder Icon")
        guard validateFolderIconActionTargets(target, title: title) else {
            return
        }

        guard let image else {
            logger.error("Folder icon asset not found")
            showAlert(messageText: title, informativeText: missingAssetMessage, style: .warning)
            return
        }

        updateCustomFolderIcon(
            image,
            target: target,
            trigger: trigger,
            successTitle: successTitle
        )
    }

    private func image(for template: FolderIconTemplate) -> NSImage? {
        if let imagePath = template.imagePath,
           let image = NSImage(contentsOfFile: imagePath) {
            return image
        }

        return NSImage(named: template.assetName)
    }

    func clearCustomFolderIcon(_ target: [String], _ trigger: String) {
        let title = AssistantLocalized.text(zh: "恢复默认图标", en: "Restore Default Icon")
        guard validateFolderIconActionTargets(target, title: title) else {
            return
        }

        updateCustomFolderIcon(
            nil,
            target: target,
            trigger: trigger,
            successTitle: AssistantLocalized.text(zh: "已恢复默认图标", en: "Default Icon Restored")
        )
    }

    func dissolveFolders(_ target: [String], _ trigger: String) {
        let title = AssistantLocalized.text(zh: "解散文件夹", en: "Dissolve Folder")
        guard trigger == "ctx-items" else {
            showAlert(
                messageText: title,
                informativeText: AssistantLocalized.text(
                    zh: "请选中一个或多个文件夹后再执行。",
                    en: "Select one or more folders before running this action."
                ),
                style: .informational
            )
            return
        }

        let selectedPaths = uniqueDecodedPaths(from: target)
        let folderPaths = selectedPaths.filter { isDirectory(atPath: $0) }
        guard !folderPaths.isEmpty, folderPaths.count == selectedPaths.count else {
            showAlert(
                messageText: title,
                informativeText: AssistantLocalized.text(
                    zh: "解散文件夹只能对文件夹使用。",
                    en: "Dissolve Folder can only be used on folders."
                ),
                style: .informational
            )
            return
        }

        let unauthorizedPaths = folderPaths.filter { matchingAuthorizedDirectory(forPath: $0) == nil }
        guard unauthorizedPaths.isEmpty else {
            let samplePath = unauthorizedPaths[0]
            showAlert(
                messageText: title,
                informativeText: AssistantLocalized.text(
                    zh: "所选文件夹不在已授权目录内，无法解散。请先到“通用 > 授权目录”添加对应文件夹。\n\n当前路径：\(samplePath)",
                    en: "The selected folder is outside your authorized folders, so it cannot be dissolved. Add the folder in General > Authorized Folders first.\n\nCurrent path: \(samplePath)"
                ),
                style: .warning
            )
            return
        }

        let unauthorizedParentPaths = folderPaths
            .map { URL(fileURLWithPath: $0).deletingLastPathComponent().path }
            .filter { matchingAuthorizedDirectory(forPath: $0) == nil }
        guard unauthorizedParentPaths.isEmpty else {
            let samplePath = unauthorizedParentPaths[0]
            showAlert(
                messageText: title,
                informativeText: AssistantLocalized.text(
                    zh: "解散文件夹需要写入上级目录。请先到“通用 > 授权目录”添加上级目录。\n\n当前上级目录：\(samplePath)",
                    en: "Dissolving a folder requires write access to its parent folder. Add the parent folder in General > Authorized Folders first.\n\nCurrent parent folder: \(samplePath)"
                ),
                style: .warning
            )
            return
        }

        let accessSnapshots = authorizedDirectoryAccessSnapshots()
        Task.detached(priority: .userInitiated) { [folderPaths, accessSnapshots] in
            let result = AssistantScopedFileWorker.dissolveFolders(
                folderPaths: folderPaths,
                accessSnapshots: accessSnapshots
            )

            await MainActor.run {
                if !result.undoItems.isEmpty {
                    self.registerUndoOperation(
                        kind: .move,
                        items: result.undoItems,
                        bookmarkURLs: result.bookmarkURLs
                    )
                }

                if result.failedMessages.isEmpty {
                    self.showAlert(
                        messageText: AssistantLocalized.text(zh: "解散完成", en: "Dissolve Complete"),
                        informativeText: AssistantLocalized.text(
                            zh: "已解散 \(result.dissolvedFolderCount) 个文件夹，移出 \(result.movedItemCount) 个项目。",
                            en: "Dissolved \(result.dissolvedFolderCount) folder(s) and moved \(result.movedItemCount) item(s)."
                        ),
                        style: .informational
                    )
                    return
                }

                var messageLines: [String] = []
                if result.movedItemCount > 0 {
                    messageLines.append(
                        AssistantLocalized.text(
                            zh: "已移出 \(result.movedItemCount) 个项目，解散 \(result.dissolvedFolderCount) 个文件夹。",
                            en: "Moved \(result.movedItemCount) item(s) and dissolved \(result.dissolvedFolderCount) folder(s)."
                        )
                    )
                }
                messageLines.append(contentsOf: result.failedMessages)

                self.showAlert(
                    messageText: result.movedItemCount > 0
                        ? AssistantLocalized.text(zh: "解散部分失败", en: "Dissolve Partially Failed")
                        : AssistantLocalized.text(zh: "解散失败", en: "Dissolve Failed"),
                    informativeText: messageLines.joined(separator: "\n"),
                    style: .warning
                )
            }
        }
    }

    private func updateCustomFolderIcon(
        _ icon: NSImage?,
        target: [String],
        trigger: String,
        successTitle: String
    ) {
        let folderPaths = uniqueDecodedPaths(from: target).filter { isDirectory(atPath: $0) }
        guard !folderPaths.isEmpty else {
            showAlert(
                messageText: AssistantLocalized.text(zh: "文件(夹)图标", en: "File/Folder Icon"),
                informativeText: AssistantLocalized.text(
                    zh: "请选择一个或多个文件夹后再更换图标。",
                    en: "Select one or more folders before changing the icon."
                ),
                style: .informational
            )
            return
        }

        let unauthorizedPaths = folderPaths.filter { matchingAuthorizedDirectory(forPath: $0) == nil }
        guard unauthorizedPaths.isEmpty else {
            let samplePath = unauthorizedPaths[0]
            showAlert(
                messageText: AssistantLocalized.text(zh: "文件(夹)图标", en: "File/Folder Icon"),
                informativeText: AssistantLocalized.text(
                    zh: "所选文件夹不在已授权目录内，无法更换图标。请先到“通用 > 授权目录”添加对应文件夹。\n\n当前路径：\(samplePath)",
                    en: "The selected folder is outside your authorized folders, so its icon cannot be changed. Add the folder in General > Authorized Folders first.\n\nCurrent path: \(samplePath)"
                ),
                style: .warning
            )
            return
        }

        let accessSnapshots = authorizedDirectoryAccessSnapshots()
        Task.detached(priority: .userInitiated) { [icon, folderPaths, accessSnapshots, successTitle] in
            let result = AssistantScopedFileWorker.applyCustomIcon(
                icon: icon,
                folderPaths: folderPaths,
                accessSnapshots: accessSnapshots
            )

            await MainActor.run {
                if result.updatedCount > 0 {
                    self.showAlert(
                        messageText: successTitle,
                        informativeText: AssistantLocalized.text(
                            zh: "已处理 \(result.updatedCount) 个文件夹。",
                            en: "Processed \(result.updatedCount) folder(s)."
                        ),
                        style: .informational
                    )
                }

                if !result.failedMessages.isEmpty {
                    self.showAlert(
                        messageText: AssistantLocalized.text(zh: "部分文件夹处理失败", en: "Some Folders Failed"),
                        informativeText: result.failedMessages.joined(separator: "\n"),
                        style: .warning
                    )
                }
            }
        }
    }

    private func validateFolderIconActionTargets(_ target: [String], title: String) -> Bool {
        let paths = decodedPaths(from: target)
        guard !paths.isEmpty else {
            showAlert(
                messageText: title,
                informativeText: AssistantLocalized.text(
                    zh: "没有找到可操作的文件夹。",
                    en: "No folder was found for this action."
                ),
                style: .informational
            )
            return false
        }

        return true
    }

    func encryptItemsAsZIP(_ target: [String], _ trigger: String) {
        let title = AssistantLocalized.text(zh: "加密压缩", en: "Encrypt ZIP")
        guard validateSelectionActionTargets(target, trigger, title: title) else {
            return
        }

        let sourcePaths = uniqueDecodedPaths(from: target)
        guard !sourcePaths.isEmpty else {
            showAlert(
                messageText: title,
                informativeText: AssistantLocalized.text(zh: "没有可压缩的文件或文件夹。", en: "There are no files or folders available to compress."),
                style: .informational
            )
            return
        }

        guard let password = promptForArchivePassword(
            title: title,
            informativeText: AssistantLocalized.text(
                zh: "输入密码将创建加密 ZIP；留空则创建普通 ZIP。",
                en: "Enter a password to create an encrypted ZIP, or leave it empty for a regular ZIP."
            ),
            allowEmpty: true,
            passwordPlaceholder: AssistantLocalized.text(
                zh: "请输入密码（选填，留空为普通压缩）",
                en: "Enter password (optional; leave empty for regular ZIP)"
            )
        ) else {
            return
        }

        let normalizedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        performZIPCompression(target, trigger, password: normalizedPassword.isEmpty ? nil : normalizedPassword, title: title)
    }

    private func performZIPCompression(_ target: [String], _ trigger: String, password: String?, title: String) {
        guard validateSelectionActionTargets(target, trigger, title: title) else {
            return
        }

        let sourcePaths = uniqueDecodedPaths(from: target)
        guard !sourcePaths.isEmpty else {
            showAlert(
                messageText: title,
                informativeText: AssistantLocalized.text(zh: "没有可压缩的文件或文件夹。", en: "There are no files or folders available to compress."),
                style: .informational
            )
            return
        }

        let archivePassword = password?.trimmingCharacters(in: .whitespacesAndNewlines)
        let accessSnapshots = authorizedDirectoryAccessSnapshots()
        Task.detached(priority: .userInitiated) { [sourcePaths, archivePassword, accessSnapshots] in
            let result = AssistantScopedFileWorker.performZIPCompression(
                sourcePaths: sourcePaths,
                password: archivePassword,
                accessSnapshots: accessSnapshots
            )

            await MainActor.run {
                if let archiveURL = result.archiveURL {
                    self.registerUndoOperation(
                        kind: .create,
                        items: [.init(originalPath: nil, currentPath: archiveURL.path)],
                        bookmarkURLs: [archiveURL.deletingLastPathComponent()]
                    )

                    self.showAlert(
                        messageText: archivePassword == nil
                            ? AssistantLocalized.text(zh: "压缩完成", en: "Archive Created")
                            : AssistantLocalized.text(zh: "加密压缩完成", en: "Encrypted Archive Created"),
                        informativeText: AssistantLocalized.text(
                            zh: "已创建：\(archiveURL.lastPathComponent)",
                            en: "Created: \(archiveURL.lastPathComponent)"
                        ),
                        style: .informational
                    )
                    return
                }

                self.showAlert(
                    messageText: archivePassword == nil
                        ? AssistantLocalized.text(zh: "压缩失败", en: "Archive Failed")
                        : AssistantLocalized.text(zh: "加密压缩失败", en: "Encrypted Archive Failed"),
                    informativeText: result.failedMessages.joined(separator: "\n"),
                    style: .warning
                )
            }
        }
    }

    func extractZIPArchives(_ target: [String], _ trigger: String) {
        let title = AssistantLocalized.text(zh: "解压 ZIP", en: "Extract ZIP")
        guard validateSelectionActionTargets(target, trigger, title: title) else {
            return
        }

        let archivePaths = uniqueDecodedPaths(from: target)
        guard !archivePaths.isEmpty else {
            showAlert(
                messageText: title,
                informativeText: AssistantLocalized.text(zh: "没有可解压的压缩包。", en: "There are no archives available to extract."),
                style: .informational
            )
            return
        }

        let accessSnapshots = authorizedDirectoryAccessSnapshots()
        Task.detached(priority: .userInitiated) { [archivePaths, accessSnapshots] in
            let result = AssistantScopedFileWorker.performZIPExtraction(
                sourcePaths: archivePaths,
                password: nil,
                accessSnapshots: accessSnapshots
            )

            await MainActor.run {
                if !result.passwordProtectedArchivePaths.isEmpty {
                    self.extractPasswordProtectedZIPArchives(
                        archivePaths: result.passwordProtectedArchivePaths,
                        accessSnapshots: accessSnapshots,
                        previousResult: result,
                        title: title
                    )
                    return
                }
                self.presentZIPExtractionResult(result)
            }
        }
    }

    private func extractPasswordProtectedZIPArchives(
        archivePaths: [String],
        accessSnapshots: [AuthorizedDirectoryAccessSnapshot],
        previousResult: ArchiveExtractionExecutionResult,
        title: String
    ) {
        guard let password = promptForArchivePassword(
            title: title,
            informativeText: AssistantLocalized.text(
                zh: "检测到需要密码的 ZIP。请输入密码后继续解压；普通 ZIP 已自动解压。",
                en: "A password-protected ZIP was found. Enter the password to continue; regular ZIP files were extracted automatically."
            ),
            allowEmpty: false
        ) else {
            presentZIPExtractionResult(previousResult)
            return
        }

        Task.detached(priority: .userInitiated) { [archivePaths, password, accessSnapshots, previousResult] in
            let protectedResult = AssistantScopedFileWorker.performZIPExtraction(
                sourcePaths: archivePaths,
                password: password,
                accessSnapshots: accessSnapshots
            )
            let combinedResult = ArchiveExtractionExecutionResult(
                extractedDirectories: previousResult.extractedDirectories + protectedResult.extractedDirectories,
                failedMessages: previousResult.failedMessages + protectedResult.failedMessages,
                passwordProtectedArchivePaths: protectedResult.passwordProtectedArchivePaths
            )

            await MainActor.run {
                self.presentZIPExtractionResult(combinedResult)
            }
        }
    }

    private func presentZIPExtractionResult(_ result: ArchiveExtractionExecutionResult) {
        if !result.extractedDirectories.isEmpty {
            registerUndoOperation(
                kind: .create,
                items: result.extractedDirectories.map {
                    UndoOperationState.Item(originalPath: nil, currentPath: $0.path)
                },
                bookmarkURLs: result.extractedDirectories.map { $0.deletingLastPathComponent() }
            )
        }

        let remainingPasswordFailures = result.passwordProtectedArchivePaths.map { path in
            let archiveName = URL(fileURLWithPath: path).lastPathComponent
            return AssistantLocalized.text(
                zh: "\(archiveName)：需要输入正确密码后才能解压。",
                en: "\(archiveName): A valid password is required to extract this archive."
            )
        }
        let failedMessages = result.failedMessages + remainingPasswordFailures

        if failedMessages.isEmpty {
            let message: String
            if result.extractedDirectories.count == 1 {
                message = AssistantLocalized.text(
                    zh: "已解压到：\(result.extractedDirectories[0].lastPathComponent)",
                    en: "Extracted to: \(result.extractedDirectories[0].lastPathComponent)"
                )
            } else {
                message = AssistantLocalized.text(
                    zh: "已解压 \(result.extractedDirectories.count) 个压缩包。",
                    en: "Extracted \(result.extractedDirectories.count) archives."
                )
            }

            showAlert(
                messageText: AssistantLocalized.text(zh: "解压完成", en: "Extraction Complete"),
                informativeText: message,
                style: .informational
            )
            return
        }

        var messageLines: [String] = []
        if !result.extractedDirectories.isEmpty {
            messageLines.append(
                AssistantLocalized.text(
                    zh: "已成功解压 \(result.extractedDirectories.count) 个压缩包。",
                    en: "Successfully extracted \(result.extractedDirectories.count) archives."
                )
            )
        }
        messageLines.append(contentsOf: failedMessages)

        showAlert(
            messageText: result.extractedDirectories.isEmpty
                ? AssistantLocalized.text(zh: "解压失败", en: "Extraction Failed")
                : AssistantLocalized.text(zh: "解压部分失败", en: "Extraction Partially Failed"),
            informativeText: messageLines.joined(separator: "\n"),
            style: .warning
        )
    }

    private func shellEscapedPath(_ path: String) -> String {
        "'\(path.replacingOccurrences(of: "'", with: "'\\''"))'"
    }

    func undoLastOperation() {
        guard let state = loadUndoOperation() else {
            showAlert(
                messageText: AssistantLocalized.text(zh: "提示", en: "Notice"),
                informativeText: AssistantLocalized.text(zh: "当前没有可撤销的操作。", en: "There is no operation available to undo."),
                style: .informational
            )
            return
        }

        let accessSnapshots = authorizedDirectoryAccessSnapshots()
        Task.detached(priority: .userInitiated) { [state, accessSnapshots] in
            let result = AssistantScopedFileWorker.performUndo(
                state: state,
                authorizedSnapshots: accessSnapshots
            )

            await MainActor.run {
                if result.remainingItems.isEmpty {
                    self.clearUndoOperation()
                } else {
                    self.saveUndoOperation(
                        UndoOperationState(
                            kind: state.kind,
                            items: result.remainingItems,
                            accessBookmarks: state.accessBookmarks
                        )
                    )
                }

                if !result.failedMessages.isEmpty {
                    self.showAlert(
                        messageText: AssistantLocalized.text(zh: "撤销部分失败", en: "Undo Partially Failed"),
                        informativeText: result.failedMessages.joined(separator: "\n"),
                        style: .warning
                    )
                }
            }
        }
    }

    func showFileInfoCenter(_ target: [String], _ trigger: String) {
        let paths = decodedPaths(from: target)
        guard !paths.isEmpty else {
            showAlert(
                messageText: AssistantLocalized.text(zh: "提示", en: "Notice"),
                informativeText: AssistantLocalized.text(zh: "没有可查看信息的文件或文件夹。", en: "There are no files or folders available to inspect."),
                style: .informational
            )
            return
        }

        guard validateFileInfoTargets(paths) else {
            return
        }

        let directories = appState.effectiveAuthorizedDirectories.map {
            DirectoryAccessSnapshot(rootPath: $0.url.path, bookmark: $0.bookmark)
        }
        let appWasActive = NSApp.isActive
        let window: NSWindow
        let viewModel: FileInfoCenterViewModel

        if let existingWindow = fileInfoWindow,
           let existingViewModel = fileInfoViewModel {
            window = existingWindow
            viewModel = existingViewModel
        } else {
            viewModel = FileInfoCenterViewModel()
            let newWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 760, height: 620),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )

            let hostingController = NSHostingController(
                rootView: FileInfoCenterView(viewModel: viewModel) { [weak newWindow] in
                    newWindow?.close()
                }
                .environment(\.locale, AssistantLocalized.currentLocale)
            )

            newWindow.title = AssistantLocalized.text(zh: "文件信息中心", en: "File Info Center")
            newWindow.contentViewController = hostingController
            newWindow.center()
            newWindow.setFrameAutosaveName("rclick-file-info-center")
            newWindow.isReleasedWhenClosed = false
            newWindow.delegate = self

            fileInfoWindow = newWindow
            fileInfoViewModel = viewModel
            window = newWindow
        }

        dismissAutoPresentedSettingsWindowIfNeeded(appWasActive: appWasActive)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)

        viewModel.load(paths: paths, directories: directories)
    }

    private func validateFileInfoTargets(_ paths: [String]) -> Bool {
        let authorizedDirectories = appState.effectiveAuthorizedDirectories
        guard !authorizedDirectories.isEmpty else {
            showAlert(
                messageText: AssistantLocalized.text(zh: "文件信息中心", en: "File Info Center"),
                informativeText: AssistantLocalized.text(
                    zh: "当前还没有授权目录。请先到“通用 > 授权目录”添加要读取的文件夹，然后再打开文件信息中心。",
                    en: "No authorized folders are configured. Add the folder in General > Authorized Folders before opening File Info Center."
                ),
                style: .informational
            )
            return false
        }

        let unauthorizedPaths = paths
            .map { URL(fileURLWithPath: $0).standardizedFileURL.path }
            .filter { matchingAuthorizedDirectory(forPath: $0) == nil }

        guard unauthorizedPaths.isEmpty else {
            let samplePath = unauthorizedPaths[0]
            showAlert(
                messageText: AssistantLocalized.text(zh: "文件信息中心", en: "File Info Center"),
                informativeText: AssistantLocalized.text(
                    zh: "所选项目不在已授权目录内，无法读取信息。请先到“通用 > 授权目录”添加对应文件夹。\n\n当前路径：\(samplePath)",
                    en: "The selected item is outside your authorized folders, so its information cannot be read. Add the folder in General > Authorized Folders first.\n\nCurrent path: \(samplePath)"
                ),
                style: .informational
            )
            return false
        }

        return true
    }

    private func dismissAutoPresentedSettingsWindowIfNeeded(appWasActive: Bool) {
        guard !appWasActive,
              let settingsWindow = NSApp.windows.first(where: { $0.identifier?.rawValue == Constants.WindowID.settingsPanel }),
              settingsWindow != fileInfoWindow else {
            return
        }

        settingsWindow.close()
    }

    func showBatchRenameCenter(_ target: [String], _ trigger: String) {
        let title = AssistantLocalized.text(zh: "批量命名", en: "Batch Rename")
        guard validateSelectionActionTargets(target, trigger, title: title) else {
            return
        }

        let seeds = makeBatchRenameSeeds(from: target)
        guard !seeds.isEmpty else {
            showAlert(
                messageText: title,
                informativeText: AssistantLocalized.text(zh: "没有可批量命名的文件或文件夹。", en: "There are no files or folders available for batch renaming."),
                style: .informational
            )
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 980, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        let hostingController = NSHostingController(
            rootView: BatchRenameView(
                seeds: seeds,
                onCancel: { [weak window] in
                    window?.close()
                },
                onApply: { [weak self, weak window] operations in
                    self?.performBatchRename(operations)
                    window?.close()
                }
            )
            .environment(\.locale, AssistantLocalized.currentLocale)
        )

        window.title = title
        window.contentViewController = hostingController
        window.center()
        window.setFrameAutosaveName("assistant-batch-rename")
        window.isReleasedWhenClosed = false
        window.delegate = self

        batchRenameWindow?.close()
        batchRenameWindow = window

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func showQRCodeRecognitionCenter(_ target: [String], _ trigger: String) {
        let title = AssistantLocalized.text(zh: "识别二维码", en: "Scan QR Code")
        guard validateSelectionActionTargets(target, trigger, title: title) else {
            return
        }

        let paths = uniqueDecodedPaths(from: target)
        guard !paths.isEmpty else {
            showAlert(
                messageText: title,
                informativeText: AssistantLocalized.text(zh: "没有可识别的文件。", en: "There are no files available to scan."),
                style: .informational
            )
            return
        }

        let viewModel = QRCodeRecognitionViewModel()
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 860, height: 620),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        let hostingController = NSHostingController(
            rootView: QRCodeRecognitionView(viewModel: viewModel) { [weak window] in
                window?.close()
            }
            .environment(\.locale, AssistantLocalized.currentLocale)
        )

        window.title = title
        window.contentViewController = hostingController
        window.center()
        window.setFrameAutosaveName("assistant-qr-code-recognition")
        window.isReleasedWhenClosed = false
        window.delegate = self

        qrCodeWindow?.close()
        qrCodeWindow = window

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)

        viewModel.load(paths: paths, directories: authorizedDirectoryAccessSnapshots())
    }

    func showImageTextRecognitionCenter(_ target: [String], _ trigger: String) {
        let title = AssistantLocalized.text(zh: "图片文案提取", en: "Extract Image Text")
        guard validateSelectionActionTargets(target, trigger, title: title) else {
            return
        }

        let paths = uniqueDecodedPaths(from: target)
        guard !paths.isEmpty else {
            showAlert(
                messageText: title,
                informativeText: AssistantLocalized.text(zh: "没有可识别的文件。", en: "There are no files available to scan."),
                style: .informational
            )
            return
        }

        let viewModel = ImageTextRecognitionViewModel()
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 660),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        let hostingController = NSHostingController(
            rootView: ImageTextRecognitionView(viewModel: viewModel) { [weak window] in
                window?.close()
            }
            .environment(\.locale, AssistantLocalized.currentLocale)
        )

        window.title = title
        window.contentViewController = hostingController
        window.center()
        window.setFrameAutosaveName("assistant-image-text-recognition")
        window.isReleasedWhenClosed = false
        window.delegate = self

        imageTextWindow?.close()
        imageTextWindow = window

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)

        viewModel.load(paths: paths, directories: authorizedDirectoryAccessSnapshots())
    }

    func takeScreenshot(_ target: [String], _ trigger: String) {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true

        let screenshotAppURL = URL(fileURLWithPath: "/System/Applications/Utilities/Screenshot.app")
        if FileManager.default.fileExists(atPath: screenshotAppURL.path) {
            NSWorkspace.shared.openApplication(at: screenshotAppURL, configuration: configuration) { _, error in
                guard let error else {
                    return
                }

                Task { @MainActor in
                    self.launchInteractiveScreencaptureFallback(previousError: error)
                }
            }
            return
        }

        launchInteractiveScreencaptureFallback(previousError: nil)
    }

    func lockScreen(_ target: [String], _ trigger: String) {
        if lockScreenUsingSystemHelperIfAvailable() {
            return
        }

        showAlert(
            messageText: AssistantLocalized.text(zh: "锁屏失败", en: "Lock Screen Failed"),
            informativeText: AssistantLocalized.text(
                zh: "无法调用系统锁屏工具，请使用系统菜单或快捷键锁定屏幕。",
                en: "The system lock screen tool could not be launched. Use the system menu or keyboard shortcut to lock the screen."
            ),
            style: .warning
        )
    }

    func toggleSystemAppearance(_ target: [String], _ trigger: String) {
        let candidateURLs = [
            "x-apple.systempreferences:com.apple.Appearance-Settings.extension",
            "x-apple.systempreferences:com.apple.preference.general?Appearance"
        ]

        for urlString in candidateURLs {
            guard let url = URL(string: urlString) else {
                continue
            }

            NSWorkspace.shared.open(url)
            return
        }

        showAlert(
            messageText: AssistantLocalized.text(zh: "打开外观设置失败", en: "Could Not Open Appearance Settings"),
            informativeText: AssistantLocalized.text(
                zh: "请手动打开“系统设置 > 外观”调整深色或浅色模式。",
                en: "Open System Settings > Appearance manually to change light or dark mode."
            ),
            style: .warning
        )
    }

    func sendShortcutToDesktop(_ target: [String], _ trigger: String) {
        let title = AssistantLocalized.text(zh: "发送快捷方式到桌面", en: "Send Shortcut to Desktop")
        guard validateSelectionActionTargets(target, trigger, title: title) else {
            return
        }

        let sourcePaths = uniqueDecodedPaths(from: target)
        guard !sourcePaths.isEmpty else {
            showAlert(
                messageText: title,
                informativeText: AssistantLocalized.text(
                    zh: "没有可创建快捷方式的文件或文件夹。",
                    en: "There are no files or folders available for shortcut creation."
                ),
                style: .informational
            )
            return
        }

        guard let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first?.standardizedFileURL else {
            showAlert(
                messageText: title,
                informativeText: AssistantLocalized.text(
                    zh: "无法定位桌面目录。",
                    en: "Could not locate the Desktop folder."
                ),
                style: .warning
            )
            return
        }

        guard matchingAuthorizedDirectory(forPath: desktopURL.path) != nil else {
            showAlert(
                messageText: title,
                informativeText: AssistantLocalized.text(
                    zh: "桌面目录未授权，无法创建快捷方式。请先到“通用 > 授权目录”添加桌面或其上级目录。",
                    en: "The Desktop folder is not authorized, so shortcuts cannot be created. Add Desktop or one of its parent folders in General > Authorized Folders first."
                ),
                style: .warning
            )
            return
        }

        let accessSnapshots = authorizedDirectoryAccessSnapshots()
        Task.detached(priority: .userInitiated) { [sourcePaths, desktopURL, accessSnapshots] in
            let result = AssistantScopedFileWorker.createDesktopAliases(
                sourcePaths: sourcePaths,
                desktopURL: desktopURL,
                accessSnapshots: accessSnapshots
            )

            await MainActor.run {
                if !result.createdURLs.isEmpty {
                    self.registerUndoOperation(
                        kind: .create,
                        items: result.createdURLs.map {
                            UndoOperationState.Item(originalPath: nil, currentPath: $0.path)
                        },
                        bookmarkURLs: [desktopURL]
                    )
                }

                if result.failedMessages.isEmpty {
                    self.showAlert(
                        messageText: AssistantLocalized.text(zh: "快捷方式已创建", en: "Shortcut Created"),
                        informativeText: AssistantLocalized.text(
                            zh: "已在桌面创建 \(result.createdURLs.count) 个快捷方式。",
                            en: "Created \(result.createdURLs.count) shortcut(s) on the Desktop."
                        ),
                        style: .informational
                    )
                    return
                }

                var messageLines: [String] = []
                if !result.createdURLs.isEmpty {
                    messageLines.append(
                        AssistantLocalized.text(
                            zh: "已成功创建 \(result.createdURLs.count) 个快捷方式。",
                            en: "Successfully created \(result.createdURLs.count) shortcut(s)."
                        )
                    )
                }
                messageLines.append(contentsOf: result.failedMessages)

                self.showAlert(
                    messageText: result.createdURLs.isEmpty
                        ? AssistantLocalized.text(zh: "快捷方式创建失败", en: "Shortcut Creation Failed")
                        : AssistantLocalized.text(zh: "快捷方式部分创建失败", en: "Shortcut Creation Partially Failed"),
                    informativeText: messageLines.joined(separator: "\n"),
                    style: .warning
                )
            }
        }
    }

    private func launchInteractiveScreencaptureFallback(previousError: Error?) {
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            process.arguments = ["-i", "-U"]

            do {
                try process.run()
                process.waitUntilExit()

                guard process.terminationStatus == 0 else {
                    throw NSError(
                        domain: "RightClickAssistantPro.Screenshot",
                        code: Int(process.terminationStatus),
                        userInfo: [
                            NSLocalizedDescriptionKey: AssistantLocalized.text(
                                zh: "系统截图工具未能正常启动。",
                                en: "The system screenshot tool did not launch successfully."
                            )
                        ]
                    )
                }
            } catch let currentError {
                let message = [previousError, currentError]
                    .compactMap { $0?.localizedDescription }
                    .joined(separator: "\n")

                Task { @MainActor in
                    self.showAlert(
                        messageText: AssistantLocalized.text(zh: "截图失败", en: "Screenshot Failed"),
                        informativeText: message.isEmpty
                            ? AssistantLocalized.text(
                                zh: "无法启动系统截图工具，请确认系统 Screenshot.app 可用。",
                                en: "Unable to launch the system screenshot tool. Make sure Screenshot.app is available."
                            )
                            : message,
                        style: .warning
                    )
                }
            }
        }
    }

    private func runCommand(executablePath: String, arguments: [String]) -> Bool {
        guard FileManager.default.isExecutableFile(atPath: executablePath) else {
            logger.warning("Command is not executable or missing: \(executablePath, privacy: .public)")
            return false
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    private func lockScreenUsingSystemHelperIfAvailable() -> Bool {
        let cgSessionPaths = [
            "/System/Library/CoreServices/Menu Extras/User.menu/Contents/Resources/CGSession",
            "/System/Library/CoreServices/CGSession"
        ]

        for path in cgSessionPaths where FileManager.default.isExecutableFile(atPath: path) {
            if runCommand(executablePath: path, arguments: ["-suspend"]) {
                logger.info("Lock screen succeeded using CGSession path=\(path, privacy: .public)")
                return true
            }
        }

        let pmsetPath = "/usr/bin/pmset"
        if runCommand(executablePath: pmsetPath, arguments: ["displaysleepnow"]) {
            logger.info("Lock screen succeeded using pmset displaysleepnow")
            return true
        }

        logger.info("System lock screen helpers are unavailable")
        return false
    }

    func validateSelectionActionTargets(_ target: [String], _ trigger: String, title: String) -> Bool {
        let paths = decodedPaths(from: target)
        guard !paths.isEmpty else {
            showAlert(
                messageText: title,
                informativeText: AssistantLocalized.text(zh: "没有找到可操作的文件或文件夹。", en: "No files or folders were found for this action."),
                style: .informational
            )
            return false
        }

        guard trigger != "ctx-container" else {
            showAlert(
                messageText: title,
                informativeText: AssistantLocalized.text(zh: "请先选择文件或文件夹，再执行这个操作。", en: "Select files or folders first, then run this action."),
                style: .informational
            )
            return false
        }

        return true
    }

    func chooseDestinationDirectory(title: String) -> URL? {
        NSApp.activate(ignoringOtherApps: true)

        let openPanel = NSOpenPanel()
        openPanel.title = title
        openPanel.message = AssistantLocalized.text(zh: "请选择目标文件夹", en: "Choose a destination folder")
        openPanel.prompt = title
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.allowsMultipleSelection = false
        openPanel.canCreateDirectories = true
        openPanel.directoryURL = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)

        return openPanel.runModal() == .OK ? openPanel.urls.first : nil
    }

    func promptForArchivePassword(
        title: String,
        informativeText: String,
        allowEmpty: Bool,
        passwordPlaceholder: String = AssistantLocalized.text(zh: "请输入密码", en: "Enter password")
    ) -> String? {
        NSApp.activate(ignoringOtherApps: true)

        while true {
            let promptController = ArchivePasswordPromptController(
                title: title,
                informativeText: informativeText,
                passwordPlaceholder: passwordPlaceholder
            )

            guard promptController.runModal() == .OK else {
                return nil
            }

            let password = promptController.passwordField.stringValue
            if !allowEmpty && password.isEmpty {
                showAlert(
                    messageText: title,
                    informativeText: AssistantLocalized.text(zh: "密码不能为空。", en: "The password cannot be empty."),
                    style: .warning,
                    delivery: .modal
                )
                continue
            }

            return password
        }
    }

    func resolvePasteDestination(_ target: [String], _ trigger: String) -> URL? {
        let paths = decodedPaths(from: target)
        guard let firstPath = paths.first else { return nil }

        if trigger == "ctx-container" {
            return URL(fileURLWithPath: firstPath, isDirectory: true)
        }

        if paths.count == 1, isDirectory(atPath: firstPath) {
            return URL(fileURLWithPath: firstPath, isDirectory: true)
        }

        let parentPaths = Set(paths.map { URL(fileURLWithPath: $0).deletingLastPathComponent().path })
        guard parentPaths.count == 1, let parentPath = parentPaths.first else {
            return nil
        }

        return URL(fileURLWithPath: parentPath, isDirectory: true)
    }

    func filePathsFromSystemClipboard() -> [String] {
        let pasteboard = NSPasteboard.general
        let fileURLType = NSPasteboard.PasteboardType("public.file-url")
        let legacyFileNamesType = NSPasteboard.PasteboardType("NSFilenamesPboardType")
        var paths: [String] = []

        let options: [NSPasteboard.ReadingOptionKey: Any] = [
            .urlReadingFileURLsOnly: true
        ]
        let urlObjects = pasteboard.readObjects(forClasses: [NSURL.self], options: options) ?? []
        paths.append(contentsOf: urlObjects.compactMap { object in
            if let url = object as? URL, url.isFileURL {
                return url.path
            }

            guard let url = object as? NSURL, url.isFileURL else {
                return nil
            }

            return url.path
        })

        pasteboard.pasteboardItems?.forEach { item in
            guard let rawValue = item.string(forType: fileURLType) else {
                return
            }

            if let url = URL(string: rawValue), url.isFileURL {
                paths.append(url.path)
            } else if rawValue.hasPrefix("/") {
                paths.append(rawValue)
            }
        }

        if let legacyPaths = pasteboard.propertyList(forType: legacyFileNamesType) as? [String] {
            paths.append(contentsOf: legacyPaths)
        }

        var seen: Set<String> = []
        return paths
            .map { URL(fileURLWithPath: $0).standardizedFileURL.path }
            .filter { FileManager.default.fileExists(atPath: $0) }
            .filter { seen.insert($0).inserted }
    }

    func pngImageDataFromSystemClipboard() -> Data? {
        let pasteboard = NSPasteboard.general

        if let image = NSImage(pasteboard: pasteboard),
           let pngData = pngData(from: image) {
            return pngData
        }

        for type in [NSPasteboard.PasteboardType.png, .tiff] where pasteboard.availableType(from: [type]) != nil {
            guard let data = pasteboard.data(forType: type) else {
                continue
            }

            if type == .png {
                return data
            }

            if let image = NSImage(data: data),
               let pngData = pngData(from: image) {
                return pngData
            }
        }

        return nil
    }

    private func pngData(from image: NSImage) -> Data? {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return nil
        }

        return bitmap.representation(using: .png, properties: [:])
    }

    func pasteImageData(_ imageData: Data, to destinationURL: URL) {
        let targetURL = uniquePastedImageURL(in: destinationURL)

        do {
            try imageData.write(to: targetURL, options: .atomic)
            registerUndoOperation(
                kind: .create,
                items: [.init(originalPath: nil, currentPath: targetURL.path)],
                bookmarkURLs: [destinationURL]
            )
        } catch {
            showAlert(
                messageText: AssistantLocalized.text(zh: "粘贴图片失败", en: "Paste Image Failed"),
                informativeText: error.localizedDescription,
                style: .warning
            )
        }
    }

    private func uniquePastedImageURL(in directoryURL: URL) -> URL {
        let baseName = AssistantLocalized.text(zh: "粘贴图片", en: "Pasted Image")
        let fileManager = FileManager.default
        var candidateURL = directoryURL.appendingPathComponent("\(baseName).png")
        var counter = 1

        while fileManager.fileExists(atPath: candidateURL.path) {
            candidateURL = directoryURL.appendingPathComponent("\(baseName)\(counter).png")
            counter += 1
        }

        return candidateURL
    }

    func transferItems(
        _ sourceItems: [String],
        destinationURL: URL,
        moveItems: Bool,
        clearClipboardOnSuccess: Bool = false
    ) {
        let sourcePaths = decodedPaths(from: sourceItems)

        guard !sourcePaths.isEmpty else {
            showAlert(
                messageText: AssistantLocalized.text(zh: "提示", en: "Notice"),
                informativeText: AssistantLocalized.text(zh: "没有可处理的文件或文件夹。", en: "There are no files or folders available to process."),
                style: .informational
            )
            return
        }

        let accessSnapshots = authorizedDirectoryAccessSnapshots()

        Task.detached(priority: .userInitiated) { [sourcePaths, destinationURL, moveItems, clearClipboardOnSuccess, accessSnapshots] in
            let result = AssistantScopedFileWorker.performTransfer(
                sourcePaths: sourcePaths,
                destinationURL: destinationURL,
                moveItems: moveItems,
                clearClipboardOnSuccess: clearClipboardOnSuccess,
                accessSnapshots: accessSnapshots
            )

            await MainActor.run {
                if !result.undoItems.isEmpty {
                    let undoKind: UndoOperationState.Kind = moveItems ? .move : .copy
                    self.registerUndoOperation(
                        kind: undoKind,
                        items: result.undoItems,
                        bookmarkURLs: result.bookmarkURLs
                    )
                }

                if result.shouldClearClipboard {
                    self.clearClipboardOperation()
                }

                if !result.failedMessages.isEmpty {
                    self.showAlert(
                        messageText: moveItems
                            ? AssistantLocalized.text(zh: "移动部分失败", en: "Move Partially Failed")
                            : AssistantLocalized.text(zh: "复制部分失败", en: "Copy Partially Failed"),
                        informativeText: result.failedMessages.joined(separator: "\n"),
                        style: .warning
                    )
                }
            }
        }
    }

    func performBatchRename(_ operations: [BatchRenameOperation]) {
        guard !operations.isEmpty else {
            showAlert(
                messageText: AssistantLocalized.text(zh: "批量命名", en: "Batch Rename"),
                informativeText: AssistantLocalized.text(zh: "当前没有需要应用的更名项。", en: "There are no rename changes to apply."),
                style: .informational
            )
            return
        }

        let accessSnapshots = authorizedDirectoryAccessSnapshots()

        Task.detached(priority: .userInitiated) { [operations, accessSnapshots] in
            let result = AssistantScopedFileWorker.performBatchRename(
                operations: operations,
                accessSnapshots: accessSnapshots
            )

            await MainActor.run {
                if !result.undoItems.isEmpty {
                    self.registerUndoOperation(
                        kind: .rename,
                        items: result.undoItems,
                        bookmarkURLs: result.bookmarkURLs
                    )
                }

                if !result.failedMessages.isEmpty {
                    self.showAlert(
                        messageText: result.undoItems.isEmpty
                            ? AssistantLocalized.text(zh: "批量命名失败", en: "Batch Rename Failed")
                            : AssistantLocalized.text(zh: "批量命名部分失败", en: "Batch Rename Partially Failed"),
                        informativeText: result.failedMessages.joined(separator: "\n"),
                        style: .warning
                    )
                }
            }
        }
    }

    func makeBatchRenameSeeds(from target: [String]) -> [BatchRenameSeed] {
        uniqueDecodedPaths(from: target).compactMap { path in
            let itemURL = URL(fileURLWithPath: path)
            let originalName = itemURL.lastPathComponent

            guard !originalName.isEmpty else {
                return nil
            }

            let itemIsDirectory = isDirectory(atPath: path)
            let preservedExtension: String
            let editableName: String

            if itemIsDirectory || itemURL.pathExtension.isEmpty {
                preservedExtension = ""
                editableName = originalName
            } else {
                preservedExtension = ".\(itemURL.pathExtension)"
                editableName = itemURL.deletingPathExtension().lastPathComponent
            }

            return BatchRenameSeed(
                path: itemURL.standardizedFileURL.path,
                directoryPath: itemURL.deletingLastPathComponent().standardizedFileURL.path,
                originalName: originalName,
                editableName: editableName,
                preservedExtension: preservedExtension,
                isDirectory: itemIsDirectory
            )
        }
    }
}
