//
//  AssistantSettingsTab.swift
//  RightClickAssistantPro
//
//  Created by 老谭 on 2026/4/29.
//

import AppKit
import UniformTypeIdentifiers
import SwiftUI

enum AssistantSettingsTab: CaseIterable, Identifiable {
    case general
    case featureCenter
    case apps
    case actions
    case newFile
    case folderIcons
    case cdirs
    case tutorial
    case about
    case contact

    var id: String { storageKey }

    var storageKey: String {
        switch self {
        case .general: "general"
        case .featureCenter: "feature-center"
        case .apps: "apps"
        case .actions: "actions"
        case .newFile: "new-file"
        case .folderIcons: "folder-icons"
        case .cdirs: "favorite-folders"
        case .tutorial: "tutorial"
        case .about: "about"
        case .contact: "contact"
        }
    }

    var title: String {
        switch self {
        case .general:
            AssistantLocalized.text(zh: "通用", en: "General")
        case .featureCenter:
            AssistantLocalized.text(zh: "功能中心", en: "Feature Center")
        case .apps:
            AssistantLocalized.text(zh: "打开方式", en: "Open With")
        case .actions:
            AssistantLocalized.text(zh: "工具箱", en: "Toolbox")
        case .newFile:
            AssistantLocalized.text(zh: "新建文件", en: "New File")
        case .folderIcons:
            AssistantLocalized.text(zh: "文件(夹)图标", en: "File/Folder Icons")
        case .cdirs:
            AssistantLocalized.text(zh: "常用目录", en: "Favorite Folders")
        case .tutorial:
            AssistantLocalized.text(zh: "使用教程", en: "Tutorial")
        case .about:
            AssistantLocalized.text(zh: "关于", en: "About")
        case .contact:
            AssistantLocalized.text(zh: "联系我们", en: "Contact")
        }
    }

    var summary: String {
        switch self {
        case .general:
            AssistantLocalized.text(zh: "扩展开关、开机启动、语言和授权目录。", en: "Extension, launch, language, and authorized folders.")
        case .featureCenter:
            AssistantLocalized.text(zh: "打开内置独立功能模块。", en: "Open built-in standalone feature modules.")
        case .apps:
            AssistantLocalized.text(zh: "管理右键打开方式和应用参数。", en: "Manage open-with apps and launch parameters.")
        case .actions:
            AssistantLocalized.text(
                zh: "控制菜单栏显示项,拖动可调整右键菜单顺序。",
                en: "Control visible menu items and drag to reorder the context menu."
            )
        case .newFile:
            AssistantLocalized.text(zh: "维护可创建的新文件模板和默认应用。", en: "Manage new-file templates and default apps.")
        case .folderIcons:
            AssistantLocalized.text(zh: "管理右键菜单里的文件夹图标样式。", en: "Manage folder icon styles shown in the context menu.")
        case .cdirs:
            AssistantLocalized.text(zh: "维护常用目录的快捷入口。", en: "Manage favorite folders in the context menu.")
        case .tutorial:
            AssistantLocalized.text(zh: "查看快速上手说明和操作演示链接。", en: "Read the quick guide and open the walkthrough video.")
        case .about:
            AssistantLocalized.text(zh: "了解右键工具Pro的产品介绍。", en: "Learn about RightMenuPro.")
        case .contact:
            AssistantLocalized.text(zh: "查看 QQ 群联系方式。", en: "View the QQ group contact.")
        }
    }

    var icon: String {
        switch self {
        case .general: "slider.horizontal.2.square"
        case .featureCenter: "square.grid.3x3"
        case .apps: "square.grid.2x2"
        case .actions: "sparkles"
        case .newFile: "doc.badge.plus"
        case .folderIcons: "folder"
        case .cdirs: "folder.badge.gearshape"
        case .tutorial: "play.rectangle"
        case .about: "info.circle"
        case .contact: "person.crop.square"
        }
    }

    var accent: Color {
        switch self {
        case .general:
            .blue
        case .featureCenter:
            .indigo
        case .apps:
            .orange
        case .actions:
            .purple
        case .newFile:
            .green
        case .folderIcons:
            .orange
        case .cdirs:
            .teal
        case .tutorial:
            .indigo
        case .about:
            .secondary
        case .contact:
            .mint
        }
    }

    @ViewBuilder
    func makeContentView() -> some View {
        switch self {
        case .general:
            AssistantGeneralSettingsView()
        case .featureCenter:
            FeatureCenterSettingsView()
        case .apps:
            OpenWithAppsSettingsView()
        case .actions:
            QuickActionsSettingsView()
        case .newFile:
            NewFileTemplatesSettingsView()
        case .folderIcons:
            FolderIconTemplatesSettingsView()
        case .cdirs:
            FavoriteFoldersSettingsView()
        case .tutorial:
            AssistantTutorialSettingsView()
        case .about:
            AssistantAboutSettingsView()
        case .contact:
            ContactSettingsTabView()
        }
    }
}

