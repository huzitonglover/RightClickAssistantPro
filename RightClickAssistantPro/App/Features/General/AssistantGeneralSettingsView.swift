//
//  AssistantGeneralSettingsView.swift
//  RightClickAssistantPro
//
//  Created by 老谭 on 2026/4/29.
//

import AppKit
import FinderSync
import SwiftUI

private final class AuthorizedFolderOpenPanelDelegate: NSObject, NSOpenSavePanelDelegate {
    func panel(_ sender: Any, shouldEnable url: URL) -> Bool {
        AuthorizedFolderSelectionPolicy.isAllowed(url)
    }

    func panel(_ sender: Any, validate url: URL) throws {
        guard AuthorizedFolderSelectionPolicy.isAllowed(url) else {
            throw NSError(
                domain: NSCocoaErrorDomain,
                code: NSUserCancelledError,
                userInfo: [
                    NSLocalizedDescriptionKey: AssistantLocalized.text(
                        zh: "请选择当前用户可访问的文件夹。",
                        en: "Choose a folder accessible by the current user."
                    )
                ]
            )
        }
    }
}

private enum AuthorizedFolderSelectionPolicy {
    private static let blockedExactPaths: Set<String> = [
        "/Applications",
        "/Library",
        "/System",
        "/Users",
        "/bin",
        "/private",
        "/sbin",
        "/usr",
        "/var"
    ]

    private static let blockedPathPrefixes: [String] = [
        "/System/",
        "/Library/",
        "/Applications/",
        "/bin/",
        "/private/",
        "/sbin/",
        "/usr/",
        "/var/"
    ]

    static func isAllowed(_ url: URL) -> Bool {
        let standardizedURL = url.standardizedFileURL.resolvingSymlinksInPath()

        guard standardizedURL.hasDirectoryPath || isExistingDirectory(standardizedURL) else {
            return false
        }

        let path = standardizedURL.path
        guard !blockedExactPaths.contains(path) else {
            return false
        }

        guard !blockedPathPrefixes.contains(where: { path.hasPrefix($0) }) else {
            return false
        }

        return true
    }

    private static func isExistingDirectory(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
            && isDirectory.boolValue
    }
}

struct AssistantGeneralSettingsView: View {
    @AssistantLogger(category: "settings-general")
    private var logger

    @AppStorage(SharedPreferenceKey.showMenuBarExtra) private var showMenuBarExtra = true
    @AppStorage(SharedPreferenceKey.showInDock) private var showInDock = false
    @AppStorage(SharedPreferenceKey.appLanguage, store: .group) private var appLanguage = AssistantLanguageOption.system.rawValue

    @EnvironmentObject private var store: AssistantRuntimeState

    @State private var isShowingNestedDirectoryAlert = false
    @State private var authorizedDirectoryImportErrorMessage: String?
    @State private var extensionEnabled = false
    @State private var extensionStatusRefreshTask: Task<Void, Never>?

    private let messager = ExtensionMessageBus.shared

    private var observedDirectoryPaths: [String] {
        store.effectiveAuthorizedDirectories.map(\.url.path)
    }

