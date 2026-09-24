//
//  BatchRenameView.swift
//  RightClickAssistantPro
//
//  Created by 老谭 on 2026/4/30.
//

import AppKit
import SwiftUI

struct BatchRenameSeed: Identifiable, Hashable {
    let path: String
    let directoryPath: String
    let originalName: String
    let editableName: String
    let preservedExtension: String
    let isDirectory: Bool

    var id: String { path }
}

struct BatchRenameOperation: Hashable, Sendable {
    let sourcePath: String
    let destinationPath: String
}

private struct BatchRenameRules {
    var findText = ""
    var replaceText = ""
    var prefix = ""
    var suffix = ""
    var unifiedBaseName = ""
    var numberingEnabled = false
    var startNumber = 1
    var padding = 3
    var numberSeparator = "-"
}

private enum BatchRenamePreviewState {
    case unchanged
    case ready
    case invalid(String)

    var message: String {
        switch self {
        case .unchanged:
            return AssistantLocalized.text(zh: "保持不变", en: "Unchanged")
        case .ready:
            return AssistantLocalized.text(zh: "准备应用", en: "Ready")
        case .invalid(let reason):
            return reason
        }
    }
}

private struct BatchRenamePreviewItem: Identifiable {
    let seed: BatchRenameSeed
    let proposedName: String
    let destinationPath: String
    let state: BatchRenamePreviewState

    var id: String { seed.id }
    var hasChange: Bool { destinationPath != seed.path }

    var isExecutable: Bool {
        guard hasChange else {
            return false
        }

        if case .ready = state {
            return true
        }

        return false
    }

    var statusText: String { state.message }
}

private struct BatchRenamePlan {
    let previewItems: [BatchRenamePreviewItem]

    var operations: [BatchRenameOperation] {
        previewItems.compactMap { item in
            guard item.isExecutable else {
                return nil
            }

            return BatchRenameOperation(
                sourcePath: item.seed.path,
                destinationPath: item.destinationPath
            )
        }
    }

    var changedCount: Int {
        previewItems.filter(\.hasChange).count
    }

    var invalidCount: Int {
        previewItems.reduce(into: 0) { count, item in
            if case .invalid = item.state {
                count += 1
            }
        }
    }
}

private enum BatchRenamePlanner {
    private static let invalidCharacters = CharacterSet(charactersIn: "/:\n\r")

    static func makePlan(seeds: [BatchRenameSeed], rules: BatchRenameRules) -> BatchRenamePlan {
        let orderedSeeds = seeds.sorted { lhs, rhs in
            let compare = lhs.originalName.localizedStandardCompare(rhs.originalName)
            if compare == .orderedSame {
                return lhs.path < rhs.path
            }
            return compare == .orderedAscending
        }

        let previewDrafts = orderedSeeds.enumerated().map { index, seed in
            makeDraft(seed: seed, index: index, rules: rules)
        }

        let targetKeyCounts = Dictionary(
            previewDrafts.map { (canonicalPathKey(for: $0.destinationPath), 1) },
            uniquingKeysWith: +
        )
        let selectedSourceKeys = Set(orderedSeeds.map { canonicalPathKey(for: $0.path) })
        let fileManager = FileManager.default

        let previewItems = previewDrafts.map { draft -> BatchRenamePreviewItem in
            if let validationMessage = draft.validationMessage {
                return BatchRenamePreviewItem(
                    seed: draft.seed,
                    proposedName: draft.proposedName,
                    destinationPath: draft.destinationPath,
                    state: .invalid(validationMessage)
                )
            }

            guard draft.destinationPath != draft.seed.path else {
                return BatchRenamePreviewItem(
                    seed: draft.seed,
                    proposedName: draft.proposedName,
                    destinationPath: draft.destinationPath,
                    state: .unchanged
                )
            }

            let destinationKey = canonicalPathKey(for: draft.destinationPath)
            if targetKeyCounts[destinationKey, default: 0] > 1 {
                return BatchRenamePreviewItem(
                    seed: draft.seed,
                    proposedName: draft.proposedName,
                    destinationPath: draft.destinationPath,
                    state: .invalid(AssistantLocalized.text(zh: "目标名称重复", en: "Duplicate target name"))
                )
            }

            if fileManager.fileExists(atPath: draft.destinationPath),
               !selectedSourceKeys.contains(destinationKey) {
                return BatchRenamePreviewItem(
                    seed: draft.seed,
                    proposedName: draft.proposedName,
                    destinationPath: draft.destinationPath,
                    state: .invalid(AssistantLocalized.text(zh: "目标位置已存在同名项目", en: "An item with the same name already exists at the destination"))
                )
            }

            return BatchRenamePreviewItem(
                seed: draft.seed,
                proposedName: draft.proposedName,
                destinationPath: draft.destinationPath,
                state: .ready
            )
        }

        return BatchRenamePlan(previewItems: previewItems)
    }

