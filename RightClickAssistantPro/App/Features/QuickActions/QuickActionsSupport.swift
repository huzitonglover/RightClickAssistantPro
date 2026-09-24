//
//  QuickActionsSupport.swift
//  RightClickAssistantPro
//
//  Created by 老谭 on 2026/4/30.
//

import AppKit
import SwiftUI

struct QuickActionSummary {
    let enabledCount: Int
    let totalCount: Int

    init(enabledCount: Int, totalCount: Int) {
        self.enabledCount = enabledCount
        self.totalCount = totalCount
    }

    init(actions: [ContextQuickAction]) {
        let counts = actions.reduce(into: (enabled: 0, total: 0)) { result, action in
            result.total += 1
            result.enabled += action.enabled ? 1 : 0
        }
        enabledCount = counts.enabled
        totalCount = counts.total
    }

    var disabledCount: Int {
        totalCount - enabledCount
    }

    var detail: String {
        AssistantLocalized.text(
            zh: "已启用 \(enabledCount) 项，已隐藏 \(disabledCount) 项。开关会立即同步到 Finder 扩展。",
            en: "\(enabledCount) enabled, \(disabledCount) hidden. Changes sync to the Finder extension immediately."
        )
    }
}

struct QuickActionControlCard: View {
    @Binding var item: ContextQuickAction
    let onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                iconBadge

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.displayName)
                        .font(.headline)
                    statusDescription
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 10) {
                Text(item.enabled ? AssistantLocalized.text(zh: "启用中", en: "Enabled") : AssistantLocalized.text(zh: "已关闭", en: "Disabled"))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(item.enabled ? .green : .secondary)
                Spacer(minLength: 0)
                Toggle("", isOn: $item.enabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .onChange(of: item.enabled) { _ in
                        onToggle()
                    }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 124, alignment: .topLeading)
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var iconBadge: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.accentColor.opacity(0.12))
            Image(systemName: item.icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.accentColor)
        }
        .frame(width: 42, height: 42)
    }

    private var statusDescription: some View {
        Text(
            item.enabled
                ? AssistantLocalized.text(zh: "当前显示在右键菜单中", en: "Currently shown in the Finder context menu")
                : AssistantLocalized.text(zh: "当前不会显示在右键菜单中", en: "Currently hidden from the Finder context menu")
        )
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}

struct QuickActionTableRow: View {
    @Binding var item: ContextQuickAction

    let columns: [GridItem]
    let isSelected: Bool
    let onSelect: () -> Void
    let onToggle: () -> Void

    var body: some View {
        ZStack {
            Rectangle()
                .fill(isSelected ? Color.accentColor.opacity(0.18) : Color.clear)

            LazyVGrid(columns: columns, spacing: 0) {
                dragHandle

                Toggle("", isOn: $item.enabled)
                    .labelsHidden()
                    .toggleStyle(.checkbox)
                    .onChange(of: item.enabled) { _ in onToggle() }

                iconPreview

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.displayName)
                        .font(.body)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Text(item.id)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text(menuStatusText)
                    .font(.body)
                    .foregroundStyle(item.enabled ? .green : .secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
        }
        .frame(height: 52)
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
    }

    private var dragHandle: some View {
        Image(systemName: "line.3.horizontal")
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(.tertiary)
            .frame(width: 20, height: 20, alignment: .center)
    }

    private var iconPreview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.accentColor.opacity(0.12))
            Image(systemName: item.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.accentColor)
        }
        .frame(width: 34, height: 34)
    }

    private var menuStatusText: String {
        item.enabled
            ? AssistantLocalized.text(zh: "显示", en: "Shown")
            : AssistantLocalized.text(zh: "隐藏", en: "Hidden")
    }
}

struct ToolboxMenuGroupTableRow: View {
    let group: ToolboxMenuGroup
    @Binding var isEnabled: Bool

    let columns: [GridItem]
    let isSelected: Bool
    let onSelect: () -> Void
    let onToggle: () -> Void

    var body: some View {
        ZStack {
            Rectangle()
                .fill(isSelected ? Color.accentColor.opacity(0.18) : Color.clear)

            LazyVGrid(columns: columns, spacing: 0) {
                dragHandle

                Toggle("", isOn: $isEnabled)
                    .labelsHidden()
                    .toggleStyle(.checkbox)
                    .onChange(of: isEnabled) { _ in onToggle() }

                iconPreview

                VStack(alignment: .leading, spacing: 3) {
                    Text(group.title)
                        .font(.body)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Text(group.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text(menuStatusText)
                    .font(.body)
                    .foregroundStyle(isEnabled ? .green : .secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
        }
        .frame(height: 52)
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
    }

    private var dragHandle: some View {
        Image(systemName: "line.3.horizontal")
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(.tertiary)
            .frame(width: 20, height: 20, alignment: .center)
    }

    private var iconPreview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.accentColor.opacity(0.12))
            Image(systemName: group.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.accentColor)
        }
        .frame(width: 34, height: 34)
    }

    private var menuStatusText: String {
        isEnabled
            ? AssistantLocalized.text(zh: "显示", en: "Shown")
            : AssistantLocalized.text(zh: "隐藏", en: "Hidden")
    }
}

struct ToolboxSettingsRowDropDelegate: DropDelegate {
    let destinationID: ToolboxSettingsRow.ID
    @Binding var rows: [ToolboxSettingsRow]
    @Binding var draggedRowID: ToolboxSettingsRow.ID?
    let onChanged: () -> Void

    func dropEntered(info: DropInfo) {
        guard let draggedRowID,
              draggedRowID != destinationID,
              let fromIndex = rows.firstIndex(where: { $0.id == draggedRowID }),
              let toIndex = rows.firstIndex(where: { $0.id == destinationID }) else {
            return
        }

        withAnimation(.easeInOut(duration: 0.12)) {
            rows.move(
                fromOffsets: IndexSet(integer: fromIndex),
                toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex
            )
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedRowID = nil
        onChanged()
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}
