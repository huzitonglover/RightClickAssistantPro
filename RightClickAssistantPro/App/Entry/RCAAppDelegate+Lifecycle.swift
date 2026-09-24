//
//  RCAAppDelegate+Lifecycle.swift
//  RightClickAssistantPro
//
//  Created by 老谭 on 2026/4/30.
//

import AppKit
import CoreGraphics
import FinderSync
import Foundation
import OSLog

enum AssistantBuildRuntime {
    static let isDesktopActivationBridgeEnabled = false

    static var shouldRepairFinderExtensionRegistration: Bool {
        #if DEBUG
        isEligibleForFinderExtensionRepair(bundleURL: Bundle.main.bundleURL)
        #else
        false
        #endif
    }

    static func isEligibleForFinderExtensionRepair(bundleURL: URL) -> Bool {
        let standardizedPath = bundleURL.standardizedFileURL.path

        if standardizedPath.hasPrefix("/Volumes/") {
            return false
        }

        if standardizedPath.contains("/AppTranslocation/") {
            return false
        }

        return true
    }
}

private enum AssistantFinderMessageRoute: String {
    case open
    case actioning
    case createFile = "Create File"
    case commonDirectories = "common-dirs"
    case openOpenWithSettings = "open-open-with-settings"
    case openNewFileSettings = "open-new-file-settings"
    case openFolderIconSettings = "open-folder-icon-settings"
}

private enum FinderPayloadDeduplication {
    static let fileInfoWindow: TimeInterval = 0.8
    static let fileInfoActionIdentifier = "file-info"
}

private struct AssistantPrimaryInstanceRecord: Codable {
    let pid: Int32
    let bundlePath: String
    let updatedAt: TimeInterval
}

private enum AssistantPrimaryInstanceCoordinator {
    private static let encoder = PropertyListEncoder()
    private static let decoder = PropertyListDecoder()
    private static let fileName = "assistant-primary-instance.plist"

    static func claimCurrentProcessLeadership(logger: AssistantRuntimeLogger) {
        let currentPID = ProcessInfo.processInfo.processIdentifier

        if let existingRecord = loadRecord(),
           existingRecord.pid != currentPID,
           let existingApp = NSRunningApplication(processIdentifier: existingRecord.pid),
           !existingApp.isTerminated {
            logger.warning("Detected previous primary instance pid \(existingRecord.pid); requesting termination")
            if !existingApp.terminate() {
                _ = existingApp.forceTerminate()
            }
        }

        saveRecord(
            AssistantPrimaryInstanceRecord(
                pid: currentPID,
                bundlePath: Bundle.main.bundlePath,
                updatedAt: Date().timeIntervalSince1970
            ),
            logger: logger
        )
    }

    static func isCurrentProcessPrimaryInstance() -> Bool {
        guard let record = loadRecord() else {
            return true
        }

        return record.pid == ProcessInfo.processInfo.processIdentifier
    }

    static func clearCurrentProcessLeadership(logger: AssistantRuntimeLogger) {
        guard let record = loadRecord(),
              record.pid == ProcessInfo.processInfo.processIdentifier else {
            return
        }

        do {
            try FileManager.default.removeItem(at: recordURL())
        } catch {
            logger.warning("Failed to clear primary instance record: \(error.localizedDescription)")
        }
    }

    private static func saveRecord(_ record: AssistantPrimaryInstanceRecord, logger: AssistantRuntimeLogger) {
        do {
            let url = recordURL()
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true,
                attributes: nil
            )
            let data = try encoder.encode(record)
            try data.write(to: url, options: .atomic)
        } catch {
            logger.warning("Failed to save primary instance record: \(error.localizedDescription)")
        }
    }

    private static func loadRecord() -> AssistantPrimaryInstanceRecord? {
        guard let data = try? Data(contentsOf: recordURL()) else {
            return nil
        }

        return try? decoder.decode(AssistantPrimaryInstanceRecord.self, from: data)
    }

    private static func recordURL() -> URL {
        let baseDirectory: URL
        if let groupContainerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: Constants.appGroupIdentifier
        ) {
            baseDirectory = groupContainerURL
                .appendingPathComponent("Library", isDirectory: true)
                .appendingPathComponent("Application Support", isDirectory: true)
        } else {
            baseDirectory = FileManager.default.temporaryDirectory
                .appendingPathComponent("rightPro.touch.com", isDirectory: true)
        }

        return baseDirectory.appendingPathComponent(fileName)
    }
}

