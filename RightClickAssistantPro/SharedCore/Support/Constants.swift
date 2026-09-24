//
//  Constants.swift
//  RightClickAssistantPro
//
//  Created by 老谭 on 2026/4/30.
//

import Foundation

public enum Constants {
    enum WindowID {
        static let settingsPanel = "assistant-settings-panel"
        static let featureModulePrefix = "assistant-feature-module-"
    }

    static var appGroupIdentifier: String {
        "group.rightPro.touch.com"
    }

    static let protectedDirs: [String] = {
        let homePath = Utils.getRealHomeDir()
        let homeScopedDirectories = [
            "Desktop",
            "Desktop/danger",
            "Applications"
        ].map { ensureDirectoryPath("\(homePath)/\($0)") }

        let systemRoots = [
            "/Applications",
            "/System",
            "/Library",
            "/Users",
            "/usr",
            "/bin",
            "/sbin",
            "/var"
        ].map(ensureDirectoryPath)

        return homeScopedDirectories + systemRoots
    }()

    private static func ensureDirectoryPath(_ path: String) -> String {
        let normalized = URL(fileURLWithPath: path, isDirectory: true)
            .standardizedFileURL
            .path
        return normalized.hasSuffix("/") ? normalized : normalized + "/"
    }
}