    private static func makeDraft(
        seed: BatchRenameSeed,
        index: Int,
        rules: BatchRenameRules
    ) -> (seed: BatchRenameSeed, proposedName: String, destinationPath: String, validationMessage: String?) {
        let result = proposedFilename(for: seed, index: index, rules: rules)
        let destinationPath = URL(fileURLWithPath: seed.directoryPath, isDirectory: true)
            .appendingPathComponent(result.name)
            .standardizedFileURL
            .path

        return (seed, result.name, destinationPath, result.validationMessage)
    }

    private static func proposedFilename(
        for seed: BatchRenameSeed,
        index: Int,
        rules: BatchRenameRules
    ) -> (name: String, validationMessage: String?) {
        var editableName = rules.unifiedBaseName.trimmingCharacters(in: .whitespacesAndNewlines)
        if editableName.isEmpty {
            editableName = seed.editableName
        }

        if !rules.findText.isEmpty {
            editableName = editableName.replacingOccurrences(
                of: rules.findText,
                with: rules.replaceText
            )
        }

        editableName = rules.prefix + editableName + rules.suffix

        if rules.numberingEnabled {
            let number = rules.startNumber + index
            let digits = max(1, rules.padding)
            let numberText = String(format: "%0*d", digits, number)
            editableName += rules.numberSeparator + numberText
        }

        let normalizedName = editableName.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalizedName.isEmpty {
            return (seed.originalName, AssistantLocalized.text(zh: "名称不能为空", en: "Name cannot be empty"))
        }

        if normalizedName == "." || normalizedName == ".." {
            return (seed.originalName, AssistantLocalized.text(zh: "名称无效", en: "Invalid name"))
        }

        if normalizedName.rangeOfCharacter(from: invalidCharacters) != nil {
            return (seed.originalName, AssistantLocalized.text(zh: "名称包含非法字符", en: "Name contains invalid characters"))
        }

        guard !seed.isDirectory else {
            return (normalizedName, nil)
        }

        return (normalizedName + seed.preservedExtension, nil)
    }

    private static func canonicalPathKey(for path: String) -> String {
        URL(fileURLWithPath: path).standardizedFileURL.path.lowercased()
    }
}

struct BatchRenameView: View {
    let seeds: [BatchRenameSeed]
    let onCancel: () -> Void
    let onApply: ([BatchRenameOperation]) -> Void

    @State private var rules = BatchRenameRules()

    private var plan: BatchRenamePlan {
        BatchRenamePlanner.makePlan(seeds: seeds, rules: rules)
    }

