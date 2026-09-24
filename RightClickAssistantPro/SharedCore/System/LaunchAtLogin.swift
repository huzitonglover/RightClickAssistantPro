//
//  LaunchAtLogin.swift
//  RightClickAssistantPro
//  Created by 老谭 on 2026/4/29.
//

import Foundation
import ServiceManagement
import SwiftUI
import os.log

public enum LaunchAtLogin {
    private static let logger = makeAssistantLogger(
        subsystem: Bundle.main.bundleIdentifier ?? "LaunchAtLogin",
        category: "service"
    )

    fileprivate static let viewState = LaunchAtLoginStateBridge()

    public static var isSupported: Bool {
        if #available(macOS 13.0, *) {
            return true
        }

        return false
    }

    public static var isEnabled: Bool {
        get { isMainAppServiceEnabled }
        set { updateRegistration(to: newValue) }
    }

    public static var wasLaunchedAtLogin: Bool {
        launchEventID == kAEOpenApplication && launchOriginCode == keyAELaunchedAsLogInItem
    }

    public static func migrateLegacyAutoRegistrationIfNeeded() {
        let defaults = UserDefaults.standard

        guard defaults.object(forKey: SharedPreferenceKey.launchAtLoginUserConfigured) == nil else {
            return
        }

        guard defaults.object(forKey: SharedPreferenceKey.launchAtLoginInitialized) != nil else {
            return
        }

        defaults.removeObject(forKey: SharedPreferenceKey.launchAtLoginInitialized)

        guard isSupported, isMainAppServiceEnabled else { return }

        do {
            try disableMainAppService()
            viewState.invalidate()
            logger.notice("Disabled launch at login during migration because earlier builds enabled it automatically")
        } catch {
            logger.error("Failed to disable legacy launch at login registration: \(error.localizedDescription)")
        }
    }

    private static var isMainAppServiceEnabled: Bool {
        guard #available(macOS 13.0, *) else {
            return false
        }

        return SMAppService.mainApp.status == .enabled
    }

    private static var launchEventID: AEEventID? {
        NSAppleEventManager.shared().currentAppleEvent?.eventID
    }

    private static var launchOriginCode: OSType? {
        NSAppleEventManager.shared()
            .currentAppleEvent?
            .paramDescriptor(forKeyword: keyAEPropData)?
            .enumCodeValue
    }

    private static func updateRegistration(to enabled: Bool) {
        guard isSupported else {
            logger.notice("Launch at login is unavailable before macOS 13")
            viewState.invalidate()
            return
        }

        viewState.invalidate()

        do {
            if enabled {
                try enableMainAppService()
            } else {
                try disableMainAppService()
            }
            recordUserConsentSelection()
            viewState.invalidate()
        } catch {
            logger.error("Failed to update launch at login state: \(error.localizedDescription)")
            viewState.invalidate()
        }
    }

    private static func enableMainAppService() throws {
        guard #available(macOS 13.0, *) else {
            return
        }

        guard SMAppService.mainApp.status != .enabled else { return }
        try SMAppService.mainApp.register()
    }

    private static func disableMainAppService() throws {
        guard #available(macOS 13.0, *) else {
            return
        }

        guard SMAppService.mainApp.status != .notRegistered else { return }
        try SMAppService.mainApp.unregister()
    }

    private static func recordUserConsentSelection() {
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: SharedPreferenceKey.launchAtLoginUserConfigured)
        defaults.removeObject(forKey: SharedPreferenceKey.launchAtLoginInitialized)
    }
}

fileprivate final class LaunchAtLoginStateBridge: ObservableObject {
    func invalidate() {
        objectWillChange.send()
    }

    func binding() -> Binding<Bool> {
        Binding(
            get: { LaunchAtLogin.isEnabled },
            set: { LaunchAtLogin.isEnabled = $0 }
        )
    }
}

public extension LaunchAtLogin {
    struct Toggle<Label: View>: View {
        @ObservedObject private var viewState = LaunchAtLogin.viewState
        private let labelBuilder: () -> Label

        public init(@ViewBuilder label: @escaping () -> Label) {
            self.labelBuilder = label
        }

        public var body: some View {
            SwiftUI.Toggle(isOn: viewState.binding(), label: labelBuilder)
        }
    }
}

public extension LaunchAtLogin.Toggle where Label == Text {
    init(_ titleKey: LocalizedStringKey) {
        self.init {
            Text(titleKey)
        }
    }

    init(_ title: some StringProtocol) {
        self.init {
            Text(title)
        }
    }

    init() {
        self.init("Launch at login")
    }
}
