//
//  AssistantFinderExtension.swift
//  AssistantFinderExtension
//
//  Created by 老谭 on 2026/4/30.
//

import AppKit
import Cocoa
import FinderSync
import OSLog

private let extensionLogger = makeAssistantLogger(
    subsystem: Bundle.main.bundleIdentifier ?? "RightClickAssistantPro",
    category: "FinderOpen"
)

@MainActor
final class AssistantFinderExtension: FIFinderSync {
    private let messageBus = ExtensionMessageBus.shared
    private let hostStateRequestMessageName = "running-request"

    private(set) var isHostAppOpen = false
    private var triggerMenuKind = FIMenuKind.contextualMenuForContainer
    private var actionTagMap: [Int: String] = [:]
    private var observedDirectoryDates: [String: Date] = [:]
    private var cachedVolumeScopeURLs: Set<URL> = []

    lazy var appState: AssistantRuntimeState = .init(inExt: true, minimumRefreshInterval: 1.5)

    override init() {
        super.init()
        configureInitialFinderScope()
        registerMessageObservers()
        refreshHostApplicationState()
        requestHostStateIfNeeded()
        persistLaunchHeartbeat()
    }

    private func configureInitialFinderScope() {
        applyFinderScope(authorizedURLs: loadPersistedObservedDirectories(), reason: "initial")
        hydrateVolumeFinderScopeAsync()
        extensionLogger.info("FinderSync() launched from \(Bundle.main.bundlePath as NSString)")
    }

    private var defaultFinderScopeURLs: Set<URL> {
        var urls: Set<URL> = [
            normalizedFinderScopeURL(FileManager.default.homeDirectoryForCurrentUser),
            normalizedFinderScopeURL(URL(fileURLWithPath: "/Users", isDirectory: true))
        ]

        if let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first {
            urls.insert(normalizedFinderScopeURL(desktopURL))
        }

        urls.formUnion(cachedVolumeScopeURLs)

        return urls
    }

    private func normalizedFinderScopeURL(_ url: URL) -> URL {
        url.standardizedFileURL.resolvingSymlinksInPath()
    }

    private func applyFinderScope(authorizedURLs: Set<URL>, reason: String) {
        let normalizedAuthorizedURLs = Set(authorizedURLs.map(normalizedFinderScopeURL))
        let urls = defaultFinderScopeURLs.union(normalizedAuthorizedURLs)
        FIFinderSyncController.default().directoryURLs = urls
        extensionLogger.info(
            "updated finder scope reason=\(reason, privacy: .public) count=\(urls.count) first=\((urls.first?.path ?? "nil"), privacy: .public)"
        )
    }

    private func loadPersistedObservedDirectories() -> Set<URL> {
        let restoredURLs = Set(
            AssistantStateSnapshotStore.shared
                .loadAuthorizedDirectoriesForFinderScope()
                .map(\.url)
        )
        if !restoredURLs.isEmpty {
            extensionLogger.info("restored \(restoredURLs.count) persisted observed directories")
        }
        return restoredURLs
    }

    private func hydrateVolumeFinderScopeAsync() {
        Task.detached(priority: .utility) {
            let visibleVolumes = FileManager.default.mountedVolumeURLs(
                includingResourceValuesForKeys: nil,
                options: .skipHiddenVolumes
            ) ?? []
            let volumeURLs = Set(
                visibleVolumes.map {
                    $0.standardizedFileURL.resolvingSymlinksInPath()
                }
            )

            await MainActor.run {
                self.cachedVolumeScopeURLs = volumeURLs
                self.applyFinderScope(
                    authorizedURLs: self.loadPersistedObservedDirectories(),
                    reason: "volume-hydration"
                )
            }
        }
    }

    private func registerMessageObservers() {
        messageBus.on(name: "quit") { [weak self] _ in
            self?.markHostAppClosed()
        }

        messageBus.on(name: "running") { [weak self] payload in
            self?.refreshHostState(with: payload)
        }
    }