    private var canApply: Bool {
        plan.invalidCount == 0 && !plan.operations.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            HStack(alignment: .top, spacing: 0) {
                controlPanel
                    .frame(width: 320)
                Divider()
                previewPanel
            }

            Divider()
            footer
        }
        .background(Color(NSColor.windowBackgroundColor))
        .frame(minWidth: 900, minHeight: 640)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(AssistantLocalized.text(zh: "批量命名", en: "Batch Rename"))
                    .font(.title2.weight(.semibold))
                Text(AssistantLocalized.text(zh: "默认保留文件扩展名，编号顺序按名称排序。", en: "File extensions are preserved by default, and numbering follows name order."))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            HStack(spacing: 10) {
                summaryPill(title: AssistantLocalized.text(zh: "选中项目", en: "Selected"), value: "\(seeds.count)")
                summaryPill(title: AssistantLocalized.text(zh: "待更名", en: "Pending"), value: "\(plan.changedCount)")
                summaryPill(title: AssistantLocalized.text(zh: "冲突", en: "Conflicts"), value: "\(plan.invalidCount)", accent: plan.invalidCount > 0 ? .red : .secondary)
            }
        }
        .padding(20)
    }

    private var controlPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                controlCard(
                    title: AssistantLocalized.text(zh: "文本替换", en: "Find & Replace"),
                    subtitle: AssistantLocalized.text(zh: "只在名称部分处理，不改扩展名。", en: "Only the file name is changed. Extensions stay untouched.")
                ) {
                    VStack(spacing: 10) {
                        TextField(AssistantLocalized.text(zh: "查找文本", en: "Find"), text: $rules.findText)
                            .textFieldStyle(.roundedBorder)
                        TextField(AssistantLocalized.text(zh: "替换为", en: "Replace With"), text: $rules.replaceText)
                            .textFieldStyle(.roundedBorder)
                    }
                }

                controlCard(
                    title: AssistantLocalized.text(zh: "前缀与后缀", en: "Prefix & Suffix"),
                    subtitle: AssistantLocalized.text(zh: "适合统一补充项目标识。", en: "Useful for applying a shared marker to all items.")
                ) {
                    VStack(spacing: 10) {
                        TextField(AssistantLocalized.text(zh: "前缀", en: "Prefix"), text: $rules.prefix)
                            .textFieldStyle(.roundedBorder)
                        TextField(AssistantLocalized.text(zh: "后缀", en: "Suffix"), text: $rules.suffix)
                            .textFieldStyle(.roundedBorder)
                    }
                }

                controlCard(
                    title: AssistantLocalized.text(zh: "统一名称", en: "Base Name"),
                    subtitle: AssistantLocalized.text(zh: "留空时保留原名称，再叠加其他规则。", en: "Leave empty to keep the original name before applying other rules.")
                ) {
                    TextField(AssistantLocalized.text(zh: "统一名称", en: "Base Name"), text: $rules.unifiedBaseName)
                        .textFieldStyle(.roundedBorder)
                }

                controlCard(
                    title: AssistantLocalized.text(zh: "自动编号", en: "Auto Numbering"),
                    subtitle: AssistantLocalized.text(zh: "常用于图片、文档、素材整理。", en: "Useful for images, documents, and asset organization.")
                ) {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle(AssistantLocalized.text(zh: "追加编号", en: "Append Numbers"), isOn: $rules.numberingEnabled)
                            .toggleStyle(.switch)

                        if rules.numberingEnabled {
                            Stepper(value: $rules.startNumber, in: 0 ... 999_999) {
                                settingsRow(title: AssistantLocalized.text(zh: "起始编号", en: "Start Number"), value: "\(rules.startNumber)")
                            }

                            Stepper(value: $rules.padding, in: 1 ... 8) {
                                settingsRow(title: AssistantLocalized.text(zh: "补齐位数", en: "Digit Width"), value: "\(rules.padding)")
                            }

                            TextField(AssistantLocalized.text(zh: "编号连接符", en: "Number Separator"), text: $rules.numberSeparator)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                }
            }
            .padding(18)
        }
    }

    private var previewPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(AssistantLocalized.text(zh: "结果预览", en: "Preview"))
                    .font(.headline)
                Spacer(minLength: 0)
                Text(AssistantLocalized.text(zh: "原名称 -> 新名称", en: "Original Name -> New Name"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 12)

            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(plan.previewItems) { item in
                        previewRow(item)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var footer: some View {
        HStack(alignment: .center, spacing: 14) {
            if plan.invalidCount > 0 {
                Text(AssistantLocalized.text(zh: "存在 \(plan.invalidCount) 项冲突，先调整规则再应用。", en: "\(plan.invalidCount) conflict(s) found. Adjust the rules before applying."))
                    .font(.subheadline)
                    .foregroundStyle(.red)
            } else if plan.operations.isEmpty {
                Text(AssistantLocalized.text(zh: "当前没有需要应用的更名项。", en: "There are no rename changes to apply."))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text(AssistantLocalized.text(zh: "本次将应用 \(plan.operations.count) 项更名，可通过“撤销上次操作”回退。", en: "\(plan.operations.count) rename operation(s) will be applied. You can revert them with Undo Last Operation."))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Button(AssistantLocalized.text(zh: "取消", en: "Cancel"), action: onCancel)
                .keyboardShortcut(.cancelAction)

            Button(AssistantLocalized.text(zh: "应用更名", en: "Apply Rename")) {
                onApply(plan.operations)
            }
            .keyboardShortcut(.defaultAction)
            .disabled(!canApply)
        }
        .padding(16)
    }

    private func previewRow(_ item: BatchRenamePreviewItem) -> some View {
        let statusColor: Color = {
            switch item.state {
            case .unchanged:
                return .secondary
            case .ready:
                return .green
            case .invalid:
                return .red
            }
        }()

        return HStack(alignment: .top, spacing: 14) {
            Image(nsImage: AssistantFileIconCache.icon(forPath: item.seed.path))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 28, height: 28)
                .padding(8)
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.seed.originalName)
                            .font(.body.weight(.medium))
                        Text(item.proposedName)
                            .font(.subheadline)
                            .foregroundStyle(item.hasChange ? Color.primary : Color.secondary)
                    }

                    Spacer(minLength: 0)

                    Text(item.statusText)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(statusColor)
                        .multilineTextAlignment(.trailing)
                }

                Text(item.seed.directoryPath)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func summaryPill(title: String, value: String, accent: Color = .accentColor) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.headline)
                .foregroundStyle(accent)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func controlCard<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func settingsRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer(minLength: 0)
            Text(value)
                .foregroundStyle(.secondary)
        }
    }
}
