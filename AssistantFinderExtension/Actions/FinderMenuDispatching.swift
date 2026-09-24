//
//  FinderMenuDispatching.swift
//  RightClickAssistantPro
//
//  Created by 李旭 on 2024/4/7.
//

import AppKit
import Foundation
import os.log

private let legacyMenuLogger = makeAssistantLogger(subsystem: subsystem, category: "menu_click")

typealias AppMenuItem = OpenWithApplication
typealias ActionMenuItem = ContextQuickAction

protocol FinderMenuDispatching {
    func menuClick(with urls: [URL])
}

extension AppMenuItem: FinderMenuDispatching {
    func menuClick(with urls: [URL]) {
        legacyMenuLogger.notice("legacy app dispatch retained for compatibility, urls: \(urls.count)")
    }
}

private enum LegacyFinderAction: Int {
    case copyPaths
    case copyDisplayNames
    case revealContainers
    case createBlankFile

    func run(with urls: [URL]) -> FinderMenuDispatchResult {
        switch self {
        case .copyPaths:
            return LegacyClipboardWriter.write(values: urls.map(\.path))
        case .copyDisplayNames:
            return LegacyClipboardWriter.write(values: urls.map(\.lastPathComponent))
        case .revealContainers:
            return revealContainers(for: urls)
        case .createBlankFile:
            return createBlankFiles(in: urls)
        }
    }

    private func revealContainers(for urls: [URL]) -> FinderMenuDispatchResult {
        let nestedResults = urls.map { url in
            FinderMenuDispatchResult(
                success: NSWorkspace.shared.selectFile(
                    url.deletingLastPathComponent().path,
                    inFileViewerRootedAtPath: ""
                )
            )
        }
        return .aggregate(nestedResults, message: "reveal parent directory")
    }

    private func createBlankFiles(in urls: [URL]) -> FinderMenuDispatchResult {
        let nestedResults = urls.map { itemURL in
            let destinationURL = LegacyFileCreationTarget.resolve(from: itemURL)
            legacyMenuLogger.notice("Trying to create empty file at \(destinationURL.path)")
            return FinderMenuDispatchResult(
                success: FileManager.default.createFile(
                    atPath: destinationURL.path,
                    contents: Data(),
                    attributes: nil
                )
            )
        }
        return .aggregate(nestedResults, message: "create empty file")
    }
}

private enum LegacyCopyFormatting {
    case raw
    case shellEscaped
    case wrappedInQuotes

    static var current: LegacyCopyFormatting {
        switch UserDefaults.group.string(forKey: "COPY_OPTION") {
        case "escape":
            return .shellEscaped
        case "quoto":
            return .wrappedInQuotes
        default:
            return .raw
        }
    }

    func apply(to value: String) -> String {
        switch self {
        case .raw:
            return value
        case .shellEscaped:
            return value.replacingOccurrences(of: " ", with: #"\ "#)
        case .wrappedInQuotes:
            return "\"\(value)\""
        }
    }
}

private enum LegacyClipboardWriter {
    static func write(values: [String]) -> FinderMenuDispatchResult {
        let pasteboard = NSPasteboard.general
        let formatting = LegacyCopyFormatting.current
        let joinedValue = values
            .map { formatting.apply(to: $0) }
            .joined(separator: UserDefaults.group.copySeparator)

        pasteboard.clearContents()
        let didWrite = pasteboard.setString(joinedValue, forType: .string)
        return FinderMenuDispatchResult(
            success: didWrite,
            message: "pasteboard updated"
        )
    }
}

private enum LegacyFileCreationTarget {
    static func resolve(from selectedURL: URL) -> URL {
        let configuredName = UserDefaults.group.newFileName
        let configuredExtension = UserDefaults.group.newFileExtension.rawValue
        let baseDirectory = FileManager.default.isDirectory(at: selectedURL)
            ? selectedURL
            : selectedURL.deletingLastPathComponent()

        return baseDirectory
            .appendingPathComponent(configuredName)
            .appendingPathExtension(configuredExtension)
    }
}

extension ActionMenuItem: FinderMenuDispatching {
    func menuClick(with urls: [URL]) {
        let result = LegacyFinderAction(rawValue: idx)?.run(with: urls)
            ?? FinderMenuDispatchResult(success: false, message: "Unsupported legacy action index \(idx)")

        if result.success {
            legacyMenuLogger.notice("\(result.description)")
        } else {
            legacyMenuLogger.error("\(result.description)")
        }
    }
}

struct FinderMenuDispatchResult: CustomStringConvertible {
    var success = false
    var message: String?
    var subResults: [FinderMenuDispatchResult]?

    static func aggregate(_ nestedResults: [FinderMenuDispatchResult], message: String) -> FinderMenuDispatchResult {
        FinderMenuDispatchResult(
            success: nestedResults.allSatisfy(\.success),
            message: message,
            subResults: nestedResults
        )
    }

    var description: String {
        var parts: [String] = ["FinderMenuDispatchResult(success: \(success ? "yes" : "no"))"]

        if let message, !message.isEmpty {
            parts.append("message: \(message)")
        }

        if let subResults, !subResults.isEmpty {
            parts.append(contentsOf: subResults.map(\.description))
        }

        return parts.joined(separator: "\n")
    }
}

private extension FileManager {
    func isDirectory(at url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        let exists = fileExists(atPath: url.path, isDirectory: &isDirectory)
        return exists && isDirectory.boolValue
    }
}