extension RCAAppDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        AssistantPrimaryInstanceCoordinator.claimCurrentProcessLeadership(logger: logger)
        enforceSingleRunningInstance()
        LaunchAtLogin.migrateLegacyAutoRegistrationIfNeeded()
        applyPreferredAppearance()
        configureFeedbackDelivery()
        applyActivationPolicy()
        configureLegacyMenuBarIfNeeded()
        if AssistantBuildRuntime.isDesktopActivationBridgeEnabled {
            configureDesktopActivationCoordinatorIfNeeded()
        }
        installFinderMessageObserver()
        repairFinderExtensionForLocalBuildIfNeeded()
        sendObserveDirMessage()
        presentPrimaryWindowIfNeededAfterLaunch()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        guard !flag else {
            return false
        }

        showSettingsWindow()
        return true
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        repairFinderExtensionForLocalBuildIfNeeded()
    }

    func applicationWillTerminate(_ notification: Notification) {
        messager.sendMessage(
            name: "quit",
            data: ExtensionMessagePayload(action: "quit", target: [], trigger: "unknown")
        )
        desktopActivationCoordinator = nil
        RCAAppDelegate.shared = nil
        AssistantPrimaryInstanceCoordinator.clearCurrentProcessLeadership(logger: logger)
        logger.info("applicationWillTerminate")
    }

    func openCommonDirs(target: [String]) {
        Task { @MainActor in
            logger.info("开始打开常用目录，目标路径: \(target)")

            for directoryPath in target {
                let resolvedPath = directoryPath.removingPercentEncoding ?? directoryPath
                let directoryURL = URL(fileURLWithPath: resolvedPath, isDirectory: true)

                logger.info("正在打开目录: \(resolvedPath)")
                NSWorkspace.shared.open(directoryURL)
            }

            logger.info("常用目录打开操作完成")
        }
    }

    func sendObserveDirMessage() {
        guard AssistantPrimaryInstanceCoordinator.isCurrentProcessPrimaryInstance() else {
            logger.notice("Ignore running-state broadcast from secondary app instance")
            return
        }

        let observedPaths = appState.effectiveAuthorizedDirectories.map { $0.url.path }

        messager.sendMessage(
            name: "running",
            data: ExtensionMessagePayload(action: "running", target: observedPaths)
        )
    }

    func currentFinderExtensionEnabledState() -> Bool {
        AssistantFinderExtensionStateInspector.isCurrentAppEmbeddedExtensionOperational()
    }

    private func configureFeedbackDelivery() {
        AssistantBannerNotificationCenter.shared.prepare()
        AssistantBannerNotificationCenter.shared.requestAuthorizationIfNeeded()
    }

    private func presentPrimaryWindowIfNeededAfterLaunch() {
        guard !LaunchAtLogin.wasLaunchedAtLogin else {
            logger.info("Skipping primary window presentation because the app was launched at login")
            return
        }

        logger.info("Presenting primary window because the app was not launched at login")
        DispatchQueue.main.async { [weak self] in
            self?.showSettingsWindow()
        }
    }

    private func applyActivationPolicy() {
        logger.info("Applying launch activation policy showInDock=\(self.showInDock)")
        NSApp.setActivationPolicy(showInDock ? .regular : .accessory)
    }

    private func configureLegacyMenuBarIfNeeded() {
        logger.info("Configuring legacy menu bar controller")
        let controller = legacyMenuBarController ?? AssistantLegacyMenuBarController()
        controller.start()
        legacyMenuBarController = controller
    }

    private func configureDesktopActivationCoordinatorIfNeeded() {
        let coordinator = desktopActivationCoordinator
            ?? AssistantDesktopActivationCoordinator(
                logger: logger,
                openAppHandler: { [weak self] in
                    self?.reopenPrimaryWindowFromMenuBar()
                },
                showDesktopMenuHandler: { [weak self] point in
                    self?.presentDesktopContainerContextMenu(at: point)
                }
            )
        coordinator.start()
        desktopActivationCoordinator = coordinator
    }

    private func applyPreferredAppearance() {
        let aquaAppearance = NSAppearance(named: .aqua)
        NSApp.appearance = aquaAppearance

        for window in NSApp.windows {
            window.appearance = aquaAppearance
        }
    }

    private func installFinderMessageObserver() {
        messager.on(name: SharedPreferenceKey.messageFromFinder) { [weak self] payload in
            self?.handleFinderPayload(payload)
        }

        messager.on(name: "running-request") { [weak self] _ in
            self?.sendObserveDirMessage()
        }
    }

    private func enforceSingleRunningInstance() {
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
            return
        }

        let currentProcessIdentifier = ProcessInfo.processInfo.processIdentifier
        let staleInstances = NSRunningApplication
            .runningApplications(withBundleIdentifier: bundleIdentifier)
            .filter { $0.processIdentifier != currentProcessIdentifier && !$0.isTerminated }

        guard !staleInstances.isEmpty else {
            return
        }

        logger.warning("Detected \(staleInstances.count) stale app instance(s); terminating duplicates")

        for application in staleInstances {
            if !application.terminate() {
                _ = application.forceTerminate()
            }
        }
    }

    func repairFinderExtensionForLocalBuildIfNeeded(force: Bool = false) {
        guard AssistantBuildRuntime.shouldRepairFinderExtensionRegistration,
              let expectedFinderExtensionBundlePath,
              let expectedFinderExtensionBundleIdentifier else {
            return
        }

        let registrationInspection = AssistantFinderExtensionStateInspector
            .inspectCurrentAppEmbeddedExtensionRegistration()
        let runtimeHealthy = FIFinderSyncController.isExtensionEnabled
            || AssistantFinderExtensionStateInspector.isCurrentAppEmbeddedExtensionRunning()
            || AssistantFinderExtensionStateInspector.hasRecentLaunchHeartbeat()
        let hasVisibleRegisteredPaths = !registrationInspection.registeredPaths.isEmpty
        let needsRepair = force
            || (
                registrationInspection.pluginkitQuerySucceeded
                    && hasVisibleRegisteredPaths
                    && registrationInspection.hasUnexpectedRegistrations
            )
            || (
                !runtimeHealthy
                    && (
                        registrationInspection.pluginkitQuerySucceeded
                            && hasVisibleRegisteredPaths
                            && !registrationInspection.currentBuildRegistered
                    )
            )

        guard needsRepair else {
            return
        }

        DispatchQueue.global(qos: .utility).async {
            AssistantDebugFinderExtensionCoordinator.refresh(
                extensionBundlePath: expectedFinderExtensionBundlePath,
                extensionBundleIdentifier: expectedFinderExtensionBundleIdentifier
            )
        }
    }

    private func handleFinderPayload(_ payload: ExtensionMessagePayload) {
        guard AssistantPrimaryInstanceCoordinator.isCurrentProcessPrimaryInstance() else {
            logger.notice("Ignore finder payload on secondary app instance \(payload.description)")
            return
        }

        logger.info("recive mess from finder by app \(payload.description)")

        if shouldIgnoreDuplicateFinderPayload(payload) {
            logger.warning("Ignore duplicate finder payload \(payload.description)")
            return
        }

        guard let route = AssistantFinderMessageRoute(rawValue: payload.action) else {
            logger.warning("actioning payload no matched")
            return
        }

        switch route {
        case .open:
            openApp(rid: payload.rid, target: payload.target)
        case .actioning:
            actionHandler(rid: payload.rid, target: payload.target, trigger: payload.trigger)
        case .createFile:
            createFile(rid: payload.rid, target: payload.target)
        case .commonDirectories:
            openCommonDirs(target: payload.target)
        case .openOpenWithSettings:
            showSettingsWindow(selectedTab: .apps)
        case .openNewFileSettings:
            showSettingsWindow(selectedTab: .newFile)
        case .openFolderIconSettings:
            showSettingsWindow(selectedTab: .folderIcons)
        }
    }

    private func shouldIgnoreDuplicateFinderPayload(_ payload: ExtensionMessagePayload) -> Bool {
        guard payload.action == AssistantFinderMessageRoute.actioning.rawValue,
              payload.rid == FinderPayloadDeduplication.fileInfoActionIdentifier else {
            return false
        }

        let signature = finderPayloadSignature(for: payload)
        let now = Date()

        defer {
            lastFinderPayloadSignature = signature
            lastFinderPayloadReceivedAt = now
        }

        guard lastFinderPayloadSignature == signature else {
            return false
        }

        return now.timeIntervalSince(lastFinderPayloadReceivedAt) < FinderPayloadDeduplication.fileInfoWindow
    }

    private func finderPayloadSignature(for payload: ExtensionMessagePayload) -> String {
        [
            payload.action,
            payload.rid,
            payload.trigger,
            payload.target.joined(separator: "\u{1F}")
        ].joined(separator: "|")
    }
}