private struct AssistantTutorialSettingsView: View {
    private let tutorialVideoURL = URL(string: "https://pan.baidu.com/s/1Cfb7BuUeNnQErwo4yXskTg?pwd=4i6i")

    
    private var setupTitle: String {
        AssistantLocalized.text(zh: "开始使用前完成 2 步", en: "Complete These 2 Steps First")
    }

    private var setupSubtitle: String {
        AssistantLocalized.text(
            zh: "先打开 Finder 扩展，再授权需要使用的目录。完成后回到 Finder 右键文件或文件夹，即可使用右键工具菜单。",
            en: "Enable the Finder extension first, then authorize the folders you want to use. After that, return to Finder and right-click a file or folder to use the assistant menu."
        )
    }

    private var openExtensionTitle: String {
        AssistantLocalized.text(zh: "打开扩展设置", en: "Open Extension Settings")
    }

    private var openExtensionText: String {
        AssistantLocalized.text(
            zh: "在“通用”页面点击“打开扩展设置”，进入系统设置后启用“右键工具Pro”Finder 扩展。若开关已经开启，可直接进行下一步。",
            en: "In General, click Open Extension Settings, then enable the RightMenuPro Finder extension in System Settings. If it is already enabled, continue to the next step."
        )
    }

    private var authorizeDirectoryTitle: String {
        AssistantLocalized.text(zh: "授权使用目录", en: "Authorize Folders")
    }

    private var authorizeDirectoryText: String {
        AssistantLocalized.text(
            zh: "回到“通用”页面，在“授权目录”中添加需要操作的文件夹。未允许访问的目录无法读取文件，也无法执行新建、打开方式、工具箱等右键功能。",
            en: "Return to General and add the folders you want to use under Authorized Folders. Folders without allowed access cannot be read or used for New File, Open With, Toolbox, and other right-click actions."
        )
    }

