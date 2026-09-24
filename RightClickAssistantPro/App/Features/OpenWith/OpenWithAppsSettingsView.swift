//
//  OpenWithAppsSettingsView.swift
//  RightClickAssistantPro
//
//  Created by 老谭 on 2026/4/29.
//

import AppKit
import SwiftUI

struct OpenWithAppsSettingsView: View {
    @EnvironmentObject private var appState: AssistantRuntimeState

    @State private var isImportingApplication = false
    @State private var expandedAppIDs: Set<String> = []
    @State private var editingApplication: OpenWithApplication?

    private let messager = ExtensionMessageBus.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                if appState.apps.isEmpty {
                    emptyState
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(appState.apps) { application in
                            OpenWithApplicationCard(
                                application: application,
                                isExpanded: expandedAppIDs.contains(application.id),
                                onToggleExpand: {
                                    toggleExpansion(for: application.id)
                                },
                                onEdit: {
                                    editingApplication = application
                                },
                                onDelete: {
                                    deleteApp(application)
                                }
                            )
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 8)
        }
        .fileImporter(
            isPresented: $isImportingApplication,
            allowedContentTypes: [.application],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let files):
                guard let url = files.first else { return }
                appState.addApp(item: OpenWithApplication(appURL: url))
                notifyExtension()
            case .failure:
                break
            }
        }
        .sheet(
            isPresented: Binding(
                get: { editingApplication != nil },
                set: { if !$0 { editingApplication = nil } }
            )
        ) {
            if let application = editingApplication {
                OpenWithApplicationEditor(
                    application: application,
                    onCancel: {
                        editingApplication = nil
                    },
                    onSave: { itemName, arguments, environment in
                        appState.updateApp(
                            id: application.id,
                            itemName: itemName,
                            arguments: arguments,
                            environment: environment
                        )
                        notifyExtension()
                        editingApplication = nil
                    }
                )
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(AssistantLocalized.text(zh: "打开方式", en: "Open With"))
                    .font(.title3.weight(.semibold))
                Text(
                    AssistantLocalized.text(
                        zh: "共 \(appState.apps.count) 个应用。可为右键菜单配置自定义名称、启动参数和环境变量。",
                        en: "\(appState.apps.count) apps configured. Customize menu names, launch arguments, and environment variables."
                    )
                )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Button {
                isImportingApplication = true
            } label: {
                Label(AssistantLocalized.text(zh: "添加应用", en: "Add App"), systemImage: "plus.app")
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(AssistantLocalized.text(zh: "还没有配置打开方式", en: "No Open-With Apps Yet"))
                .font(.headline)
            Text(
                AssistantLocalized.text(
                    zh: "添加后可以从 Finder 右键菜单直接用指定应用打开当前文件。",
                    en: "Add an app to open selected files directly from the Finder context menu."
                )
            )
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button {
                isImportingApplication = true
            } label: {
                Label(AssistantLocalized.text(zh: "选择应用", en: "Choose App"), systemImage: "plus.app")
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func toggleExpansion(for appID: String) {
        if expandedAppIDs.contains(appID) {
            expandedAppIDs.remove(appID)
        } else {
            expandedAppIDs.insert(appID)
        }
    }

    @MainActor
    private func deleteApp(_ application: OpenWithApplication) {
        guard let index = appState.apps.firstIndex(where: { $0.id == application.id }) else { return }
        appState.deleteApp(index: index)
        expandedAppIDs.remove(application.id)
        notifyExtension()
    }

    private func notifyExtension() {
        messager.sendMessage(
            name: "running",
            data: ExtensionMessagePayload(action: "running", target: [])
        )
    }
}

private struct OpenWithApplicationCard: View {
    let application: OpenWithApplication
    let isExpanded: Bool
    let onToggleExpand: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(nsImage: AssistantFileIconCache.icon(forPath: application.url.path))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 4) {
                    Text(application.name)
                        .font(.headline)
                    Text(verbatim: application.url.path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }

                Spacer(minLength: 0)

                HStack(spacing: 10) {
                    Button(action: onToggleExpand) {
                        Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle")
                    }
                    .buttonStyle(.plain)

                    Menu {
                        Button(AssistantLocalized.text(zh: "编辑", en: "Edit")) {
                            onEdit()
                        }
                        Button(AssistantLocalized.text(zh: "删除", en: "Delete"), role: .destructive) {
                            onDelete()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    OpenWithDetailGroup(
                        title: AssistantLocalized.text(zh: "启动参数", en: "Launch Arguments"),
                        values: application.arguments,
                        emptyText: AssistantLocalized.text(zh: "未配置参数", en: "No arguments configured")
                    )
                    OpenWithDetailGroup(
                        title: AssistantLocalized.text(zh: "环境变量", en: "Environment Variables"),
                        values: application.environment
                            .sorted(by: { $0.key < $1.key })
                            .map { "\($0.key)=\($0.value)" },
                        emptyText: AssistantLocalized.text(zh: "未配置环境变量", en: "No environment variables configured")
                    )
                }
                .padding(.leading, 48)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct OpenWithDetailGroup: View {
    let title: String
    let values: [String]
    let emptyText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            if values.isEmpty {
                Text(emptyText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(values, id: \.self) { value in
                        Text(value)
                            .font(.system(.body, design: .monospaced))
                    }
                }
            }
        }
    }
}

private struct OpenWithApplicationEditor: View {
    let application: OpenWithApplication
    let onCancel: () -> Void
    let onSave: (String, [String], [String: String]) -> Void

    @State private var itemName: String
    @State private var argumentsText: String
    @State private var environmentText: String

    init(
        application: OpenWithApplication,
        onCancel: @escaping () -> Void,
        onSave: @escaping (String, [String], [String: String]) -> Void
    ) {
        self.application = application
        self.onCancel = onCancel
        self.onSave = onSave
        _itemName = State(initialValue: application.itemName)
        _argumentsText = State(initialValue: application.arguments.joined(separator: "; "))
        _environmentText = State(
            initialValue: application.environment
                .sorted(by: { $0.key < $1.key })
                .map { "\($0.key)=\($0.value)" }
                .joined(separator: "\n")
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text(AssistantLocalized.text(zh: "编辑打开方式", en: "Edit Open-With App"))
                    .font(.title3.weight(.semibold))
                Text(application.appName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Form {
                TextField(AssistantLocalized.text(zh: "菜单显示名称", en: "Menu Display Name"), text: $itemName)

                VStack(alignment: .leading, spacing: 6) {
                    Text(AssistantLocalized.text(zh: "启动参数", en: "Launch Arguments"))
                        .font(.headline)
                    Text(AssistantLocalized.text(zh: "多个参数请用分号 `;` 分隔。", en: "Separate multiple arguments with semicolons `;`."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField(AssistantLocalized.text(zh: "例如：--reuse-window; --wait", en: "Example: --reuse-window; --wait"), text: $argumentsText)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(AssistantLocalized.text(zh: "环境变量", en: "Environment Variables"))
                        .font(.headline)
                    Text(AssistantLocalized.text(zh: "每行一项，格式为 `KEY=VALUE`。", en: "One item per line in `KEY=VALUE` format."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextEditor(text: $environmentText)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 120)
                }
            }
            .compatibilityGroupedFormStyle()

            HStack {
                Spacer(minLength: 0)
                Button(AssistantLocalized.text(zh: "取消", en: "Cancel"), action: onCancel)
                    .keyboardShortcut(.escape)
                Button(AssistantLocalized.text(zh: "保存", en: "Save")) {
                    onSave(
                        itemName,
                        parseArguments(argumentsText),
                        parseEnvironment(environmentText)
                    )
                }
                .keyboardShortcut(.return)
            }
        }
        .padding(24)
        .frame(minWidth: 460, minHeight: 380)
    }

    private func parseArguments(_ text: String) -> [String] {
        text
            .components(separatedBy: ";")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func parseEnvironment(_ text: String) -> [String: String] {
        var result: [String: String] = [:]
        for line in text.split(separator: "\n") {
            let parts = line.split(separator: "=", maxSplits: 1)
            guard parts.count == 2 else { continue }
            result[String(parts[0]).trimmingCharacters(in: .whitespaces)] =
                String(parts[1]).trimmingCharacters(in: .whitespaces)
        }
        return result
    }
}