enum AssistantFinderExtensionStateInspector {
    struct RegistrationInspection {
        let pluginkitQuerySucceeded: Bool
        let pluginkitEnabled: Bool
        let currentBuildRegistered: Bool
        let hasUnexpectedRegistrations: Bool
        let registeredPaths: [String]
    }

    private struct PluginKitQueryResult {
        let didRun: Bool
        let matchingLines: [String]
        let registeredPaths: [String]

        var enabled: Bool {
            guard didRun else {
                return false
            }

            guard !matchingLines.isEmpty else {
                return false
            }

            if matchingLines.contains(where: { $0.hasPrefix("+") }) {
                return true
            }

            if matchingLines.allSatisfy({ $0.hasPrefix("-") }) {
                return false
            }

            return true
        }
    }

    static func hasRecentLaunchHeartbeat(
        defaults: UserDefaults = .group,
        maxAge: TimeInterval = 300
    ) -> Bool {
        let lastHeartbeat = defaults.double(forKey: SharedPreferenceKey.finderExtensionHeartbeat)

        guard lastHeartbeat > 0 else {
            return false
        }

        return Date().timeIntervalSince1970 - lastHeartbeat <= maxAge
    }

    static func isCurrentAppEmbeddedExtensionEnabled(appBundle: Bundle = .main) -> Bool {
        inspectCurrentAppEmbeddedExtensionRegistration(appBundle: appBundle).pluginkitEnabled
    }

    static func isCurrentAppEmbeddedExtensionOperational(appBundle: Bundle = .main) -> Bool {
        let registrationInspection = inspectCurrentAppEmbeddedExtensionRegistration(appBundle: appBundle)
        let runtimeHealthy = FIFinderSyncController.isExtensionEnabled
            || isCurrentAppEmbeddedExtensionRunning(appBundle: appBundle)
            || hasRecentLaunchHeartbeat()

        return runtimeHealthy
            || (
                registrationInspection.pluginkitQuerySucceeded
                    && registrationInspection.currentBuildRegistered
                    && !registrationInspection.hasUnexpectedRegistrations
                    && (
                        registrationInspection.pluginkitEnabled
                            || hasRecentLaunchHeartbeat()
                    )
            )
    }

    static func isCurrentAppEmbeddedExtensionRunning(appBundle: Bundle = .main) -> Bool {
        isRunning(
            extensionBundleIdentifier: currentAppEmbeddedExtensionBundleIdentifier(appBundle: appBundle)
        )
    }

    static func isCurrentAppEmbeddedExtensionRegistered(appBundle: Bundle = .main) -> Bool {
        inspectCurrentAppEmbeddedExtensionRegistration(appBundle: appBundle).currentBuildRegistered
    }

    static func hasUnexpectedRegistrationState(appBundle: Bundle = .main) -> Bool {
        inspectCurrentAppEmbeddedExtensionRegistration(appBundle: appBundle).hasUnexpectedRegistrations
    }

    static func inspectCurrentAppEmbeddedExtensionRegistration(
        appBundle: Bundle = .main
    ) -> RegistrationInspection {
        guard let extensionBundleIdentifier = currentAppEmbeddedExtensionBundleIdentifier(appBundle: appBundle),
              let extensionBundleURL = currentAppEmbeddedExtensionBundleURL(appBundle: appBundle) else {
            return RegistrationInspection(
                pluginkitQuerySucceeded: false,
                pluginkitEnabled: false,
                currentBuildRegistered: false,
                hasUnexpectedRegistrations: false,
                registeredPaths: []
            )
        }

        let expectedPath = normalizedPluginPath(extensionBundleURL.path)
        let query = queryPluginKit(extensionBundleIdentifier: extensionBundleIdentifier)

        guard query.didRun, !query.matchingLines.isEmpty || !query.registeredPaths.isEmpty else {
            return RegistrationInspection(
                pluginkitQuerySucceeded: false,
                pluginkitEnabled: false,
                currentBuildRegistered: false,
                hasUnexpectedRegistrations: false,
                registeredPaths: []
            )
        }

        let currentBuildRegistered = query.registeredPaths.contains(expectedPath)
        let hasUnexpectedRegistrations = query.registeredPaths.isEmpty
            || query.registeredPaths.contains(where: { $0 != expectedPath })
            || !currentBuildRegistered

        return RegistrationInspection(
            pluginkitQuerySucceeded: true,
            pluginkitEnabled: query.enabled,
            currentBuildRegistered: currentBuildRegistered,
            hasUnexpectedRegistrations: hasUnexpectedRegistrations,
            registeredPaths: query.registeredPaths
        )
    }