    private func refreshHostApplicationState() {
        guard let hostBundleIdentifier = hostApplicationBundleIdentifier else {
            extensionLogger.warning("host bundle identifier unavailable for extension bundle=\(Bundle.main.bundleIdentifier ?? "nil", privacy: .public)")
            isHostAppOpen = false
            return
        }

        let runningHostApplications = NSRunningApplication
            .runningApplications(withBundleIdentifier: hostBundleIdentifier)
            .filter { !$0.isTerminated }
        isHostAppOpen = !runningHostApplications.isEmpty

        extensionLogger.info(
            "host state refreshed bundleID=\(hostBundleIdentifier, privacy: .public) runningCount=\(runningHostApplications.count) isHostAppOpen=\(self.isHostAppOpen)"
        )
    }

    private var hostApplicationBundleIdentifier: String? {
        guard let extensionBundleIdentifier = Bundle.main.bundleIdentifier,
              extensionBundleIdentifier.hasSuffix(".ext") else {
            return nil
        }

        return String(extensionBundleIdentifier.dropLast(4))
    }

    private func requestHostStateIfNeeded() {
        guard isHostAppOpen else {
            extensionLogger.info("skip running-request because host app is not open")
            return
        }

        extensionLogger.info("send running-request to host app")
        messageBus.sendMessage(
            name: hostStateRequestMessageName,
            data: ExtensionMessagePayload(action: hostStateRequestMessageName)
        )
    }

    private func persistLaunchHeartbeat() {
        UserDefaults.group.set(Date().timeIntervalSince1970, forKey: SharedPreferenceKey.finderExtensionHeartbeat)
    }

    private func markHostAppClosed() {
        isHostAppOpen = false
    }

    private func refreshHostState(with payload: ExtensionMessagePayload) {
        isHostAppOpen = true
        extensionLogger.info(
            "received host running payload targetCount=\(payload.target.count) firstTarget=\((payload.target.first ?? "nil"), privacy: .public)"
        )
        updateObservedDirectories(using: payload.target)

        Task { @MainActor in
            appState.refreshIfNeeded()
        }
    }

    private func updateObservedDirectories(using paths: [String]) {
        let urls = Set(paths.map(URL.init(fileURLWithPath:)))
        applyFinderScope(authorizedURLs: urls, reason: "host-running")
    }

    private func sendMessage(
        action: String,
        target: [String],
        rid: String = "",
        trigger: String = ""
    ) {
        messageBus.sendMessage(
            name: SharedPreferenceKey.messageFromFinder,
            data: ExtensionMessagePayload(
                action: action,
                target: target,
                rid: rid,
                trigger: trigger
            )
        )
    }

    override func beginObservingDirectory(at url: URL) {
        observedDirectoryDates[url.standardizedFileURL.path] = Date()
        extensionLogger.info("beginObservingDirectoryAtURL: \(url.path as NSString)")
        for directory in FIFinderSyncController.default().directoryURLs ?? [] {
            extensionLogger.notice("Sync directory set to \(directory.path)")
        }
    }

    override func endObservingDirectory(at url: URL) {
        observedDirectoryDates.removeValue(forKey: url.standardizedFileURL.path)
        extensionLogger.info("endObservingDirectoryAtURL: \(url.path as NSString)")
    }

    override func requestBadgeIdentifier(for url: URL) {
        extensionLogger.debug("requestBadgeIdentifierForURL: \(url.path)")
    }

    override var toolbarItemName: String {
        AssistantLocalized.appName
    }

    override var toolbarItemToolTip: String {
        AssistantLocalized.text(
            zh: "右键工具Pro：点击工具栏图标打开菜单。",
            en: "RightMenuPro: click the toolbar icon to open the menu."
        )
    }

    override var toolbarItemImage: NSImage {
        guard let image = NSImage(named: "AssistantToolbarRaster") else {
            preconditionFailure("Missing toolbar image asset: AssistantToolbarRaster")
        }

        image.isTemplate = false
        return image
    }

