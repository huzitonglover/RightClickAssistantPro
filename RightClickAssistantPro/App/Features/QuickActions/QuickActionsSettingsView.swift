//
//  QuickActionsSettingsView.swift
//  RightClickAssistantPro
//
//  Created by 老谭 on 2026/4/29.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct QuickActionsSettingsView: View {
    @EnvironmentObject private var appState: AssistantRuntimeState
    @AppStorage(SharedPreferenceKey.showOpenWithMenuGroup, store: .group)
    private var showOpenWithMenuGroup = true
    @AppStorage(SharedPreferenceKey.showNewFileMenuGroup, store: .group)
    private var showNewFileMenuGroup = true
    @AppStorage(SharedPreferenceKey.showFolderIconMenuGroup, store: .group)
    private var showFolderIconMenuGroup = true
    @AppStorage(SharedPreferenceKey.showFavoriteFoldersMenuGroup, store: .group)
    private var showFavoriteFoldersMenuGroup = true
    @AppStorage(SharedPreferenceKey.showCopyPathMenuGroup, store: .group)
    private var showCopyPathMenuGroup = true

    @State private var selectedItemID: String?
    @State private var orderedRows = ToolboxSettingsRow.loadOrder()
    @State private var draggedRowID: ToolboxSettingsRow.ID?

    private let messager = ExtensionMessageBus.shared
    private let columns: [GridItem] = [
        GridItem(.fixed(34), spacing: 0, alignment: .leading),
        GridItem(.fixed(72), spacing: 0, alignment: .leading),
        GridItem(.fixed(82), spacing: 0, alignment: .leading),
        GridItem(.flexible(minimum: 220), spacing: 0, alignment: .leading),
        GridItem(.fixed(128), spacing: 0, alignment: .leading)
    ]

    private var summary: QuickActionSummary {
        QuickActionSummary(enabledCount: enabledRowCount, totalCount: visibleRows.count)
    }

    private var visibleRows: [ToolboxSettingsRow] {
        orderedRows.filter { row in
            switch row {
            case .menuGroup:
                return true
            case .quickAction(let identifier):
                return action(for: identifier)?.isAvailableOnCurrentSystem == true
            }
        }
    }

    private var enabledRowCount: Int {
        visibleRows.reduce(0) { count, row in
            isEnabled(row) ? count + 1 : count
        }
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
                tableHeader("")
                tableHeader(AssistantLocalized.text(zh: "启用", en: "Enabled"))
                tableHeader(AssistantLocalized.text(zh: "图标", en: "Icon"))
                tableHeader(AssistantLocalized.text(zh: "功能名称", en: "Action Name"))
                tableHeader(AssistantLocalized.text(zh: "菜单状态", en: "Menu Status"))
            }
            .padding(.horizontal, 12)
            .frame(height: 42)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(visibleRows) { row in
                        switch row {
                        case .menuGroup(let group):
                            ToolboxMenuGroupTableRow(
                                group: group,
                                isEnabled: menuGroupBinding(for: group),
                                columns: columns,
                                isSelected: selectedItemID == row.id,
                                onSelect: {
                                    selectedItemID = row.id
                                },
                                onToggle: notifyExtension
                            )
                            .onDrag {
                                draggedRowID = row.id
                                return NSItemProvider(object: row.id as NSString)
                            }
                            .onDrop(
                                of: [UTType.text],
                                delegate: ToolboxSettingsRowDropDelegate(
                                    destinationID: row.id,
                                    rows: $orderedRows,
                                    draggedRowID: $draggedRowID,
                                    onChanged: persistOrder
                                )
                            )

                            Divider()

                        case .quickAction(let identifier):
                            if let item = actionBinding(for: identifier) {
                                QuickActionTableRow(
                                    item: item,
                                    columns: columns,
                                    isSelected: selectedItemID == row.id,
                                    onSelect: {
                                        selectedItemID = row.id
                                    },
                                    onToggle: {
                                        appState.toggleActionItem()
                                        notifyExtension()
                                    }
                                )
                                .onDrag {
                                    draggedRowID = row.id
                                    return NSItemProvider(object: row.id as NSString)
                                }
                                .onDrop(
                                    of: [UTType.text],
                                    delegate: ToolboxSettingsRowDropDelegate(
                                        destinationID: row.id,
                                        rows: $orderedRows,
                                        draggedRowID: $draggedRowID,
                                        onChanged: persistOrder
                                    )
                                )

                                Divider()
                            }
                        }
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
        HStack(alignment: .center, spacing: 12) {
            Text(summary.detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            Button {
                showOpenWithMenuGroup = true
                showNewFileMenuGroup = true
                showFolderIconMenuGroup = true
                showFavoriteFoldersMenuGroup = true
                showCopyPathMenuGroup = true
                ToolboxSettingsRow.resetOrder()
                orderedRows = ToolboxSettingsRow.loadOrder()
                appState.resetActionItems()
                selectedItemID = nil
                notifyExtension()
            } label: {
                Label(AssistantLocalized.text(zh: "恢复默认", en: "Reset"), systemImage: "arrow.counterclockwise")
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

    private func notifyExtension() {
        messager.sendMessage(
            name: "running",
            data: ExtensionMessagePayload(action: "running", target: [])
        )
    }

    private func persistOrder() {
        ToolboxSettingsRow.saveOrder(orderedRows)
        notifyExtension()
    }

    private func action(for identifier: String) -> ContextQuickAction? {
        appState.actions.first(where: { $0.id == identifier })
    }

    private func actionBinding(for identifier: String) -> Binding<ContextQuickAction>? {
        guard let index = appState.actions.firstIndex(where: { $0.id == identifier }) else {
            return nil
        }

        return $appState.actions[index]
    }

    private func menuGroupBinding(for group: ToolboxMenuGroup) -> Binding<Bool> {
        switch group {
        case .openWith:
            return $showOpenWithMenuGroup
        case .newFile:
            return $showNewFileMenuGroup
        case .folderIcon:
            return $showFolderIconMenuGroup
        case .favoriteFolders:
            return $showFavoriteFoldersMenuGroup
        case .copyPath:
            return $showCopyPathMenuGroup
        }
    }

    private func isEnabled(_ row: ToolboxSettingsRow) -> Bool {
        switch row {
        case .menuGroup(let group):
            return menuGroupBinding(for: group).wrappedValue
        case .quickAction(let identifier):
            return action(for: identifier)?.enabled == true
        }
    }
}
