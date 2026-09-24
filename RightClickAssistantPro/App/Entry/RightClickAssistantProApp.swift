//
//  RightClickAssistantProApp.swift
//  RightClickAssistantPro
//
//  Created by 老谭 on 2026/4/30.
//

import AppKit
import Foundation
import SwiftUI

@main
struct RightClickAssistantProApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: RCAAppDelegate
    @AppStorage(SharedPreferenceKey.appLanguage, store: .group) private var appLanguage = AssistantLanguageOption.system.rawValue
    @StateObject private var appState = AssistantRuntimeState.shared

    private var selectedLanguage: AssistantLanguageOption {
        AssistantLanguageOption(rawValue: appLanguage) ?? .system
    }

    var body: some Scene {
        AssistantSettingsWindow(
            appState: appState,
            appLocale: selectedLanguage.locale,
            initialTab: .general,
            onAppear: {}
        )
        .commands {
            AssistantApplicationCommands()
        }
    }
}

private struct AssistantApplicationCommands: Commands {
    var body: some Commands {
        CommandGroup(replacing: .appSettings) {
            Button(AssistantLocalized.text(zh: "打开 App", en: "Open App")) {
                RCAAppDelegate.shared?.reopenPrimaryWindowFromMenuBar()
            }
        }
    }
}

@MainActor
final class RCAAppDelegate: NSObject, NSApplicationDelegate {
    static var shared: RCAAppDelegate?

    @AssistantLogger(category: "RCAAppDelegate")
    var logger

    let messager = ExtensionMessageBus.shared
    var appState: AssistantRuntimeState = .shared
    var showInDock = UserDefaults.standard.bool(forKey: SharedPreferenceKey.showInDock)
    var settingsWindow: NSWindow?
    var fileInfoWindow: NSWindow?
    var fileInfoViewModel: FileInfoCenterViewModel?
    var batchRenameWindow: NSWindow?
    var qrCodeWindow: NSWindow?
    var imageTextWindow: NSWindow?
    var featureCenterModuleWindows: [FeatureCenterModuleID: NSWindow] = [:]
    var sharingPickerAnchorWindow: NSWindow?
    var legacyMenuBarController: AssistantLegacyMenuBarController?
    var desktopActivationCoordinator: AssistantDesktopActivationCoordinator?
    var pendingPrimaryWindowPresentationWorkItem: DispatchWorkItem?
    var lastFinderPayloadSignature: String?
    var lastFinderPayloadReceivedAt: Date = .distantPast

    var expectedFinderExtensionBundlePath: String? {
        Bundle.main.builtInPlugInsURL?
            .appendingPathComponent("AssistantFinderExtension.appex")
            .path
    }

    var expectedFinderExtensionBundleIdentifier: String? {
        guard let expectedFinderExtensionBundlePath else {
            return nil
        }

        let infoPlistURL = URL(fileURLWithPath: expectedFinderExtensionBundlePath)
            .appendingPathComponent("Contents/Info.plist")
        guard let bundle = Bundle(url: infoPlistURL.deletingLastPathComponent().deletingLastPathComponent()) else {
            return nil
        }

        return bundle.bundleIdentifier
    }

    override init() {
        super.init()
        Self.shared = self
    }
}