    private var videoTitle: String {
        AssistantLocalized.text(zh: "操作演示视频", en: "Walkthrough Video")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                setupStepsPanel
                videoPanel
            }
            .frame(maxWidth: 860, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
        }
    }

    private var setupStepsPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            setupHeader

            VStack(alignment: .leading, spacing: 14) {
                tutorialStepCard(
                    number: "1",
                    title: openExtensionTitle,
                    text: openExtensionText,
                    iconName: "puzzlepiece.extension",
                    tint: .blue,
                    background: Color.blue.opacity(0.075)
                )

                tutorialStepCard(
                    number: "2",
                    title: authorizeDirectoryTitle,
                    text: authorizeDirectoryText,
                    iconName: "folder.badge.gearshape",
                    tint: .green,
                    background: Color.green.opacity(0.075)
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var setupHeader: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.accentColor.opacity(0.12))
                    .frame(width: 44, height: 44)

                Image(systemName: "checklist")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            }

            VStack(alignment: .leading, spacing: 7) {
                Text(setupTitle)
                    .font(.title2.weight(.semibold))

                Text(setupSubtitle)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func tutorialStepCard(
        number: String,
        title: String,
        text: String,
        iconName: String,
        tint: Color,
        background: Color
    ) -> some View {
        HStack(alignment: .top, spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(tint.opacity(0.16))
                    .frame(width: 54, height: 54)

                Image(systemName: iconName)
                    .font(.system(size: 23, weight: .semibold))
                    .foregroundStyle(tint)
            }

            VStack(alignment: .leading, spacing: 9) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(title)
                        .font(.headline.weight(.semibold))

                    Text(number)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(tint)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(tint.opacity(0.13))
                        .clipShape(Capsule())
                }

                Text(text)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(background)
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(tint.opacity(0.22), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @ViewBuilder
    private var videoPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(videoTitle)
                .font(.title3.weight(.semibold))

            VStack(alignment: .center, spacing: 18) {
                Button {
                    openTutorialVideo()
                } label: {
                    Image(systemName: "play.rectangle.fill")
                        .font(.system(size: 46, weight: .semibold))
                        .foregroundStyle(.indigo)
                        .frame(width: 72, height: 58)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button {
                    openTutorialVideo()
                } label: {
                    Label(
                        AssistantLocalized.text(zh: "打开教程视频", en: "Open Tutorial Video"),
                        systemImage: "arrow.up.right.square"
                    )
                }
                .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 260)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private func openTutorialVideo() {
        guard let tutorialVideoURL else { return }
        NSWorkspace.shared.open(tutorialVideoURL)
    }
}

private struct FolderIconTemplatesSettingsView: View {
    @EnvironmentObject private var appState: AssistantRuntimeState
    @AppStorage(SharedPreferenceKey.showFolderIconImages, store: .group)
    private var showFolderIconImages = true
    @State private var selectedIconID: FolderIconTemplate.ID?

    private let messager = ExtensionMessageBus.shared
    private let columns: [GridItem] = [
        GridItem(.fixed(84), spacing: 0, alignment: .leading),
        GridItem(.fixed(96), spacing: 0, alignment: .leading),
        GridItem(.fixed(132), spacing: 0, alignment: .leading),
        GridItem(.flexible(minimum: 220), spacing: 0, alignment: .leading)
    ]

    private var enabledCount: Int {
        appState.folderIcons.filter(\.enabled).count
    }

    private var canRemoveSelectedIcon: Bool {
        guard let selectedIconID,
              let item = appState.folderIcons.first(where: { $0.id == selectedIconID }) else {
            return false
        }

        return !item.isBuiltIn
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            table
            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var table: some View {
        VStack(spacing: 0) {
            LazyVGrid(columns: columns, spacing: 0) {
                tableHeader(AssistantLocalized.text(zh: "启用", en: "Enabled"))
                tableHeader(AssistantLocalized.text(zh: "图标", en: "Icon"))
                tableHeader(AssistantLocalized.text(zh: "尺寸", en: "Size"))
                tableHeader(AssistantLocalized.text(zh: "显示名称", en: "Display Name"))
            }
            .padding(.horizontal, 12)
            .frame(height: 42)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach($appState.folderIcons) { $item in
                        FolderIconTemplateRow(
                            item: $item,
                            columns: columns,
                            showIconImage: showFolderIconImages,
                            isSelected: selectedIconID == item.id,
                            onSelect: {
                                selectedIconID = item.id
                            },
                            onChanged: persistChanges,
                            onDelete: {
                                let iconID = item.id
                                removeCustomIcon(id: iconID)
                            }
                        )
                        Divider()
                    }
                }
            }
        }
        .frame(minHeight: 420)
        .background(Color(NSColor.windowBackgroundColor))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.secondary.opacity(0.22), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 12) {
                addRemoveButtons

                Text(AssistantLocalized.text(zh: "自定义图标尺寸建议小于 128 x 128 (dpi = 72)", en: "Custom icon size should be under 128 x 128 (dpi = 72)."))
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 0)

                Button(AssistantLocalized.text(zh: "重置", en: "Reset")) {
                    appState.resetFolderIconItems()
                    selectedIconID = nil
                    notifyExtension()
                }
            }

            HStack(alignment: .center, spacing: 12) {
                Toggle(AssistantLocalized.text(zh: "显示图标", en: "Show Icons"), isOn: $showFolderIconImages)
                    .toggleStyle(.checkbox)
                    .onChange(of: showFolderIconImages) { _ in
                        notifyExtension()
                    }
            }
        }
    }

    private var addRemoveButtons: some View {
        HStack(spacing: 8) {
            Button {
                importCustomIcon()
            } label: {
                Image(systemName: "plus")
                    .frame(width: 18, height: 18)
            }
            .help(AssistantLocalized.text(zh: "添加自定义图标", en: "Add Custom Icon"))

            Button {
                removeSelectedCustomIcon()
            } label: {
                Image(systemName: "minus")
                    .frame(width: 18, height: 18)
            }
            .disabled(!canRemoveSelectedIcon)
            .help(AssistantLocalized.text(zh: "删除选中的自定义图标", en: "Remove Selected Custom Icon"))
        }
    }

    private func tableHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func importCustomIcon() {
        let panel = NSOpenPanel()
        panel.title = AssistantLocalized.text(zh: "选择文件夹图标", en: "Choose Folder Icon")
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.png, .icns, .jpeg, .tiff]

        guard panel.runModal() == .OK,
              let url = panel.url,
              let image = NSImage(contentsOf: url) else {
            return
        }

        let maxPixelSize = max(Int(image.size.width), Int(image.size.height))
        let itemID = UUID().uuidString
        guard let storedURL = storeCustomIconImage(from: url, id: itemID) else {
            return
        }

        let nextIndex = appState.folderIcons.count
        let item = FolderIconTemplate(
            id: itemID,
            name: url.deletingPathExtension().lastPathComponent,
            assetName: "",
            imagePath: storedURL.path,
            pixelSize: maxPixelSize,
            idx: nextIndex,
            isBuiltIn: false
        )
        appState.folderIcons.append(item)
        selectedIconID = item.id
        persistChanges()
    }

    private func storeCustomIconImage(from sourceURL: URL, id: String) -> URL? {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: Constants.appGroupIdentifier
        ) else {
            showImportFailedAlert()
            return nil
        }

        let directoryURL = containerURL
            .appendingPathComponent("FolderIcons", isDirectory: true)
        let fileExtension = sourceURL.pathExtension.isEmpty ? "png" : sourceURL.pathExtension
        let targetURL = directoryURL
            .appendingPathComponent(id)
            .appendingPathExtension(fileExtension)

        do {
            try FileManager.default.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true
            )
            if FileManager.default.fileExists(atPath: targetURL.path) {
                try FileManager.default.removeItem(at: targetURL)
            }
            try FileManager.default.copyItem(at: sourceURL, to: targetURL)
            return targetURL
        } catch {
            showImportFailedAlert()
            return nil
        }
    }

    private func showImportFailedAlert() {
        let alert = NSAlert()
        alert.messageText = AssistantLocalized.text(zh: "导入图标失败", en: "Icon Import Failed")
        alert.informativeText = AssistantLocalized.text(
            zh: "无法把图标保存到共享目录，请换一个 PNG、ICNS、JPG 或 TIFF 文件后再试。",
            en: "The icon could not be saved to the shared folder. Try another PNG, ICNS, JPG, or TIFF file."
        )
        alert.alertStyle = .warning
        alert.addButton(withTitle: AssistantLocalized.text(zh: "确定", en: "OK"))
        alert.runModal()
    }

    private func removeSelectedCustomIcon() {
        guard let selectedIconID else {
            return
        }

        removeCustomIcon(id: selectedIconID)
    }

    private func removeCustomIcon(id: String) {
        guard let item = appState.folderIcons.first(where: { $0.id == id }),
              !item.isBuiltIn else {
            return
        }

        if let imagePath = item.imagePath {
            try? FileManager.default.removeItem(atPath: imagePath)
        }

        if selectedIconID == id {
            selectedIconID = nil
        }
        appState.deleteFolderIconItem(id: id)
        notifyExtension()
    }

    private func persistChanges() {
        appState.saveFolderIconItems()
        notifyExtension()
    }

    private func notifyExtension() {
        messager.sendMessage(
            name: "running",
            data: ExtensionMessagePayload(action: "running", target: [])
        )
    }
}