    static func isEnabled(extensionBundleIdentifier: String?) -> Bool {
        guard let extensionBundleIdentifier else {
            return false
        }

        return queryPluginKit(extensionBundleIdentifier: extensionBundleIdentifier).enabled
    }

    static func currentAppEmbeddedExtensionBundleIdentifier(appBundle: Bundle = .main) -> String? {
        guard let extensionBundleURL = currentAppEmbeddedExtensionBundleURL(appBundle: appBundle),
              let bundle = Bundle(url: extensionBundleURL) else {
            return nil
        }

        return bundle.bundleIdentifier
    }

    static func currentAppEmbeddedExtensionBundleURL(appBundle: Bundle = .main) -> URL? {
        appBundle.builtInPlugInsURL?
            .appendingPathComponent("AssistantFinderExtension.appex")
    }

    static func isRunning(extensionBundleIdentifier: String?) -> Bool {
        guard let extensionBundleIdentifier else {
            return false
        }

        return NSRunningApplication
            .runningApplications(withBundleIdentifier: extensionBundleIdentifier)
            .contains(where: { !$0.isTerminated })
    }

    static func registeredPluginPaths(extensionBundleIdentifier: String?) -> [String] {
        guard let extensionBundleIdentifier else {
            return []
        }

        return queryPluginKit(extensionBundleIdentifier: extensionBundleIdentifier).registeredPaths
    }

    private static func queryPluginKit(extensionBundleIdentifier: String) -> PluginKitQueryResult {
        let result = run(
            "/usr/bin/pluginkit",
            arguments: ["-m", "-A", "-D", "-v", "-i", extensionBundleIdentifier, "-p", "com.apple.FinderSync"]
        )

        guard result.didRun else {
            return PluginKitQueryResult(
                didRun: false,
                matchingLines: [],
                registeredPaths: []
            )
        }

        let lines = result.output
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        let paths = lines.compactMap { line -> String? in
                let columns = line.split(separator: "\t")
                guard let lastColumn = columns.last else {
                    return nil
                }

                let path = String(lastColumn).trimmingCharacters(in: .whitespacesAndNewlines)
                guard path.hasPrefix("/") else {
                    return nil
                }

                return normalizedPluginPath(path)
            }

        return PluginKitQueryResult(
            didRun: true,
            matchingLines: lines.filter { $0.contains(extensionBundleIdentifier) },
            registeredPaths: Array(Set(paths)).sorted()
        )
    }

    private static func run(_ launchPath: String, arguments: [String]) -> (didRun: Bool, output: String) {
        let process = Process()
        let outputPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        do {
            try process.run()
            process.waitUntilExit()
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            return (true, String(decoding: outputData, as: UTF8.self))
        } catch {
            return (false, "")
        }
    }

    private static func normalizedPluginPath(_ path: String) -> String {
        URL(fileURLWithPath: path).standardizedFileURL.path
    }
}

private enum AssistantDebugFinderExtensionCoordinator {
    static func refresh(extensionBundlePath: String, extensionBundleIdentifier: String) {
        removeDuplicateRegistrations(
            currentExtensionBundlePath: extensionBundlePath,
            extensionBundleIdentifier: extensionBundleIdentifier
        )

        run("/usr/bin/pluginkit", arguments: ["-a", extensionBundlePath])
        run(
            "/usr/bin/pluginkit",
            arguments: ["-e", "use", "-p", "com.apple.FinderSync", "-i", extensionBundleIdentifier]
        )
        run("/usr/bin/killall", arguments: ["Finder"])
    }

    private static func removeDuplicateRegistrations(
        currentExtensionBundlePath: String,
        extensionBundleIdentifier: String
    ) {
        let normalizedCurrentPath = URL(fileURLWithPath: currentExtensionBundlePath).standardizedFileURL.path
        let registeredPaths = AssistantFinderExtensionStateInspector
            .registeredPluginPaths(extensionBundleIdentifier: extensionBundleIdentifier)

        for registeredPath in registeredPaths where registeredPath != normalizedCurrentPath {
            run("/usr/bin/pluginkit", arguments: ["-r", registeredPath])
        }
    }

    @discardableResult
    private static func run(_ launchPath: String, arguments: [String]) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus
        } catch {
            return -1
        }
    }

}

final class AssistantDesktopActivationCoordinator {
    private static let finderBundleIdentifier = "com.apple.finder"
    private static let dockBundleIdentifier = "com.apple.dock"
    private static let activationCooldown: TimeInterval = 0.35
    private static let permissionRetryInterval: TimeInterval = 5
    private static let maximumPermissionRetryCount = 24

    private let logger: AssistantRuntimeLogger
    private let openAppHandler: @MainActor () -> Void
    private let showDesktopMenuHandler: @MainActor (CGPoint) -> Void
    private var globalMouseMonitor: Any?
    private var rightMouseEventTap: CFMachPort?
    private var rightMouseRunLoopSource: CFRunLoopSource?
    private var permissionRetryTimer: Timer?
    private var permissionRetryCount = 0
    private var hasShownPermissionGuidance = false
    private var lastActivationAt: Date = .distantPast

    init(
        logger: AssistantRuntimeLogger,
        openAppHandler: @escaping @MainActor () -> Void,
        showDesktopMenuHandler: @escaping @MainActor (CGPoint) -> Void
    ) {
        self.logger = logger
        self.openAppHandler = openAppHandler
        self.showDesktopMenuHandler = showDesktopMenuHandler
    }

