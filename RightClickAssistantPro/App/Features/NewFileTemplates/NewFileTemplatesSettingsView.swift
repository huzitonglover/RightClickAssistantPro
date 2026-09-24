//
//  NewFileTemplatesSettingsView.swift
//  RightClickAssistantPro
//
//  Created by 老谭 on 2026/4/29.
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct NewFileTemplatesSettingsView: View {
    @AssistantLogger(category: "NewFileTemplatesSettingsView")
    private var logger

    @EnvironmentObject private var appState: AssistantRuntimeState
    @AppStorage(SharedPreferenceKey.showNewFileTemplateImages, store: .group)
    private var showTemplateImages = true
    @AppStorage(SharedPreferenceKey.newFileCreationSoundEnabled, store: .group)
    private var creationSoundEnabled = true
    @AppStorage(SharedPreferenceKey.openNewFileAfterCreation, store: .group)
    private var openFileAfterCreation = false

    @State private var selectedTemplateID: NewFileTemplate.ID?
    @State private var draggedTemplateID: NewFileTemplate.ID?

    private let messager = ExtensionMessageBus.shared
    private let columns: [GridItem] = [
        GridItem(.fixed(72), spacing: 0, alignment: .leading),
        GridItem(.fixed(92), spacing: 0, alignment: .leading),
        GridItem(.flexible(minimum: 220), spacing: 0, alignment: .leading),
        GridItem(.fixed(120), spacing: 0, alignment: .leading)
    ]

    private var canRemoveSelectedTemplate: Bool {
        guard let selectedTemplateID,
              let item = appState.newFiles.first(where: { $0.id == selectedTemplateID }) else {
            return false
        }

        return !item.id.hasPrefix("builtin-newfile-")
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
                tableHeader(AssistantLocalized.text(zh: "显示名称（双击编辑/按住拖拽）", en: "Display Name (double-click to edit / drag)"))
                tableHeader(AssistantLocalized.text(zh: "后缀", en: "Suffix"))
            }
            .padding(.horizontal, 12)
            .frame(height: 42)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach($appState.newFiles) { $item in
                        NewFileTemplateRow(
                            item: $item,
                            columns: columns,
                            showIconImage: showTemplateImages,
                            isSelected: selectedTemplateID == item.id,
                            onSelect: {
                                selectedTemplateID = item.id
                            },
                            onChanged: persistChanges,
                            onDelete: {
                                removeTemplate(id: item.id)
                            }
                        )
                        .onDrag {
                            selectedTemplateID = item.id
                            draggedTemplateID = item.id
                            return NSItemProvider(object: item.id as NSString)
                        }
                        .onDrop(
                            of: [UTType.text],
                            delegate: NewFileTemplateDropDelegate(
                                destinationID: item.id,
                                items: $appState.newFiles,
                                draggedTemplateID: $draggedTemplateID,
                                onChanged: persistChanges
                            )
                        )
                        Divider()
                    }
                }
            }
        }
        .frame(minHeight: 300, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.secondary.opacity(0.22), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 10) {
                Button(AssistantLocalized.text(zh: "添加模版文件", en: "Add Template File")) {
                    importTemplateFile()
                }

                Button {
                    removeSelectedTemplate()
                } label: {
                    Text("-")
                        .frame(width: 18, height: 18)
                }
                .disabled(!canRemoveSelectedTemplate)
                .help(AssistantLocalized.text(zh: "删除选中的自定义模版", en: "Remove selected custom template"))

                Spacer(minLength: 0)

                Link(
                    AssistantLocalized.text(zh: "右键菜单失效的解决办法 >>", en: "Fix context menu issues >>"),
                    destination: URL(string: "x-apple.systempreferences:com.apple.ExtensionsPreferences")!
                )
                .font(.body.weight(.semibold))

                Button(AssistantLocalized.text(zh: "重置", en: "Reset")) {
                    appState.resetFiletypeItems()
                    selectedTemplateID = nil
                    draggedTemplateID = nil
                    notifyExtension()
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 28) {
                    Toggle(AssistantLocalized.text(zh: "显示图标", en: "Show Icons"), isOn: $showTemplateImages)
                        .toggleStyle(.checkbox)
                        .onChange(of: showTemplateImages) { _ in notifyExtension() }

                    Toggle(AssistantLocalized.text(zh: "开启提示音", en: "Play Sound"), isOn: $creationSoundEnabled)
                        .toggleStyle(.checkbox)

                    Spacer(minLength: 0)
                }

                Toggle(AssistantLocalized.text(zh: "新建文件后自动打开", en: "Open New File After Creation"), isOn: $openFileAfterCreation)
                    .toggleStyle(.checkbox)
            }
        }
    }

    private func tableHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(.primary)
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func importTemplateFile() {
        let panel = NSOpenPanel()
        panel.title = AssistantLocalized.text(zh: "选择模版文件", en: "Choose Template File")
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.content]

        guard panel.runModal() == .OK,
              let sourceURL = panel.url else {
            return
        }

        let normalizedExtension = "." + sourceURL.pathExtension.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard normalizedExtension.count > 1 else {
            showTemplateImportFailedAlert()
            return
        }

        let nextIndex = appState.newFiles.count
        let itemID = UUID().uuidString
        var template = NewFileTemplate(
            ext: normalizedExtension,
            name: sourceURL.deletingPathExtension().lastPathComponent,
            idx: nextIndex,
            icon: "doc",
            id: itemID
        )
        template.template = TemplateLibrary.storeCopy(
            source: sourceURL,
            keeping: nil,
            logger: logger
        )

        appState.addNewFile(template)
        selectedTemplateID = template.id
        notifyExtension()
    }

    private func removeSelectedTemplate() {
        guard let selectedTemplateID else {
            return
        }

        removeTemplate(id: selectedTemplateID)
    }

    private func removeTemplate(id: String) {
        guard let index = appState.newFiles.firstIndex(where: { $0.id == id }),
              !appState.newFiles[index].id.hasPrefix("builtin-newfile-") else {
            return
        }

        if let templateURL = appState.newFiles[index].template {
            TemplateLibrary.removeManagedCopy(at: templateURL, logger: logger)
        }

        appState.deleteNewFileTemplate(id: id)
        if selectedTemplateID == id {
            selectedTemplateID = nil
        }
        notifyExtension()
    }

    private func persistChanges() {
        appState.sync()
        notifyExtension()
    }

    private func notifyExtension() {
        messager.sendMessage(
            name: "running",
            data: ExtensionMessagePayload(action: "running", target: [])
        )
    }

    private func showTemplateImportFailedAlert() {
        let alert = NSAlert()
        alert.messageText = AssistantLocalized.text(zh: "导入模版失败", en: "Template Import Failed")
        alert.informativeText = AssistantLocalized.text(
            zh: "请选择带有文件后缀的模版文件。",
            en: "Choose a template file with a filename extension."
        )
        alert.alertStyle = .warning
        alert.addButton(withTitle: AssistantLocalized.text(zh: "确定", en: "OK"))
        alert.runModal()
    }

}

private struct NewFileTemplateDropDelegate: DropDelegate {
    let destinationID: NewFileTemplate.ID
    @Binding var items: [NewFileTemplate]
    @Binding var draggedTemplateID: NewFileTemplate.ID?
    let onChanged: () -> Void

    func dropEntered(info: DropInfo) {
        guard let draggedTemplateID,
              draggedTemplateID != destinationID,
              let fromIndex = items.firstIndex(where: { $0.id == draggedTemplateID }),
              let toIndex = items.firstIndex(where: { $0.id == destinationID }) else {
            return
        }

        withAnimation(.easeInOut(duration: 0.12)) {
            items.move(
                fromOffsets: IndexSet(integer: fromIndex),
                toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex
            )
            reindexItems()
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedTemplateID = nil
        reindexItems()
        onChanged()
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    private func reindexItems() {
        for index in items.indices {
            items[index].idx = index
        }
    }
}