private struct FolderIconTemplateRow: View {
    @Binding var item: FolderIconTemplate
    @State private var isEditingName = false
    @FocusState private var isNameFieldFocused: Bool

    let columns: [GridItem]
    let showIconImage: Bool
    let isSelected: Bool
    let onSelect: () -> Void
    let onChanged: () -> Void
    let onDelete: () -> Void

    var body: some View {
        ZStack {
            Rectangle()
                .fill(isSelected ? Color.accentColor.opacity(0.18) : Color.clear)

            LazyVGrid(columns: columns, spacing: 0) {
                Toggle("", isOn: $item.enabled)
                    .labelsHidden()
                    .toggleStyle(.checkbox)
                    .onChange(of: item.enabled) { _ in onChanged() }

                FolderIconTemplatePreview(item: item, showIconImage: showIconImage)

                Text(item.sizeText)
                    .font(.body.monospacedDigit())
                    .foregroundStyle(.primary)

                HStack(spacing: 8) {
                    nameEditor

                    if !item.isBuiltIn {
                        Button(role: .destructive, action: onDelete) {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                        .help(AssistantLocalized.text(zh: "删除", en: "Delete"))
                    }
                }
            }
            .padding(.horizontal, 12)
        }
        .frame(height: 56)
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
    }

    @ViewBuilder
    private var nameEditor: some View {
        if isEditingName {
            TextField("", text: $item.name)
                .textFieldStyle(.roundedBorder)
                .focused($isNameFieldFocused)
                .onSubmit(finishNameEditing)
                .onChange(of: item.name) { _ in onChanged() }
                .onChange(of: isNameFieldFocused) { focused in
                    if !focused {
                        finishNameEditing()
                    }
                }
                .onAppear {
                    isNameFieldFocused = true
                }
        } else {
            Text(item.displayName)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture {
                    onSelect()
                    beginNameEditing()
                }
        }
    }

    private func beginNameEditing() {
        isEditingName = true
    }

    private func finishNameEditing() {
        guard isEditingName else { return }
        let trimmedName = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty {
            item.name = AssistantLocalized.text(zh: "未命名图标", en: "Untitled Icon")
        } else if trimmedName != item.name {
            item.name = trimmedName
        }
        isEditingName = false
        onChanged()
    }
}

private struct FolderIconTemplatePreview: View {
    let item: FolderIconTemplate
    let showIconImage: Bool

    var body: some View {
        Group {
            if showIconImage {
                templateImage
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "folder")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 34, height: 34)
    }

    private var templateImage: Image {
        if let imagePath = item.imagePath,
           let nsImage = NSImage(contentsOfFile: imagePath) {
            return Image(nsImage: nsImage)
        }

        return Image(item.assetName)
    }
}