    private var snapshot: GeneralSettingsSnapshot {
        GeneralSettingsSnapshot(
            extensionEnabled: extensionEnabled,
            launchAtLoginEnabled: LaunchAtLogin.isEnabled,
            authorizedDirectoryCount: store.effectiveAuthorizedDirectoryCount
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                overviewCards
                extensionPanel
                startupAndAppearancePanel
                languagePanel
                authorizationPanel
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 8)
        }
        .alert(AssistantLocalized.text(zh: "目录选择无效", en: "Invalid Folder Selection"), isPresented: $isShowingNestedDirectoryAlert) {
            Button(AssistantLocalized.text(zh: "重新选择", en: "Choose Again")) {
                chooseAuthorizedDirectory()
            }
            Button(AssistantLocalized.text(zh: "取消", en: "Cancel"), role: .cancel) {}
        } message: {
            Text(
                AssistantLocalized.text(
                    zh: "当前目录已经被已授权的父级目录覆盖，请改选其他位置。",
                    en: "This folder is already covered by an authorized parent folder. Please choose another location."
                )
            )
        }
        .alert(
            AssistantLocalized.text(zh: "授权失败", en: "Authorization Failed"),
            isPresented: Binding(
                get: { authorizedDirectoryImportErrorMessage != nil },
                set: { if !$0 { authorizedDirectoryImportErrorMessage = nil } }
            )
        ) {
            Button(AssistantLocalized.text(zh: "知道了", en: "OK"), role: .cancel) {}
        } message: {
            Text(authorizedDirectoryImportErrorMessage ?? "")
        }
        .onAppear {
            beginExtensionStatusRefreshCycle()
            applyActivationPolicy(showInDock)
        }
        .onForeground {
            beginExtensionStatusRefreshCycle()
        }
        .onDisappear {
            extensionStatusRefreshTask?.cancel()
            extensionStatusRefreshTask = nil
        }
    }

    private var overviewCards: some View {
        HStack(spacing: 12) {
            ForEach(snapshot.overviewEntries) { entry in
                GeneralOverviewCard(entry: entry)
            }
        }
    }

    private var extensionPanel: some View {
        HStack(alignment: .center, spacing: 18) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(AssistantLocalized.text(zh: "Finder 扩展", en: "Finder Extension"))
                        .font(.title3.weight(.semibold))

                    Label(snapshot.extensionStatusTitle, systemImage: snapshot.extensionStatusIcon)
                        .font(.headline)
                        .foregroundStyle(snapshot.extensionStatusColor)
                }

                Text(
                    AssistantLocalized.text(
                        zh: "扩展启用后，右键工具的菜单项才会出现在 Finder 中。",
                        en: "The assistant menu appears in Finder only after the extension is enabled."
                    )
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                openExtensionManagement()
            } label: {
                Label(AssistantLocalized.text(zh: "打开扩展设置", en: "Open Extension Settings"), systemImage: "slider.horizontal.3")
            }
            .fixedSize()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var startupAndAppearancePanel: some View {
        GeneralSectionCard(
            title: AssistantLocalized.text(zh: "启动与显示", en: "Launch & Visibility"),
            detail: AssistantLocalized.text(
                zh: "默认不会在登录时自动启动；你可以在这里手动开启，并控制右键工具在顶部菜单栏和底部菜单栏中的显示形态。",
                en: "The app stays off at login by default. Enable it here only if you want it, and control how it appears in the menu bar and Dock."
            )
        ) {
            VStack(alignment: .leading, spacing: 14) {
                LaunchAtLogin.Toggle(AssistantLocalized.text(zh: "开机启动", en: "Launch at Login"))
                    .disabled(!LaunchAtLogin.isSupported)

                if LaunchAtLogin.isSupported {
                    Text(
                        AssistantLocalized.text(
                            zh: "只有在你手动打开此选项后，右键工具才会在登录时启动。",
                            en: "The app will launch at login only after you turn this option on."
                        )
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                if !LaunchAtLogin.isSupported {
                    Text(
                        AssistantLocalized.text(
                            zh: "macOS 12 暂不支持系统级开机启动开关，其余 Finder 功能可正常使用。",
                            en: "The system launch-at-login switch is unavailable on macOS 12, but the Finder features continue to work normally."
                        )
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Toggle(AssistantLocalized.text(zh: "在顶部菜单栏显示图标", en: "Show icon in the top menu bar"), isOn: $showMenuBarExtra)
                    .toggleStyle(.checkbox)

                Toggle(AssistantLocalized.text(zh: "在底部菜单栏显示图标", en: "Show app in the Dock"), isOn: $showInDock)
                    .toggleStyle(.checkbox)
                    .onChange(of: showInDock) { newValue in
                        applyActivationPolicy(newValue)
                    }
            }
        }
    }

    private var languagePanel: some View {
        GeneralSectionCard(
            title: AssistantLocalized.text(zh: "语言", en: "Language"),
            detail: AssistantLocalized.text(
                zh: "默认跟随系统语言，也可以手动切换为简体中文或 English。",
                en: "Follow the system language by default, or switch manually to Simplified Chinese or English."
            )
        ) {
            Picker("", selection: $appLanguage) {
                ForEach(AssistantLanguageOption.allCases) { option in
                    Text(option.title).tag(option.rawValue)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
        }
    }

    private var authorizationPanel: some View {
        GeneralSectionCard(
            title: AssistantLocalized.text(zh: "授权目录", en: "Authorized Folders"),
            detail: AssistantLocalized.text(
                zh: "添加需要使用右键工具的目录。目录权限由 macOS 文件选择器授予。",
                en: "Add the folders you want to use with right-click tools. Folder access is granted by the macOS file picker."
            )
        ) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 12) {
                    Text(authorizationSummaryText)
                        .font(.headline)

                    Spacer(minLength: 0)

                    Button {
                        chooseAuthorizedDirectory()
                    } label: {
                        Label(AssistantLocalized.text(zh: "添加目录", en: "Add Folder"), systemImage: "folder.badge.plus")
                    }
                }

                if store.dirs.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(AssistantLocalized.text(zh: "还没有授权目录", en: "No Authorized Folders Yet"))
                            .font(.headline)
                        Text(
                            AssistantLocalized.text(
                                zh: "添加目录后，Finder 扩展才能在这些位置执行右键相关操作。",
                                en: "Add folders to allow the Finder extension to perform context menu actions there."
                            )
                        )
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Color(NSColor.windowBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(store.dirs) { item in
                            AuthorizedFolderRow(item: item) {
                                removeAuthorizedDirectory(item)
                            }
                        }
                    }
                }
            }
        }
    }

    private var authorizationSummaryText: String {
        return AssistantLocalized.text(
            zh: "当前已授权 \(store.dirs.count) 个目录",
            en: "\(store.dirs.count) authorized folders"
        )
    }

    private func syncExtensionState() {
        let finderSyncAPIEnabled = FIFinderSyncController.isExtensionEnabled
        let registrationInspection = AssistantFinderExtensionStateInspector
            .inspectCurrentAppEmbeddedExtensionRegistration()
        let pluginkitEnabled = registrationInspection.pluginkitEnabled
        let currentEmbeddedExtensionRegistered = registrationInspection.currentBuildRegistered
        let extensionProcessRunning = AssistantFinderExtensionStateInspector.isCurrentAppEmbeddedExtensionRunning()
        let extensionLaunchedRecently = AssistantFinderExtensionStateInspector.hasRecentLaunchHeartbeat()
        let hasUnexpectedRegistrations = registrationInspection.hasUnexpectedRegistrations
        let runtimeConfirmed = extensionProcessRunning || (finderSyncAPIEnabled && extensionLaunchedRecently)
        let pluginkitStatus = registrationInspection.pluginkitQuerySucceeded
            ? String(pluginkitEnabled)
            : "unavailable"
        let registrationStatus = registrationInspection.pluginkitQuerySucceeded
            ? String(currentEmbeddedExtensionRegistered)
            : "unavailable"
        let unexpectedRegistrationStatus = registrationInspection.pluginkitQuerySucceeded
            ? String(hasUnexpectedRegistrations)
            : "unavailable"

        logger.debug(
            "Extension status refreshed. FinderSync API: \(finderSyncAPIEnabled), pluginkit: \(pluginkitStatus), registered current build: \(registrationStatus), process running: \(extensionProcessRunning), recent launch: \(extensionLaunchedRecently), runtime confirmed: \(runtimeConfirmed), unexpected registrations: \(unexpectedRegistrationStatus)"
        )

        extensionEnabled = runtimeConfirmed
            || finderSyncAPIEnabled
            || (
                registrationInspection.pluginkitQuerySucceeded
                    && currentEmbeddedExtensionRegistered
                    && !hasUnexpectedRegistrations
                    && (pluginkitEnabled || extensionLaunchedRecently)
            )
    }

    private func beginExtensionStatusRefreshCycle() {
        extensionStatusRefreshTask?.cancel()
        extensionStatusRefreshTask = Task { @MainActor in
            syncExtensionState()

            for _ in 0..<9 {
                try? await Task.sleep(nanoseconds: 500_000_000)
                guard !Task.isCancelled else { return }
                syncExtensionState()
            }
        }
    }

    @MainActor
    private func chooseAuthorizedDirectory() {
        let panelDelegate = AuthorizedFolderOpenPanelDelegate()
        let panel = NSOpenPanel()
        panel.delegate = panelDelegate
        panel.title = AssistantLocalized.text(zh: "添加授权目录", en: "Add Authorized Folder")
        panel.message = AssistantLocalized.text(
            zh: "请选择当前用户可访问的文件夹，可选择启动盘根目录。系统保护位置仍不能作为授权目录。",
            en: "Choose a folder accessible by the current user. The startup disk root is allowed, but protected system locations are still blocked."
        )
        panel.prompt = AssistantLocalized.text(zh: "添加", en: "Add")
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.treatsFilePackagesAsDirectories = false
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser

        guard panel.runModal() == .OK, let directoryURL = panel.url else {
            return
        }

        addAuthorizedDirectory(directoryURL)
    }

    @MainActor
    private func addAuthorizedDirectory(_ directoryURL: URL) {
        let standardizedURL = directoryURL.standardizedFileURL.resolvingSymlinksInPath()

        guard AuthorizedFolderSelectionPolicy.isAllowed(standardizedURL) else {
            logger.info("Blocked protected authorized directory: \(standardizedURL.path)")
            authorizedDirectoryImportErrorMessage = AssistantLocalized.text(
                zh: "不能将系统目录或其他系统保护位置添加为授权目录。请选择启动盘根目录、桌面、文稿、下载或其他当前用户可访问的文件夹。",
                en: "System folders and other protected system locations cannot be added as authorized folders. Choose the startup disk root, Desktop, Documents, Downloads, or another folder accessible by the current user."
            )
            return
        }

        guard !store.hasParentBookmark(of: directoryURL) else {
            isShowingNestedDirectoryAlert = true
            logger.info("Blocked nested authorized directory: \(standardizedURL.path)")
            return
        }

        let directory: AuthorizedDirectory
        do {
            directory = try AuthorizedDirectory(permUrl: standardizedURL)
        } catch {
            logger.error("Failed to create authorized directory bookmark: \(error.localizedDescription)")
            authorizedDirectoryImportErrorMessage = AssistantLocalized.text(
                zh: "无法为这个目录生成授权信息，请重新选择目录，或检查系统文件访问权限后再试。",
                en: "The app could not create authorization data for this folder. Choose the folder again or check file access permissions, then try again."
            )
            return
        }

        store.dirs.append(directory)

        do {
            try store.savePermissiveDir()
            logger.info("Authorized directory saved to shared preferences.")
        } catch {
            logger.error("Failed to persist authorized directory: \(error.localizedDescription)")
            store.dirs.removeAll { $0.id == directory.id }
            authorizedDirectoryImportErrorMessage = AssistantLocalized.text(
                zh: "目录授权信息保存失败，请稍后重试。",
                en: "Failed to save the folder authorization. Please try again."
            )
            return
        }
        broadcastObservedDirectories()
    }

    @MainActor
    private func removeAuthorizedDirectory(_ item: AuthorizedDirectory) {
        guard let index = store.dirs.firstIndex(of: item) else { return }

        store.deletePermissiveDir(index: index)
        broadcastObservedDirectories()
    }

    private func broadcastObservedDirectories() {
        messager.sendMessage(
            name: "running",
            data: ExtensionMessagePayload(action: "running", target: observedDirectoryPaths)
        )
    }

    private func applyActivationPolicy(_ showInDock: Bool) {
        NSApp.setActivationPolicy(showInDock ? .regular : .accessory)
    }

    private func openExtensionManagement() {
        if AssistantBuildRuntime.shouldRepairFinderExtensionRegistration {
            RCAAppDelegate.shared?.repairFinderExtensionForLocalBuildIfNeeded(force: true)
        }

        FIFinderSyncController.showExtensionManagementInterface()
        beginExtensionStatusRefreshCycle()
    }
}