extension RCAAppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow {
            logger.info("windowWillClose id=\(window.identifier?.rawValue ?? "nil") title=\(window.title)")
        }

        if let window = notification.object as? NSWindow, window == fileInfoWindow {
            fileInfoWindow = nil
            fileInfoViewModel = nil
            restoreAccessoryActivationPolicyIfNeeded()
        } else if let window = notification.object as? NSWindow, window == batchRenameWindow {
            batchRenameWindow = nil
            restoreAccessoryActivationPolicyIfNeeded()
        } else if let window = notification.object as? NSWindow, window == qrCodeWindow {
            qrCodeWindow = nil
            restoreAccessoryActivationPolicyIfNeeded()
        } else if let window = notification.object as? NSWindow, window == imageTextWindow {
            imageTextWindow = nil
            restoreAccessoryActivationPolicyIfNeeded()
        } else if let window = notification.object as? NSWindow, window == settingsWindow {
            settingsWindow = nil
            restoreAccessoryActivationPolicyIfNeeded()
        } else if let window = notification.object as? NSWindow,
                  let moduleID = featureCenterModuleWindows.first(where: { $0.value == window })?.key {
            featureCenterModuleWindows[moduleID] = nil
            restoreAccessoryActivationPolicyIfNeeded()
        }
    }

    func windowDidBecomeKey(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else {
            return
        }

        logger.info("windowDidBecomeKey id=\(window.identifier?.rawValue ?? "nil") title=\(window.title)")
    }

    func windowDidMiniaturize(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else {
            return
        }

        logger.info("windowDidMiniaturize id=\(window.identifier?.rawValue ?? "nil") title=\(window.title)")
    }

    func windowDidDeminiaturize(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else {
            return
        }

        logger.info("windowDidDeminiaturize id=\(window.identifier?.rawValue ?? "nil") title=\(window.title)")
    }
}

@MainActor
final class AssistantLegacyMenuBarController: NSObject {
    @AssistantLogger(category: "MenuBar")
    private var logger

    private var statusItem: NSStatusItem?
    private var defaultsObserver: NSObjectProtocol?

    func start() {
        guard defaultsObserver == nil else {
            refresh()
            return
        }

        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refresh()
            }
        }

        refresh()
    }

    deinit {
        if let defaultsObserver {
            NotificationCenter.default.removeObserver(defaultsObserver)
        }
    }

    private var shouldShowMenuBarExtra: Bool {
        guard let value = UserDefaults.standard.object(forKey: SharedPreferenceKey.showMenuBarExtra) as? Bool else {
            return true
        }

        return value
    }

    func refresh() {
        logger.info("Refreshing menu bar controller; shouldShowMenuBarExtra=\(self.shouldShowMenuBarExtra)")
        if shouldShowMenuBarExtra {
            installStatusItemIfNeeded()
        } else {
            removeStatusItem()
        }
    }

    private func installStatusItemIfNeeded() {
        let item = statusItem ?? NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem = item

        logger.info("Installing status item; existingButton=\(item.button != nil)")

        if let button = item.button {
            let image = NSImage(named: "AssistantMenuRaster")
            image?.isTemplate = false
            button.image = image
            button.imagePosition = .imageOnly
            button.toolTip = AssistantLocalized.appName
        }

        item.menu = makeMenu()
        logger.info("Status item menu attached")
    }

    private func removeStatusItem() {
        guard let statusItem else {
            logger.info("Skip removing status item because it does not exist")
            return
        }

        NSStatusBar.system.removeStatusItem(statusItem)
        self.statusItem = nil
        logger.info("Removed status item")
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu(title: AssistantLocalized.appName)

        let openAppItem = NSMenuItem(
            title: AssistantLocalized.text(zh: "打开 App", en: "Open App"),
            action: #selector(reopenPrimaryWindow),
            keyEquivalent: ""
        )
        openAppItem.target = self
        menu.addItem(openAppItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: AssistantLocalized.text(zh: "退出", en: "Quit"),
            action: #selector(requestQuit),
            keyEquivalent: "q"
        )
        quitItem.keyEquivalentModifierMask = [.command]
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    @objc
    private func reopenPrimaryWindow() {
        logger.info("Menu bar action selected: reopenPrimaryWindow")
        RCAAppDelegate.shared?.reopenPrimaryWindowFromMenuBar()
    }

    @objc
    private func requestQuit() {
        logger.info("Menu bar action selected: requestQuit")
        let messager = ExtensionMessageBus.shared
        messager.sendMessage(name: "quit", data: ExtensionMessagePayload(action: "quit"))

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            NSApplication.shared.terminate(self)
        }
    }
}