    deinit {
        if let globalMouseMonitor {
            NSEvent.removeMonitor(globalMouseMonitor)
        }
        if let rightMouseRunLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), rightMouseRunLoopSource, .commonModes)
        }
        if let rightMouseEventTap {
            CFMachPortInvalidate(rightMouseEventTap)
        }
        permissionRetryTimer?.invalidate()
    }

    func start() {
        guard globalMouseMonitor == nil, rightMouseEventTap == nil else {
            return
        }

        requestDesktopRightClickPermissionsIfNeeded()

        if installRightMouseEventTap() {
            globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(
                matching: [.leftMouseDown]
            ) { [weak self] event in
                DispatchQueue.main.async { [weak self] in
                    self?.handleDesktopClick(event)
                }
            }
            return
        }

        schedulePermissionRetryIfNeeded()
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] event in
            DispatchQueue.main.async { [weak self] in
                self?.handleDesktopClick(event)
            }
        }
    }

    func stop() {
        guard let globalMouseMonitor else {
            removeRightMouseEventTap()
            return
        }

        NSEvent.removeMonitor(globalMouseMonitor)
        self.globalMouseMonitor = nil
        removeRightMouseEventTap()
        permissionRetryTimer?.invalidate()
        permissionRetryTimer = nil
    }

    private func handleDesktopClick(_ event: NSEvent) {
        if shouldOpenApp(for: event) {
            openApp()
            return
        }

        guard shouldActivateFinder(for: event) else {
            return
        }

        activateFinder()
    }

    private func shouldOpenApp(for event: NSEvent) -> Bool {
        guard Date().timeIntervalSince(lastActivationAt) >= Self.activationCooldown else {
            return false
        }

        guard event.type == .rightMouseDown else {
            return false
        }

        guard event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.option) else {
            return false
        }

        let clickPoint = event.locationInWindow
        guard isPointInsideVisibleDesktopArea(clickPoint) else {
            return false
        }

        let shouldOpen = !hasForegroundWindow(at: clickPoint)
        if shouldOpen {
            logger.info("Detected Option-right-click on desktop background; opening app")
        }
        return shouldOpen
    }

    private func openApp() {
        lastActivationAt = Date()
        Task { @MainActor in
            openAppHandler()
        }
    }

    private func shouldActivateFinder(for event: NSEvent) -> Bool {
        guard Date().timeIntervalSince(lastActivationAt) >= Self.activationCooldown else {
            return false
        }

        guard let finder = NSRunningApplication
            .runningApplications(withBundleIdentifier: Self.finderBundleIdentifier)
            .first(where: { !$0.isTerminated }) else {
            return false
        }

        guard !finder.isActive else {
            return false
        }

        let clickPoint = event.locationInWindow
        guard isPointInsideVisibleDesktopArea(clickPoint) else {
            return false
        }

        return !hasForegroundWindow(at: clickPoint)
    }

    private func activateFinder() {
        guard let finder = NSRunningApplication
            .runningApplications(withBundleIdentifier: Self.finderBundleIdentifier)
            .first(where: { !$0.isTerminated }) else {
            return
        }

        lastActivationAt = Date()

        guard finder.activate(options: [.activateAllWindows, .activateIgnoringOtherApps]) else {
            logger.warning("Failed to activate Finder after desktop background click")
            return
        }

        logger.info("Activated Finder after desktop background click")
    }

    private func installRightMouseEventTap() -> Bool {
        guard CGPreflightListenEventAccess() else {
            logger.warning("Desktop right-click event tap is unavailable")
            return false
        }

        let eventMask = (1 << CGEventType.rightMouseDown.rawValue)

        let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { _, type, event, userInfo in
                guard let userInfo else {
                    return Unmanaged.passUnretained(event)
                }

                let coordinator = Unmanaged<AssistantDesktopActivationCoordinator>
                    .fromOpaque(userInfo)
                    .takeUnretainedValue()
                return coordinator.handleRightMouseEventTap(type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )

        guard let eventTap else {
            logger.warning("Failed to install right-mouse event tap for desktop background interception")
            return false
        }

        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)

        rightMouseEventTap = eventTap
        rightMouseRunLoopSource = runLoopSource
        permissionRetryTimer?.invalidate()
        permissionRetryTimer = nil
        permissionRetryCount = 0
        logger.info("Installed right-mouse event tap for desktop background interception")
        return true
    }

    private func removeRightMouseEventTap() {
        if let rightMouseRunLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), rightMouseRunLoopSource, .commonModes)
            self.rightMouseRunLoopSource = nil
        }

        if let rightMouseEventTap {
            CFMachPortInvalidate(rightMouseEventTap)
            self.rightMouseEventTap = nil
        }
    }

    private func requestDesktopRightClickPermissionsIfNeeded() {
        guard AssistantBuildRuntime.isDesktopActivationBridgeEnabled else {
            return
        }

        let needsDesktopEventAccess = !CGPreflightListenEventAccess()

        if needsDesktopEventAccess {
            logger.notice(
                "Desktop right-click bridge is unavailable; showing General settings guidance"
            )
            presentDesktopPermissionGuidanceIfNeeded()
        }
    }

    private func schedulePermissionRetryIfNeeded() {
        guard permissionRetryTimer == nil else {
            return
        }

        permissionRetryTimer = Timer.scheduledTimer(
            withTimeInterval: Self.permissionRetryInterval,
            repeats: true
        ) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }

            self.permissionRetryCount += 1
            self.requestDesktopRightClickPermissionsIfNeeded()
            if self.installRightMouseEventTap() {
                timer.invalidate()
                return
            }

            guard self.permissionRetryCount < Self.maximumPermissionRetryCount else {
                self.logger.warning("Stopped retrying desktop right-click event tap installation after setup timeout")
                timer.invalidate()
                self.permissionRetryTimer = nil
                return
            }
        }
    }

    private func presentDesktopPermissionGuidanceIfNeeded() {
        guard !hasShownPermissionGuidance else {
            return
        }

        hasShownPermissionGuidance = true

        DispatchQueue.main.async { [weak self] in
            guard let self else {
                return
            }

            NSApp.activate(ignoringOtherApps: true)

            let alert = NSAlert()
            alert.messageText = AssistantLocalized.text(
                zh: "桌面快捷菜单暂不可用",
                en: "Desktop Shortcut Menu Unavailable"
            )
            alert.informativeText = AssistantLocalized.text(
                zh: "请到“通用”页面查看桌面快捷菜单状态，并按页面提示完成设置。",
                en: "Open General to check the desktop shortcut menu status and finish setup as prompted."
            )
            alert.alertStyle = .informational
            alert.addButton(withTitle: AssistantLocalized.text(zh: "打开通用", en: "Open General"))
            alert.addButton(withTitle: AssistantLocalized.text(zh: "稍后", en: "Later"))

            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                self.openAppHandler()
            }
        }
    }

    private func handleRightMouseEventTap(
        type: CGEventType,
        event: CGEvent
    ) -> Unmanaged<CGEvent>? {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let rightMouseEventTap {
                CGEvent.tapEnable(tap: rightMouseEventTap, enable: true)
                logger.notice("Re-enabled desktop right-click event tap after system disabled it")
            }
            return Unmanaged.passUnretained(event)

        case .rightMouseDown:
            break

        default:
            return Unmanaged.passUnretained(event)
        }

        let clickPoint = NSEvent(cgEvent: event)?.locationInWindow ?? event.location
        guard shouldHandleDesktopRightClick(at: clickPoint) else {
            return Unmanaged.passUnretained(event)
        }

        let modifiers = event.flags
        if modifiers.contains(.maskAlternate) {
            logger.info("Intercepted Option-right-click on desktop background; opening app")
            openApp()
            return nil
        }

        logger.info("Intercepted right-click on desktop background; showing custom container menu")
        Task { @MainActor [weak self] in
            self?.showDesktopMenuHandler(clickPoint)
        }
        return nil
    }

    private func shouldHandleDesktopRightClick(at point: CGPoint) -> Bool {
        guard isPointInsideVisibleDesktopArea(point) else {
            return false
        }

        guard !hasForegroundWindow(at: point) else {
            return false
        }

        return true
    }

    private func isPointInsideVisibleDesktopArea(_ point: CGPoint) -> Bool {
        NSScreen.screens.contains { screen in
            screen.visibleFrame.contains(point)
        }
    }

    private func hasForegroundWindow(at point: CGPoint) -> Bool {
        // Excluding desktop elements lets us treat a windowless hit as a wallpaper/icon-surface click.
        guard let windowInfo = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
            as? [[String: AnyObject]] else {
            logger.warning("Failed to inspect on-screen windows for desktop click bridge")
            return true
        }

        for entry in windowInfo {
            guard let alpha = entry[kCGWindowAlpha as String] as? Double, alpha > 0 else {
                continue
            }

            if shouldIgnoreWindow(entry) {
                continue
            }

            guard let rawBounds = entry[kCGWindowBounds as String] else {
                continue
            }

            let boundsDictionary = rawBounds as! CFDictionary
            guard
                  let bounds = CGRect(dictionaryRepresentation: boundsDictionary),
                  bounds.contains(point) else {
                continue
            }

            let ownerName = (entry[kCGWindowOwnerName as String] as? String) ?? "unknown"
            let windowLayer = (entry[kCGWindowLayer as String] as? Int) ?? 0
            logger.debug(
                "Desktop click bridge ignored point \(Int(point.x)),\(Int(point.y)) because window owner=\(ownerName, privacy: .public) layer=\(windowLayer)"
            )
            return true
        }

        return false
    }

    private func shouldIgnoreWindow(_ entry: [String: AnyObject]) -> Bool {
        guard let ownerPID = entry[kCGWindowOwnerPID as String] as? pid_t,
              let application = NSRunningApplication(processIdentifier: ownerPID) else {
            return false
        }

        return application.bundleIdentifier == Self.dockBundleIdentifier
    }
}

