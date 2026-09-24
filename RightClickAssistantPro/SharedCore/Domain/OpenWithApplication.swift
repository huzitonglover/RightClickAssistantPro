//
//  OpenWithApplication.swift
//  RightClickAssistantPro
//
//  Created by 老谭 on 2026/4/30.
//

import AppKit
import Foundation

struct OpenWithApplication: AssistantModelIdentity {
    var id: String
    var url: URL
    var itemName: String
    var inheritFromGlobalArguments = true
    var inheritFromGlobalEnvironment = true
    var arguments: [String] = []
    var environment: [String: String] = [:]

    init(id: String = UUID().uuidString, appURL url: URL) {
        self.id = id
        self.url = url
        itemName = url.deletingPathExtension().lastPathComponent
    }

    var appName: String {
        FileManager.default.displayName(atPath: url.path)
    }

    var name: String {
        itemName.isEmpty ? appName : itemName
    }
}

extension OpenWithApplication {
    private static let workspace = NSWorkspace.shared
    private static let preferredBundleIdentifiers = [
        "com.apple.TextEdit",
        "com.apple.Terminal"
    ]

    init?(bundleIdentifier identifier: String) {
        guard let applicationURL = Self.workspace.urlForApplication(withBundleIdentifier: identifier) else {
            return nil
        }
        self.init(appURL: applicationURL)
    }

    static var vscode: Self? {
        Self(bundleIdentifier: "com.microsoft.VSCode")
    }

    static var terminal: Self? {
        Self(bundleIdentifier: "com.apple.Terminal")
    }

    static var textEdit: Self? {
        Self(bundleIdentifier: "com.apple.TextEdit")
    }

    static var defaultApps: [Self] {
        preferredBundleIdentifiers.compactMap(Self.init(bundleIdentifier:))
    }
}
