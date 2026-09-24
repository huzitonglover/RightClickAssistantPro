//
//  AssistantSettingsWindow.swift
//  RightClickAssistantPro
//
//  Created by 老谭 on 2026/4/30.
//

import AppKit
import SwiftUI

private enum AssistantSettingsWindowMetrics {
    static let defaultWidth: CGFloat = 1160
    static let defaultHeight: CGFloat = 760
    static let minWidth: CGFloat = 920
    static let minHeight: CGFloat = 620
    static let minimumVisibleWidth: CGFloat = 320
    static let minimumVisibleHeight: CGFloat = 220
}

struct AssistantSettingsWindow: Scene {
    @ObservedObject var appState: AssistantRuntimeState
    let appLocale: Locale
    let initialTab: AssistantSettingsTab
    let onAppear: () -> Void

    var body: some Scene {
        Settings {
            rootView
        }
    }

    private var rootView: some View {
        Self.makeRootView(
            appState: appState,
            appLocale: appLocale,
            initialTab: initialTab,
            onAppear: onAppear
        )
    }
}

extension AssistantSettingsWindow {
    static func makeRootView(
        appState: AssistantRuntimeState,
        appLocale: Locale,
        initialTab: AssistantSettingsTab = .general,
        onAppear: @escaping () -> Void = {}
    ) -> some View {
        AssistantSettingsView(initialTab: initialTab)
            .environmentObject(appState)
            .environment(\.locale, appLocale)
            .frame(
                minWidth: AssistantSettingsWindowMetrics.minWidth,
                minHeight: AssistantSettingsWindowMetrics.minHeight
            )
            .onAppear(perform: onAppear)
    }
}

extension RCAAppDelegate {
    func reopenPrimaryWindowFromMenuBar() {
        logger.info(
            "Requesting primary window reopen from menu bar; active=\(NSApp.isActive) activationPolicy=\(NSApp.activationPolicy().rawValue) settingsWindowExists=\(self.settingsWindow != nil)"
        )
        presentPrimaryWindowFromMenuBar()
    }

    func showSettingsWindow(afterMenuInteraction: Bool = false, selectedTab: AssistantSettingsTab = .general) {
        logger.info(
            "showSettingsWindow start afterMenuInteraction=\(afterMenuInteraction) settingsWindowExists=\(self.settingsWindow != nil) active=\(NSApp.isActive) activationPolicy=\(NSApp.activationPolicy().rawValue)"
        )

        guard !afterMenuInteraction else {
            presentPrimaryWindowFromMenuBar()
            return
        }

        let window: NSWindow

        if let existingWindow = settingsWindow {
            logger.info(
                "Reusing settings window visible=\(existingWindow.isVisible) miniaturized=\(existingWindow.isMiniaturized) frame=\(NSStringFromRect(existingWindow.frame))"
            )
            updateSettingsWindow(existingWindow, selectedTab: selectedTab)
            window = existingWindow
        } else {
            logger.info("Creating new settings window")
            let newWindow = NSWindow(
                contentRect: NSRect(
                    x: 0,
                    y: 0,
                    width: AssistantSettingsWindowMetrics.defaultWidth,
                    height: AssistantSettingsWindowMetrics.defaultHeight
                ),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )

            newWindow.identifier = NSUserInterfaceItemIdentifier(Constants.WindowID.settingsPanel)
            newWindow.title = AssistantLocalized.text(zh: "设置", en: "Settings")
            newWindow.titleVisibility = .hidden
            newWindow.titlebarAppearsTransparent = true
            newWindow.collectionBehavior.formUnion([.moveToActiveSpace, .fullScreenAuxiliary])
            newWindow.setFrameAutosaveName(Constants.WindowID.settingsPanel)
            newWindow.contentMinSize = NSSize(
                width: AssistantSettingsWindowMetrics.minWidth,
                height: AssistantSettingsWindowMetrics.minHeight
            )
            newWindow.isReleasedWhenClosed = false
            newWindow.delegate = self
            updateSettingsWindow(newWindow, selectedTab: selectedTab)
            newWindow.center()

            settingsWindow = newWindow
            window = newWindow
        }

        prepareSettingsWindowForPresentation(window)
        logger.info(
            "Presenting settings window before activation visible=\(window.isVisible) miniaturized=\(window.isMiniaturized) frame=\(NSStringFromRect(window.frame))"
        )
        NSApp.unhide(nil)
        NSApp.activate(ignoringOtherApps: true)
        NSRunningApplication.current.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
        window.orderFrontRegardless()
        window.makeKeyAndOrderFront(nil)
        logger.info(
            "showSettingsWindow end visible=\(window.isVisible) key=\(window.isKeyWindow) main=\(window.isMainWindow) miniaturized=\(window.isMiniaturized)"
        )
    }

    private func presentPrimaryWindowFromMenuBar() {
        pendingPrimaryWindowPresentationWorkItem?.cancel()
        logger.info("Scheduling primary window presentation from menu bar")
        promoteApplicationForPrimaryWindowPresentationIfNeeded()

        let workItem = DispatchWorkItem { [weak self] in
            self?.presentPrimaryWindowAfterMenuDismissal(remainingRetries: 1)
        }
        pendingPrimaryWindowPresentationWorkItem = workItem

        // Status-item menu tracking can temporarily block activation changes.
        // Wait for the menu dismissal, then verify once more if the window is still not visible.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: workItem)
    }