private enum AssistantDesktopMenuCommandKind: String {
    case openApp
    case openOpenWithSettings
    case openNewFileSettings
    case createFile
    case favoriteFolder
    case quickAction
}

private final class AssistantDesktopMenuCommand: NSObject {
    let kind: AssistantDesktopMenuCommandKind
    let rid: String
    let targetPaths: [String]
    let trigger: String

    init(
        kind: AssistantDesktopMenuCommandKind,
        rid: String,
        targetPaths: [String],
        trigger: String = "ctx-container"
    ) {
        self.kind = kind
        self.rid = rid
        self.targetPaths = targetPaths
        self.trigger = trigger
    }
}

private final class AssistantDesktopContextMenuPresenter {
    private let logger: AssistantRuntimeLogger

    init(logger: AssistantRuntimeLogger) {
        self.logger = logger
    }

    @MainActor
    func present(menu: NSMenu, at screenPoint: CGPoint) {
        let hostWindow = NSWindow(
            contentRect: NSRect(x: screenPoint.x, y: screenPoint.y, width: 1, height: 1),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        hostWindow.isOpaque = false
        hostWindow.backgroundColor = .clear
        hostWindow.hasShadow = false
        hostWindow.ignoresMouseEvents = false
        hostWindow.level = .popUpMenu
        hostWindow.collectionBehavior = [.transient, .canJoinAllSpaces, .ignoresCycle]

        let hostView = NSView(frame: NSRect(x: 0, y: 0, width: 1, height: 1))
        hostView.wantsLayer = true
        hostView.layer?.backgroundColor = NSColor.clear.cgColor
        hostWindow.contentView = hostView

        NSApp.activate(ignoringOtherApps: true)
        hostWindow.orderFrontRegardless()
        let didPop = menu.popUp(positioning: nil, at: .zero, in: hostView)
        logger.info("Presented desktop background menu at \(Int(screenPoint.x)),\(Int(screenPoint.y)) selected=\(didPop)")
        hostWindow.orderOut(nil)
    }
}

extension RCAAppDelegate {
    private static let desktopContainerTargetPath = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Desktop", isDirectory: true)
        .path

