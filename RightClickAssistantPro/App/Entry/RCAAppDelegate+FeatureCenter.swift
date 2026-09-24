//
//  RCAAppDelegate+FeatureCenter.swift
//  RightClickAssistantPro
//
//  Created by Codex on 2026/5/15.
//

import AppKit
import SwiftUI

extension RCAAppDelegate {
    func showFeatureCenterModule(_ moduleID: FeatureCenterModuleID) {
        promoteApplicationForFeatureModulePresentationIfNeeded()

        let window: NSWindow
        if let existingWindow = featureCenterModuleWindows[moduleID] {
            window = existingWindow
        } else {
            let module = FeatureCenterRegistry.module(for: moduleID)
            let newWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 760, height: 560),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )

            newWindow.identifier = NSUserInterfaceItemIdentifier(Constants.WindowID.featureModulePrefix + module.id.rawValue)
            newWindow.title = module.title
            newWindow.contentMinSize = NSSize(width: 580, height: 380)
            newWindow.contentViewController = NSHostingController(
                rootView: AnyView(
                    makeFeatureCenterModuleView(moduleID, window: newWindow)
                        .environment(\.locale, AssistantLocalized.currentLocale)
                )
            )
            newWindow.center()
            newWindow.isReleasedWhenClosed = false
            newWindow.delegate = self

            featureCenterModuleWindows[moduleID] = newWindow
            window = newWindow
        }

        NSApp.unhide(nil)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    @ViewBuilder
    private func makeFeatureCenterModuleView(_ moduleID: FeatureCenterModuleID, window: NSWindow) -> some View {
        switch moduleID {
        case .shortcutAssistant:
            ShortcutAssistantView { [weak window] in
                window?.close()
            }
        }
    }

    private func promoteApplicationForFeatureModulePresentationIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: SharedPreferenceKey.showInDock) else {
            return
        }

        if NSApp.activationPolicy() != .regular {
            NSApp.setActivationPolicy(.regular)
        }
    }
}
