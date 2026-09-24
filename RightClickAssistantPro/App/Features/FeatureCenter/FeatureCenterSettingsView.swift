//
//  FeatureCenterSettingsView.swift
//  RightClickAssistantPro
//
//  Created by Codex on 2026/5/15.
//

import AppKit
import SwiftUI

struct FeatureCenterSettingsView: View {
    private var modules: [FeatureCenterModule] {
        FeatureCenterRegistry.modules
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                moduleGrid
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 8)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(AssistantLocalized.text(zh: "功能中心", en: "Feature Center"))
                .font(.title2.weight(.semibold))
            Text(
                AssistantLocalized.text(
                    zh: "这里放独立内置的小功能模块，和工具箱的右键菜单能力分开管理。",
                    en: "Standalone built-in modules live here, separate from the Toolbox context menu features."
                )
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var moduleGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.adaptive(minimum: 210, maximum: 280), spacing: 14, alignment: .top)
            ],
            alignment: .leading,
            spacing: 14
        ) {
            ForEach(modules) { module in
                FeatureCenterModuleCard(module: module)
            }
        }
    }
}

private struct FeatureCenterModuleCard: View {
    let module: FeatureCenterModule

    var body: some View {
        Button {
            RCAAppDelegate.shared?.showFeatureCenterModule(module.id)
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(module.accent.opacity(0.14))
                        Image(systemName: module.icon)
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundStyle(module.accent)
                    }
                    .frame(width: 58, height: 58)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(module.title)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)

                        statusBadge
                    }

                    Spacer(minLength: 0)
                }

                Text(module.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                if let permissionNote = module.permissionNotes.first {
                    Label(permissionNote, systemImage: "lock.shield")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 168, alignment: .topLeading)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.secondary.opacity(0.10), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var statusBadge: some View {
        Text(module.status.title)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(module.status.color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(module.status.color.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
    }
}

#Preview {
    FeatureCenterSettingsView()
}