    private static let desktopHiddenQuickActionIDs: Set<String> = [
        "copy-to",
        "move-to",
        "cut",
        "delete-direct",
        "airdrop",
        "batch-rename",
        "scan-qr-code",
        "encrypt-zip",
        "extract-zip",
        "extract-image-text",
        "send-shortcut-to-desktop"
    ]

    @MainActor
    func presentDesktopContainerContextMenu(at screenPoint: CGPoint) {
        appState.refresh()
        let targetPath = authorizedDesktopContainerTargetPath() ?? Self.desktopContainerTargetPath
        let menu = makeDesktopContainerContextMenu(targetPath: targetPath)
        AssistantDesktopContextMenuPresenter(logger: logger).present(menu: menu, at: screenPoint)
    }

    private func authorizedDesktopContainerTargetPath() -> String? {
        let desktopPath = URL(fileURLWithPath: Self.desktopContainerTargetPath, isDirectory: true)
            .standardizedFileURL
            .resolvingSymlinksInPath()
            .path

        return matchingAuthorizedDirectory(forPath: desktopPath) == nil ? nil : desktopPath
    }

    private func makeDesktopContainerContextMenu(targetPath: String) -> NSMenu {
        let menu = NSMenu(title: AssistantLocalized.appName)

        if let openWithItem = desktopContainerOpenWithMenuItem(targetPath: targetPath) {
            menu.addItem(openWithItem)
        }

        desktopContainerNewFileMenuItems(targetPath: targetPath).forEach(menu.addItem)

        if let fileInfoItem = desktopQuickActionMenuItem(identifier: FinderPayloadDeduplication.fileInfoActionIdentifier, targetPath: targetPath) {
            menu.addItem(fileInfoItem)
        }

        if let favoriteFoldersItem = desktopContainerFavoriteFoldersMenuItem() {
            menu.addItem(favoriteFoldersItem)
        }

        let quickActions = appState.actions
            .filter(\.enabled)
            .filter(\.isAvailableOnCurrentSystem)
            .filter { $0.id != FinderPayloadDeduplication.fileInfoActionIdentifier }
            .filter { !Self.desktopHiddenQuickActionIDs.contains($0.id) }
        quickActions.forEach { item in
            menu.addItem(makeDesktopQuickActionMenuItem(item, targetPath: targetPath))
        }

        return menu
    }

    private func desktopContainerOpenWithMenuItem(targetPath: String) -> NSMenuItem? {
        guard UserDefaults.group.showOpenWithMenuGroup else {
            return nil
        }

        let menuItem = NSMenuItem()
        menuItem.title = AssistantLocalized.text(zh: "打开方式", en: "Open With")
        menuItem.image = desktopMenuImage(systemSymbolName: "square.grid.2x2", fallback: "app")

        let submenu = NSMenu(title: "Open With submenu")
        appState.apps
            .map { desktopOpenWithApplicationMenuItem(for: $0, targetPath: targetPath) }
            .forEach(submenu.addItem)
        submenu.addItem(desktopOpenWithSettingsMenuItem())

        menuItem.submenu = submenu
        return menuItem
    }

    private func desktopOpenWithApplicationMenuItem(for item: OpenWithApplication, targetPath: String) -> NSMenuItem {
        let child = NSMenuItem()
        child.target = self
        child.title = item.name
        child.action = #selector(handleDesktopContextMenuCommand(_:))
        child.toolTip = item.url.path
        child.representedObject = AssistantDesktopMenuCommand(
            kind: .openApp,
            rid: item.id,
            targetPaths: [targetPath]
        )
        child.image = AssistantFileIconCache.icon(forPath: item.url.path)
        return child
    }

    private func desktopOpenWithSettingsMenuItem() -> NSMenuItem {
        let child = NSMenuItem()
        child.target = self
        child.title = AssistantLocalized.text(zh: "新增默认打开方式", en: "Add Default Open-With App")
        child.action = #selector(handleDesktopContextMenuCommand(_:))
        child.toolTip = AssistantLocalized.text(
            zh: "打开 App 并进入“打开方式”设置",
            en: "Open the app and jump to Open With settings"
        )
        child.representedObject = AssistantDesktopMenuCommand(
            kind: .openOpenWithSettings,
            rid: "open-with-settings",
            targetPaths: []
        )
        child.image = desktopMenuImage(systemSymbolName: "plus.app", fallback: "plus")
        return child
    }

    private func desktopQuickActionMenuItem(identifier: String, targetPath: String) -> NSMenuItem? {
        guard let item = appState.actions.first(where: { action in
            action.id == identifier
                && action.enabled
                && action.isAvailableOnCurrentSystem
                && !Self.desktopHiddenQuickActionIDs.contains(action.id)
        }) else {
            return nil
        }

        return makeDesktopQuickActionMenuItem(item, targetPath: targetPath)
    }

    private func makeDesktopQuickActionMenuItem(_ item: ContextQuickAction, targetPath: String) -> NSMenuItem {
        let menuItem = NSMenuItem()
        menuItem.target = self
        menuItem.title = item.displayName
        menuItem.action = #selector(handleDesktopContextMenuCommand(_:))
        menuItem.toolTip = item.displayName
        menuItem.representedObject = AssistantDesktopMenuCommand(
            kind: .quickAction,
            rid: item.id,
            targetPaths: [targetPath]
        )
        menuItem.image = desktopMenuImage(systemSymbolName: item.icon, fallback: "doc")
        return menuItem
    }


    private func desktopContainerFavoriteFoldersMenuItem() -> NSMenuItem? {
        guard !appState.cdirs.isEmpty else {
            return nil
        }

        let menuItem = NSMenuItem()
        menuItem.title = AssistantLocalized.text(zh: "常用目录", en: "Favorite Folders")
        menuItem.image = desktopMenuImage(systemSymbolName: "folder.badge.questionmark", fallback: "folder")

        let submenu = NSMenu(title: "Favorite Folders submenu")
        appState.cdirs.forEach { directory in
            let child = NSMenuItem()
            child.target = self
            child.title = directory.name
            child.action = #selector(handleDesktopContextMenuCommand(_:))
            child.toolTip = directory.url.path
            child.representedObject = AssistantDesktopMenuCommand(
                kind: .favoriteFolder,
                rid: directory.id,
                targetPaths: [directory.url.path],
                trigger: "favorite-folder"
            )
            child.image = desktopMenuImage(systemSymbolName: "folder", fallback: "folder")
            submenu.addItem(child)
        }

        menuItem.submenu = submenu
        return menuItem
    }