    @MainActor override func menu(for menuKind: FIMenuKind) -> NSMenu {
        triggerMenuKind = menuKind
        actionTagMap.removeAll(keepingCapacity: true)

        let fallbackMenu = NSMenu(title: AssistantLocalized.appName)
        let selectedPaths = FIFinderSyncController.default().selectedItemURLs()?.map(\.path) ?? []
        let targetedPath = FIFinderSyncController.default().targetedURL()?.path ?? "nil"
        let fallbackPath = currentContainerFallbackURL?.path ?? "nil"
        let observedDirectories = Array(FIFinderSyncController.default().directoryURLs ?? [])
        extensionLogger.info(
            "menu request kind=\(self.menuKindName(menuKind), privacy: .public) selectedCount=\(selectedPaths.count) selectedPaths=\(self.joinedLogValue(from: selectedPaths), privacy: .public) targetedPath=\(targetedPath, privacy: .public) fallbackPath=\(fallbackPath, privacy: .public) observedCount=\(self.observedDirectoryDates.count) finderScopeCount=\(observedDirectories.count) finderScopeFirst=\((observedDirectories.first?.path ?? "nil"), privacy: .public)"
        )
        refreshHostApplicationState()
        requestHostStateIfNeeded()

        if isHostAppOpen {
            persistLaunchHeartbeat()
            appState.refreshIfNeeded()
        } else {
            extensionLogger.warning("host app is not running when Finder requested the menu")
            return fallbackMenu
        }

        guard supportsMenuComposition(for: menuKind) else {
            extensionLogger.warning("unsupported menu kind \(self.menuKindName(menuKind), privacy: .public)")
            return fallbackMenu
        }

        let menu = contextMenuComposer.makeMenu()
        let menuTitles = menu.items.map(\.title).joined(separator: " | ")
        extensionLogger.info(
            "menu built kind=\(self.menuKindName(menuKind), privacy: .public) itemCount=\(menu.items.count) titles=\(menuTitles, privacy: .public)"
        )
        return menu
    }

    private func supportsMenuComposition(for menuKind: FIMenuKind) -> Bool {
        switch menuKind {
        case .toolbarItemMenu, .contextualMenuForItems, .contextualMenuForContainer:
            return true
        default:
            return false
        }
    }

    private func menuKindName(_ menuKind: FIMenuKind) -> String {
        switch menuKind {
        case .contextualMenuForItems:
            return "contextualMenuForItems"
        case .contextualMenuForContainer:
            return "contextualMenuForContainer"
        case .contextualMenuForSidebar:
            return "contextualMenuForSidebar"
        case .toolbarItemMenu:
            return "toolbarItemMenu"
        @unknown default:
            return "unknown"
        }
    }

    private func joinedLogValue(from paths: [String]) -> String {
        guard !paths.isEmpty else {
            return "[]"
        }

        return paths.joined(separator: " | ")
    }

    private func uniqueTag(for rid: String) -> Int {
        var candidate = Int.random(in: 1 ... Int.max)
        while actionTagMap[candidate] != nil {
            candidate = Int.random(in: 1 ... Int.max)
        }
        actionTagMap[candidate] = rid
        return candidate
    }

    private var contextMenuComposer: FinderContextMenuComposer {
        FinderContextMenuComposer(
            appState: appState,
            menuKind: triggerMenuKind,
            selectedItemPaths: selectedItemPathsForCurrentMenu,
            selectedFolderPaths: selectedFolderPathsForFolderIconMenu,
            actionTargets: FinderMenuActionTargets(
                target: self,
                openAppSelector: #selector(openSelectedItems(_:)),
                openOpenWithSettingsSelector: #selector(openOpenWithSettings(_:)),
                openNewFileSettingsSelector: #selector(openNewFileSettings(_:)),
                openFolderIconSettingsSelector: #selector(openFolderIconSettings(_:)),
                createFileSelector: #selector(createTemplateFile(_:)),
                openFavoriteFolderSelector: #selector(openFavoriteFolder(_:)),
                quickActionSelector: #selector(performQuickAction(_:))
            ),
            makeTag: { rid in
                self.uniqueTag(for: rid)
            },
            menuImage: { name, fallback in
                self.menuImage(systemSymbolName: name, fallback: fallback)
            },
            resolveCreateDestinationPath: {
                self.resolveCreateDestinationPath()
            }
        )
    }

    private var selectedItemPathsForCurrentMenu: [String] {
        guard triggerMenuKind == .contextualMenuForItems else {
            return []
        }

        return (FIFinderSyncController.default().selectedItemURLs() ?? [])
            .map { $0.standardizedFileURL.path }
    }

