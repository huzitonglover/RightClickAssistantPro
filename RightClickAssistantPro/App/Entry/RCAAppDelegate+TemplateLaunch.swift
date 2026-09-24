//
//  RCAAppDelegate+TemplateLaunch.swift
//  RightClickAssistantPro
//
//  Created by 老谭 on 2026/4/30.
//

import AppKit
import Foundation

private enum AssistantTemplateSeedLibrary {
    private static let inlineTemplates: [String: Data] = [
        ".txt": Data("New text file\n".utf8),
        ".md": Data("# New Markdown File\n".utf8),
        ".xml": Data(
            """
            <?xml version="1.0" encoding="UTF-8"?>
            <root/>
            """.utf8
        ),
        ".rtf": Data("{\\rtf1\\ansi\\deff0\n}\n".utf8)
    ]

    static func bundledTemplateURL(for ext: String, in bundle: Bundle = .main) -> URL? {
        let normalizedExtension = ext.replacingOccurrences(of: ".", with: "")
        return bundle.url(forResource: "assistant-seed", withExtension: normalizedExtension)
    }

    static func inlineTemplateData(for ext: String) -> Data? {
        inlineTemplates[ext.lowercased()]
    }

    static func requiresStructuredTemplate(for ext: String) -> Bool {
        switch ext.lowercased() {
        case ".docx", ".pptx", ".xlsx", ".wps", ".et", ".dps", ".pages", ".numbers", ".key", ".ai", ".psd":
            return true
        default:
            return false
        }
    }
}

private enum AssistantFileNaming {
    static func uniqueFileURL(
        in directoryPath: String,
        ext: String,
        fileManager: FileManager = .default
    ) -> URL {
        let baseFileName = AssistantLocalized.text(zh: "未命名", en: "Untitled")
        let directoryURL = URL(fileURLWithPath: directoryPath, isDirectory: true)
        var candidateURL = directoryURL.appendingPathComponent(baseFileName + ext)
        var counter = 1

        while fileManager.fileExists(atPath: candidateURL.path) {
            candidateURL = directoryURL.appendingPathComponent("\(baseFileName)\(counter)\(ext)")
            counter += 1
        }

        return candidateURL
    }

    static func uniqueFolderURL(
        in directoryPath: String,
        fileManager: FileManager = .default
    ) -> URL {
        let baseFolderName = AssistantLocalized.text(zh: "新建文件夹", en: "New Folder")
        let directoryURL = URL(fileURLWithPath: directoryPath, isDirectory: true)
        var candidateURL = directoryURL.appendingPathComponent(baseFolderName, isDirectory: true)
        var counter = 1

        while fileManager.fileExists(atPath: candidateURL.path) {
            candidateURL = directoryURL.appendingPathComponent("\(baseFolderName)\(counter)", isDirectory: true)
            counter += 1
        }

        return candidateURL
    }
}

