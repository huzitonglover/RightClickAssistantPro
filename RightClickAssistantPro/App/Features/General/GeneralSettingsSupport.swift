//
//  GeneralSettingsSupport.swift
//  RightClickAssistantPro
//
//  Created by 老谭 on 2026/4/30.
//

import AppKit
import SwiftUI

struct GeneralOverviewEntry: Identifiable {
    let id: String
    let title: String
    let value: String
    let symbol: String
    let tint: Color
}

struct GeneralSettingsSnapshot {
    let extensionEnabled: Bool
    let launchAtLoginEnabled: Bool
    let authorizedDirectoryCount: Int

    var extensionStatusTitle: String {
        extensionEnabled
            ? AssistantLocalized.text(zh: "扩展已启用", en: "Extension Enabled")
            : AssistantLocalized.text(zh: "扩展未启用", en: "Extension Disabled")
    }

    var extensionStatusIcon: String {
        extensionEnabled ? "checkmark.shield.fill" : "exclamationmark.shield"
    }

    var extensionStatusColor: Color {
        extensionEnabled ? .green : .orange
    }

    var overviewEntries: [GeneralOverviewEntry] {
        [
            .init(
                id: "extension",
                title: AssistantLocalized.text(zh: "扩展状态", en: "Extension"),
                value: extensionStatusTitle,
                symbol: extensionStatusIcon,
                tint: extensionStatusColor
            ),
            .init(
                id: "launch",
                title: AssistantLocalized.text(zh: "开机启动", en: "Launch at Login"),
                value: launchAtLoginEnabled
                    ? AssistantLocalized.text(zh: "已开启", en: "Enabled")
                    : AssistantLocalized.text(zh: "未开启", en: "Disabled"),
                symbol: "power",
                tint: .blue
            ),
            .init(
                id: "authorized",
                title: AssistantLocalized.text(zh: "授权目录", en: "Authorized Folders"),
                value: AssistantLocalized.text(zh: "\(authorizedDirectoryCount) 个", en: "\(authorizedDirectoryCount)"),
                symbol: "folder",
                tint: .teal
            )
        ]
    }
}

struct GeneralOverviewCard: View {
    let entry: GeneralOverviewEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(entry.tint.opacity(0.12))
                Image(systemName: entry.symbol)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(entry.tint)
            }
            .frame(width: 40, height: 40)

            Text(entry.title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(entry.value)
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 124, alignment: .topLeading)
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct GeneralSectionCard<Content: View>: View {
    let title: String
    let detail: String
    @ViewBuilder let content: Content

    init(title: String, detail: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.detail = detail
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title3.weight(.semibold))
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct AuthorizedFolderRow: View {
    let item: AuthorizedDirectory
    let removeAction: () -> Void

    private var displayName: String {
        let lastPathComponent = item.url.lastPathComponent
        return lastPathComponent.isEmpty ? item.url.path : lastPathComponent
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "folder")
                .foregroundStyle(Color.accentColor)

            VStack(alignment: .leading, spacing: 4) {
                Text(displayName)
                    .font(.headline)
                Text(verbatim: item.url.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            Spacer(minLength: 0)

            Button(role: .destructive, action: removeAction) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
        }
        .padding(14)
        .background(Color(NSColor.windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