    private var selectedFolderPathsForFolderIconMenu: [String] {
        guard triggerMenuKind == .contextualMenuForItems else {
            return []
        }

        let selectedURLs = FIFinderSyncController.default().selectedItemURLs() ?? []
        let folderPaths = selectedURLs
            .filter(isDirectory)
            .map { $0.standardizedFileURL.path }

        guard !folderPaths.isEmpty, folderPaths.count == selectedURLs.count else {
            return []
        }

        return folderPaths
    }

    @MainActor @objc func openFavoriteFolder(_ menuItem: NSMenuItem) {
        guard let rid = actionTagMap[menuItem.tag] else {
            extensionLogger.warning("未获取到rid")
            return
        }
        guard let dirItem = appState.cdirs.first(where: { $0.id == rid }) else {
            extensionLogger.warning("未找到对应的常用目录配置，rid: \(rid)")
            return
        }

        sendMessage(action: "common-dirs", target: [dirItem.url.path], rid: dirItem.id)
        extensionLogger.info("已发送打开常用目录消息: \(dirItem.name), 路径: \(dirItem.url.path)")
    }

    private func menuImage(systemSymbolName name: String, fallback: String) -> NSImage? {
        if let image = renderedMenuSymbolImage(name: name) {
            return image
        }

        extensionLogger.warning("无效的 SF Symbol 图标名: \(name), 使用兜底图标: \(fallback)")
        return renderedMenuSymbolImage(name: fallback)
    }

    private func renderedMenuSymbolImage(name: String) -> NSImage? {
        guard let baseImage = NSImage(systemSymbolName: name, accessibilityDescription: name)?.copy() as? NSImage else {
            return nil
        }

        baseImage.isTemplate = false
        let tintedImage = NSImage(size: baseImage.size, flipped: false) { rect in
            baseImage.draw(in: rect)
            Self.menuSymbolTintColor(for: Self.currentDrawingAppearance()).set()
            rect.fill(using: .sourceIn)
            return true
        }
        tintedImage.isTemplate = false
        return tintedImage
    }

    private static func currentDrawingAppearance() -> NSAppearance {
        NSAppearance.currentDrawing()
    }

    private static func menuSymbolTintColor(for appearance: NSAppearance) -> NSColor {
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

    private var fallbackObservedContainerURL: URL? {
        let fallbackURL = observedDirectoryDates
            .max(by: { $0.value < $1.value })
            .map { URL(fileURLWithPath: $0.key, isDirectory: true) }
        extensionLogger.debug(
            "fallback observed container path=\((fallbackURL?.path ?? "nil"), privacy: .public)"
        )
        return fallbackURL
    }

    private var currentContainerFallbackURL: URL? {
        if let targetedURL = FIFinderSyncController.default().targetedURL() {
            let standardizedURL = targetedURL.standardizedFileURL
            extensionLogger.debug(
                "use targeted container fallback path=\(standardizedURL.path, privacy: .public)"
            )
            return standardizedURL
        }

        let fallbackURL = fallbackObservedContainerURL
        extensionLogger.debug(
            "use observed container fallback path=\((fallbackURL?.path ?? "nil"), privacy: .public)"
        )
        return fallbackURL
    }

    private func selectionContext() -> FinderSelectionContext {
        let context = FinderSelectionContextResolver.resolve(
            for: triggerMenuKind,
            controller: .default(),
            fallbackContainerURL: currentContainerFallbackURL
        )
        extensionLogger.info(
            "selection context trigger=\(context.trigger, privacy: .public) targetCount=\(context.targets.count) targets=\(self.joinedLogValue(from: context.targets), privacy: .public)"
        )
        return context
    }

    private func resolveCreateDestinationPath() -> String? {
        let selectedTargets = FIFinderSyncController.default().selectedItemURLs()?.map(\.path) ?? []
        let normalizedDirectories = deduplicatedPaths(
            selectedTargets.map(normalizedDirectoryPath(for:))
        )

        switch triggerMenuKind {
        case .contextualMenuForItems:
            if normalizedDirectories.count == 1 {
                return normalizedDirectories[0]
            }
            return currentContainerFallbackURL.map { normalizedDirectoryPath(for: $0.path) } ?? normalizedDirectories.first

        case .toolbarItemMenu:
            if !normalizedDirectories.isEmpty {
                if normalizedDirectories.count == 1 {
                    return normalizedDirectories[0]
                }
                return currentContainerFallbackURL.map { normalizedDirectoryPath(for: $0.path) } ?? normalizedDirectories.first
            }
            return currentContainerFallbackURL.map { normalizedDirectoryPath(for: $0.path) }

        default:
            return currentContainerFallbackURL.map { normalizedDirectoryPath(for: $0.path) }
        }
    }

    private func normalizedDirectoryPath(for path: String) -> String {
        let normalizedPath = path.removingPercentEncoding ?? path
        let itemURL = URL(fileURLWithPath: normalizedPath).standardizedFileURL

        if isDirectory(at: itemURL) {
            return itemURL.path
        }

        return itemURL.deletingLastPathComponent().standardizedFileURL.path
    }

    private func isDirectory(at url: URL) -> Bool {
        guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey, .isSymbolicLinkKey]) else {
            return false
        }