    private func desktopContainerNewFileMenuItems(targetPath: String) -> [NSMenuItem] {
        let enabledTemplates = appState.newFiles.filter(\.enabled)

        let menuItem = NSMenuItem()
        menuItem.title = AssistantLocalized.text(zh: "新建文件", en: "New File")
        menuItem.image = desktopMenuImage(systemSymbolName: "doc.badge.plus", fallback: "doc")

        let submenu = NSMenu(title: "file create menu")
        enabledTemplates
            .map { desktopNewFileChildMenuItem(for: $0, targetPath: targetPath) }
            .forEach(submenu.addItem)
        submenu.addItem(desktopNewFileSettingsMenuItem())

        menuItem.submenu = submenu
        return [menuItem]
    }

    private func desktopNewFileSettingsMenuItem() -> NSMenuItem {
        let child = NSMenuItem()
        child.target = self
        child.title = AssistantLocalized.text(zh: "新建自定义模版", en: "Add Custom Template")
        child.action = #selector(handleDesktopContextMenuCommand(_:))
        child.toolTip = AssistantLocalized.text(
            zh: "打开 App 并进入“新建文件”设置",
            en: "Open the app and jump to New File settings"
        )
        child.representedObject = AssistantDesktopMenuCommand(
            kind: .openNewFileSettings,
            rid: "new-file-settings",
            targetPaths: []
        )
        child.image = desktopMenuImage(systemSymbolName: "plus.app", fallback: "plus")
        return child
    }

    private func desktopNewFileChildMenuItem(for item: NewFileTemplate, targetPath: String) -> NSMenuItem {
        let child = NSMenuItem()
        child.target = self
        child.title = item.displayName
        child.action = #selector(handleDesktopContextMenuCommand(_:))
        child.toolTip = item.displayName
        child.representedObject = AssistantDesktopMenuCommand(
            kind: .createFile,
            rid: item.id,
            targetPaths: [targetPath]
        )

        guard UserDefaults.group.showNewFileTemplateImages else {
            return child
        }

        if let app = item.openApp {
            child.image = AssistantFileIconCache.icon(forPath: app.path)
            child.image?.isTemplate = true
        } else if item.icon.starts(with: "icon-"), let image = NSImage(named: item.icon) {
            child.image = image
            child.image?.isTemplate = true
        } else {
            child.image = desktopMenuImage(systemSymbolName: item.icon, fallback: "doc")
        }

        return child
    }

    @MainActor @objc
    private func handleDesktopContextMenuCommand(_ menuItem: NSMenuItem) {
        guard let command = menuItem.representedObject as? AssistantDesktopMenuCommand else {
            logger.warning("Desktop context menu action is missing command payload")
            return
        }

        logger.info(
            "Desktop context menu action kind=\(command.kind.rawValue, privacy: .public) rid=\(command.rid, privacy: .public) targets=\(command.targetPaths.joined(separator: " | "), privacy: .public)"
        )

        switch command.kind {
        case .openApp:
            openApp(rid: command.rid, target: command.targetPaths)
        case .openOpenWithSettings:
            showSettingsWindow(selectedTab: .apps)
        case .openNewFileSettings:
            showSettingsWindow(selectedTab: .newFile)
        case .createFile:
            createFile(rid: command.rid, target: command.targetPaths)
        case .favoriteFolder:
            openCommonDirs(target: command.targetPaths)
        case .quickAction:
            actionHandler(rid: command.rid, target: command.targetPaths, trigger: command.trigger)
        }
    }

    private func desktopMenuImage(systemSymbolName name: String, fallback: String) -> NSImage? {
        if let image = renderedDesktopMenuSymbolImage(name: name) {
            return image
        }

        logger.warning("Invalid desktop menu symbol \(name, privacy: .public); falling back to \(fallback, privacy: .public)")
        return renderedDesktopMenuSymbolImage(name: fallback)
    }

    private func renderedDesktopMenuSymbolImage(name: String) -> NSImage? {
        guard let baseImage = NSImage(systemSymbolName: name, accessibilityDescription: name)?.copy() as? NSImage else {
            return nil
        }

        baseImage.isTemplate = false
        let tintedImage = NSImage(size: baseImage.size, flipped: false) { rect in
            baseImage.draw(in: rect)
            Self.currentDrawingAppearance().performAsCurrentDrawingAppearance {
                Self.desktopMenuSymbolTintColor(for: Self.currentDrawingAppearance()).set()
                rect.fill(using: .sourceIn)
            }
            return true
        }
        tintedImage.isTemplate = false
        return tintedImage
    }

    private static func currentDrawingAppearance() -> NSAppearance {
        NSAppearance.currentDrawing()
    }

    private static func desktopMenuSymbolTintColor(for appearance: NSAppearance) -> NSColor {
        let darkAppearances: [NSAppearance.Name] = [
            .darkAqua,
            .vibrantDark,
            .accessibilityHighContrastDarkAqua,
            .accessibilityHighContrastVibrantDark
        ]
        let matchingAppearances: [NSAppearance.Name] = darkAppearances + [
            .aqua,
            .vibrantLight,
            .accessibilityHighContrastAqua,
            .accessibilityHighContrastVibrantLight
        ]

        if let bestMatch = appearance.bestMatch(from: matchingAppearances),
           darkAppearances.contains(bestMatch) {
            return NSColor.white.withAlphaComponent(0.96)
        }

        return NSColor(calibratedWhite: 0.12, alpha: 1)
    }
}