extension RCAAppDelegate {
    func createFolder(_ target: [String], _ trigger: String) {
        Task { @MainActor in
            guard let targetPath = target.first else {
                logger.warning("createFolder has no target")
                return
            }

            let directoryPath = normalizedCreateDestinationDirectoryPath(from: targetPath)
            let folderURL = AssistantFileNaming.uniqueFolderURL(in: directoryPath)

            guard let authorizedDirectory = matchingAuthorizedDirectory(forPath: directoryPath) else {
                logger.warning("No authorized directory matched create folder target: \(directoryPath)")
                showAlert(
                    messageText: AssistantLocalized.text(zh: "目录未授权", en: "Folder Not Authorized"),
                    informativeText: AssistantLocalized.text(
                        zh: "请在设置 > 通用 > 授权目录中添加该目录或其上级目录后，再新建文件夹。\n当前目录：\(directoryPath)",
                        en: "Add this folder or one of its parent folders in Settings > General > Authorized Folders before creating a new folder.\nCurrent folder: \(directoryPath)"
                    ),
                    style: .warning
                )
                return
            }

            var isStale = false
            do {
                let scopedURL = try URL(
                    resolvingBookmarkData: authorizedDirectory.bookmark,
                    options: .withSecurityScope,
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )

                guard scopedURL.startAccessingSecurityScopedResource() else {
                    logger.warning("fail access scope \(authorizedDirectory.url.path)")
                    return
                }
                defer { scopedURL.stopAccessingSecurityScopedResource() }

                try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: false)
                registerUndoOperation(
                    kind: .create,
                    items: [.init(originalPath: nil, currentPath: folderURL.path)],
                    bookmarkURLs: [folderURL.deletingLastPathComponent()]
                )

                if UserDefaults.group.newFileCreationSoundEnabled {
                    NSSound(named: "Pop")?.play()
                }
            } catch {
                showAlert(
                    messageText: AssistantLocalized.text(zh: "新建文件夹失败", en: "New Folder Failed"),
                    informativeText: error.localizedDescription,
                    style: .warning
                )
            }
        }
    }

    func createFile(rid: String, target: [String]) {
        Task { @MainActor in
            guard let fileTemplate = appState.getFileType(rid: rid),
                  let targetPath = target.first
            else {
                logger.warning("when createFile,but not have fileType \(rid) ")
                return
            }

            let directoryPath = normalizedCreateDestinationDirectoryPath(from: targetPath)
            let fileURL = AssistantFileNaming.uniqueFileURL(in: directoryPath, ext: fileTemplate.ext)
            logger.info("create file dir:\(directoryPath) -- ext \(fileTemplate.ext)")

            guard let authorizedDirectory = matchingAuthorizedDirectory(forPath: directoryPath) else {
                logger.warning("No authorized directory matched create target: \(directoryPath)")
                showAlert(
                    messageText: AssistantLocalized.text(zh: "目录未授权", en: "Folder Not Authorized"),
                    informativeText: AssistantLocalized.text(
                        zh: "请在设置 > 通用 > 授权目录中添加桌面或其上级目录后，再使用新建文件。\n当前目录：\(directoryPath)",
                        en: "Add Desktop or one of its parent folders in Settings > General > Authorized Folders before creating a new file.\nCurrent folder: \(directoryPath)"
                    ),
                    style: .warning
                )
                return
            }

            var isStale = false
            do {
                let scopedURL = try URL(
                    resolvingBookmarkData: authorizedDirectory.bookmark,
                    options: .withSecurityScope,
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )

                guard scopedURL.startAccessingSecurityScopedResource() else {
                    logger.warning("fail access scope \(authorizedDirectory.url.path)")
                    return
                }
                defer { scopedURL.stopAccessingSecurityScopedResource() }

                guard try materializeTemplate(fileTemplate, at: fileURL) else {
                    return
                }

                registerUndoOperation(
                    kind: .create,
                    items: [.init(originalPath: nil, currentPath: fileURL.path)],
                    bookmarkURLs: [fileURL.deletingLastPathComponent()]
                )

                if UserDefaults.group.newFileCreationSoundEnabled {
                    NSSound(named: "Pop")?.play()
                }

                if UserDefaults.group.openNewFileAfterCreation {
                    NSWorkspace.shared.open(fileURL)
                }
            } catch {
                logger.error("解析 bookmark 失败：\(error.localizedDescription)")
            }
        }
    }

    private func normalizedCreateDestinationDirectoryPath(from targetPath: String) -> String {
        let decodedPath = targetPath.removingPercentEncoding ?? targetPath
        let targetURL = URL(fileURLWithPath: decodedPath).standardizedFileURL

        if isDirectory(atPath: targetURL.path) {
            return targetURL.path
        }

        return targetURL.deletingLastPathComponent().standardizedFileURL.path
    }

    func openApp(rid: String, target: [String]) {
        Task { @MainActor in
            guard let appItem = appState.getAppItem(rid: rid) else {
                logger.warning("when openapp,but not have app \(rid)")
                return
            }

            let configuration = NSWorkspace.OpenConfiguration()
            configuration.promptsUserIfNeeded = false
            configuration.arguments = appItem.arguments
            configuration.environment = appItem.environment

            for path in target {
                let directoryURL = URL(fileURLWithPath: path.removingPercentEncoding ?? path, isDirectory: true)
                logger.info("starting open dir .........\(directoryURL.path), app:\(appItem.url.path)")

                NSWorkspace.shared.open([directoryURL], withApplicationAt: appItem.url, configuration: configuration) { [weak self] runningApp, error in
                    Task { @MainActor [weak self] in
                        guard let self else {
                            return
                        }

                        if let error {
                            self.logger.error("Error opening application: \(error.localizedDescription)")
                        } else if let runningApp {
                            self.logger.info("Successfully opened application: \(runningApp.localizedName ?? "Unknown")")
                        }
                    }
                }
            }        
        }
    }

    private func materializeTemplate(_ template: NewFileTemplate, at fileURL: URL) throws -> Bool {
        let fileManager = FileManager.default

        if let customTemplateURL = template.template {
            try fileManager.copyItem(at: customTemplateURL, to: fileURL)
            logger.info("已成功复制模板到目标路径: \(fileURL.path)")
            return true
        }

        if let bundledTemplateURL = AssistantTemplateSeedLibrary.bundledTemplateURL(for: template.ext) {
            logger.info("使用模板创建文件，模板路径: \(bundledTemplateURL.path)")
            try fileManager.copyItem(at: bundledTemplateURL, to: fileURL)
            logger.info("已成功复制模板到目标路径: \(fileURL.path)")
            return true
        }

        logger.warning("模板文件不存在: \(template.ext)")
        if AssistantTemplateSeedLibrary.requiresStructuredTemplate(for: template.ext) {
            showAlert(
                messageText: AssistantLocalized.text(zh: "创建失败", en: "Creation Failed"),
                informativeText: AssistantLocalized.text(
                    zh: "\(template.ext.uppercased().replacingOccurrences(of: ".", with: "")) 模板缺失，暂时无法创建该文件类型。",
                    en: "The \(template.ext.uppercased().replacingOccurrences(of: ".", with: "")) template is missing, so this file type cannot be created right now."
                ),
                style: .warning
            )
            return false
        }

        if let templateData = AssistantTemplateSeedLibrary.inlineTemplateData(for: template.ext) {
            try templateData.write(to: fileURL)
            return true
        }

        try Data().write(to: fileURL)
        return true
    }
}