        return values.isDirectory == true
            && values.isPackage != true
            && values.isSymbolicLink != true
    }

    private func deduplicatedPaths(_ paths: [String]) -> [String] {
        var seen: Set<String> = []

        return paths.filter { path in
            guard !path.isEmpty else {
                return false
            }

            return seen.insert(path).inserted
        }
    }

    @MainActor @objc func createTemplateFile(_ menuItem: NSMenuItem) {
        let representedCommand = menuItem.representedObject as? FinderCreateFileCommand

        guard let rid = representedCommand?.templateID ?? actionTagMap[menuItem.tag] else {
            extensionLogger.warning("not get rid for \(menuItem.tag)")
            return
        }
        guard let target = representedCommand?.targetPath ?? resolveCreateDestinationPath() else {
            extensionLogger.warning("not get create target path")
            return
        }
        extensionLogger.info("create file rid=\(rid, privacy: .public) target=\(target, privacy: .public)")
        sendMessage(action: "Create File", target: [target], rid: rid)
    }

    @MainActor @objc func openOpenWithSettings(_ menuItem: NSMenuItem) {
        sendMessage(action: "open-open-with-settings", target: [], rid: "open-with-settings")
    }

    @MainActor @objc func openNewFileSettings(_ menuItem: NSMenuItem) {
        sendMessage(action: "open-new-file-settings", target: [], rid: "new-file-settings")
    }

    @MainActor @objc func openFolderIconSettings(_ menuItem: NSMenuItem) {
        sendMessage(action: "open-folder-icon-settings", target: [], rid: "folder-icon-settings")
    }

    @MainActor @objc func performQuickAction(_ menuItem: NSMenuItem) {
        guard let rid = actionTagMap[menuItem.tag] else {
            extensionLogger.warning("not get rid")
            return
        }
        let selectionContext = selectionContext()
        if selectionContext.targets.isEmpty && !allowsEmptyTargets(for: rid) {
            extensionLogger.warning("not dir when actioning rid=\(rid, privacy: .public) trigger=\(selectionContext.trigger, privacy: .public)")
            return
        }
        extensionLogger.info(
            "actioning rid=\(rid, privacy: .public) trigger=\(selectionContext.trigger, privacy: .public) targetCount=\(selectionContext.targets.count) targets=\(self.joinedLogValue(from: selectionContext.targets), privacy: .public)"
        )
        sendMessage(
            action: "actioning",
            target: selectionContext.targets,
            rid: rid,
            trigger: selectionContext.trigger
        )
    }

    private func allowsEmptyTargets(for rid: String) -> Bool {
        switch rid {
        case "take-screenshot", "lock-screen", "toggle-appearance", "open-terminal":
            true
        default:
            false
        }
    }

    @objc func openSelectedItems(_ menuItem: NSMenuItem) {
        guard let rid = actionTagMap[menuItem.tag] else {
            extensionLogger.warning("not get rid")
            return
        }

        let selectionContext = selectionContext()
        guard !selectionContext.targets.isEmpty else {
            extensionLogger.warning("not get target for open rid=\(rid, privacy: .public) trigger=\(selectionContext.trigger, privacy: .public)")
            return
        }

        extensionLogger.info(
            "open rid=\(rid, privacy: .public) trigger=\(selectionContext.trigger, privacy: .public) targetCount=\(selectionContext.targets.count) targets=\(self.joinedLogValue(from: selectionContext.targets), privacy: .public)"
        )
        sendMessage(action: "open", target: selectionContext.targets, rid: rid)
    }
}