    private func presentPrimaryWindowAfterMenuDismissal(remainingRetries: Int) {
        pendingPrimaryWindowPresentationWorkItem = nil

        logger.info(
            "Running post-menu primary window presentation remainingRetries=\(remainingRetries) active=\(NSApp.isActive) activationPolicy=\(NSApp.activationPolicy().rawValue)"
        )

        NSApp.unhide(nil)
        NSApp.activate(ignoringOtherApps: true)
        NSRunningApplication.current.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
        showSettingsWindow()

        let isWindowVisible = settingsWindow?.isVisible == true
        let isWindowMiniaturized = settingsWindow?.isMiniaturized ?? false
        let windowReady = isWindowVisible && !isWindowMiniaturized && NSApp.isActive

        logger.info(
            "Primary window reopen verification: visible=\(isWindowVisible), miniaturized=\(isWindowMiniaturized), active=\(NSApp.isActive)"
        )

        guard !windowReady, remainingRetries > 0 else {
            return
        }

        let retryWorkItem = DispatchWorkItem { [weak self] in
            self?.presentPrimaryWindowAfterMenuDismissal(remainingRetries: remainingRetries - 1)
        }
        pendingPrimaryWindowPresentationWorkItem = retryWorkItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: retryWorkItem)
    }

    private func promoteApplicationForPrimaryWindowPresentationIfNeeded() {
        guard !shouldShowDockIconPersistently else {
            logger.info("Skip activation policy promotion because Dock icon is persistent")
            return
        }

        if NSApp.activationPolicy() != .regular {
            logger.info("Promoting activation policy from \(NSApp.activationPolicy().rawValue) to regular")
            NSApp.setActivationPolicy(.regular)
        } else {
            logger.info("Activation policy already regular before presenting primary window")
        }
    }

    private var shouldShowDockIconPersistently: Bool {
        UserDefaults.standard.bool(forKey: SharedPreferenceKey.showInDock)
    }

    func restoreAccessoryActivationPolicyIfNeeded() {
        guard !shouldShowDockIconPersistently else {
            logger.info("Skip restoring accessory activation policy because Dock icon is persistent")
            return
        }

        guard settingsWindow == nil,
              fileInfoWindow == nil,
              batchRenameWindow == nil,
              qrCodeWindow == nil,
              imageTextWindow == nil,
              featureCenterModuleWindows.isEmpty else {
            logger.info(
                "Keep activation policy unchanged because windows still exist settings=\(self.settingsWindow != nil) fileInfo=\(self.fileInfoWindow != nil) batchRename=\(self.batchRenameWindow != nil) qrCode=\(self.qrCodeWindow != nil) imageText=\(self.imageTextWindow != nil) featureModules=\(!self.featureCenterModuleWindows.isEmpty)"
            )
            return
        }

        if NSApp.activationPolicy() != .accessory {
            logger.info("Restoring activation policy to accessory")
            NSApp.setActivationPolicy(.accessory)
        } else {
            logger.info("Activation policy already accessory")
        }
    }

    private func updateSettingsWindow(_ window: NSWindow, selectedTab: AssistantSettingsTab = .general) {
        logger.info("Updating settings window content controller")
        window.title = AssistantLocalized.text(zh: "设置", en: "Settings")
        window.collectionBehavior.formUnion([.moveToActiveSpace, .fullScreenAuxiliary])
        window.contentViewController = NSHostingController(
            rootView: AnyView(
                AssistantSettingsWindow.makeRootView(
                    appState: appState,
                    appLocale: AssistantLocalized.currentLocale,
                    initialTab: selectedTab
                )
            )
        )
    }

    private func prepareSettingsWindowForPresentation(_ window: NSWindow) {
        if window.isMiniaturized {
            logger.info("Deminiaturizing settings window before presentation")
            window.deminiaturize(nil)
        }

        guard !hasUsableVisibleArea(for: window.frame) else {
            logger.info("Settings window already within usable visible area")
            return
        }

        if let targetScreen = NSScreen.main ?? window.screen ?? NSScreen.screens.first {
            let visibleFrame = targetScreen.visibleFrame
            let centeredOrigin = NSPoint(
                x: visibleFrame.midX - (window.frame.width / 2),
                y: visibleFrame.midY - (window.frame.height / 2)
            )
            window.setFrameOrigin(centeredOrigin)
            logger.info("Recentered settings window to frame=\(NSStringFromRect(window.frame))")
        } else {
            window.center()
            logger.info("Centered settings window using fallback centering")
        }
    }

    private func hasUsableVisibleArea(for frame: NSRect) -> Bool {
        NSScreen.screens.contains { screen in
            let visibleFrame = screen.visibleFrame
            let intersection = visibleFrame.intersection(frame)

            return !intersection.isNull
                && intersection.width >= AssistantSettingsWindowMetrics.minimumVisibleWidth
                && intersection.height >= AssistantSettingsWindowMetrics.minimumVisibleHeight
        }
    }
}
