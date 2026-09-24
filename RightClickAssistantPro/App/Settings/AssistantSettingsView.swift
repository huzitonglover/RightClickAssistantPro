//
//  AssistantSettingsView.swift
//  RightClickAssistantPro
//
//  Created by 老谭 on 2026/4/30.
//

import SwiftUI

struct AssistantSettingsView: View {
    @State private var selectedTab: AssistantSettingsTab
    @EnvironmentObject private var appState: AssistantRuntimeState

    init(initialTab: AssistantSettingsTab = .general) {
        _selectedTab = State(initialValue: initialTab)
    }

    private var versionText: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? AssistantLocalized.text(zh: "未知", en: "Unknown")
    }

    var body: some View {
        HSplitView {
            sidebarColumn
            detailColumn
        }
        .frame(minWidth: 840, minHeight: 500)
    }

    private var sidebarColumn: some View {
        VStack(alignment: .leading, spacing: 18) {
            sidebarHeader

            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(AssistantSettingsTab.allCases) { tab in
                        SettingsSidebarButton(
                            title: tab.title,
                            subtitle: tab.summary,
                            icon: tab.icon,
                            accent: tab.accent,
                            isSelected: selectedTab == tab
                        ) {
                            selectedTab = tab
                        }
                    }
                }
                .padding(.top, 6)
            }

            Text(
                AssistantLocalized.text(
                    zh: "右键工具Pro围绕 Finder 右键、文件创建和常用路径做集中配置。",
                    en: "RightMenuPro centralizes Finder context menu, file creation, and frequently used paths."
                )
            )
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(minWidth: 280, idealWidth: 300, maxWidth: 320, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(NSColor.controlBackgroundColor))
    }

    private var detailColumn: some View {
        VStack(alignment: .leading, spacing: 18) {
            if shouldShowHeroBanner {
                SettingsHeroBanner(tab: selectedTab)
            }
            selectedTab.makeContentView()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(
            EdgeInsets(
                top: usesCompactTopPadding ? 12 : 24,
                leading: 24,
                bottom: 24,
                trailing: 24
            )
        )
        .frame(minWidth: 560, idealWidth: 860, maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var shouldShowHeroBanner: Bool {
        selectedTab != .about
            && selectedTab != .general
            && selectedTab != .featureCenter
            && selectedTab != .tutorial
            && selectedTab != .contact
    }

    private var usesCompactTopPadding: Bool {
        selectedTab == .general
            || selectedTab == .featureCenter
            || selectedTab == .tutorial
            || selectedTab == .contact
    }

    private var sidebarHeader: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                Image("AssistantBrandMark")
                    .resizable()
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(AssistantLocalized.appName)
                        .font(.title2.weight(.semibold))
                    Text("\(AssistantLocalized.text(zh: "版本", en: "Version")) \(versionText)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 10) {
                SettingsMetricPill(label: AssistantLocalized.text(zh: "打开方式", en: "Open With"), value: "\(appState.apps.count)")
                SettingsMetricPill(label: AssistantLocalized.text(zh: "工具箱", en: "Toolbox"), value: "\(toolboxSwitchCount)")
                SettingsMetricPill(label: AssistantLocalized.text(zh: "模板", en: "Templates"), value: "\(appState.newFiles.count)")
            }
        }
    }

    private var toolboxSwitchCount: Int {
        ToolboxSettingsRow.defaultOrder.filter { row in
            switch row {
            case .menuGroup:
                return true
            case .quickAction(let identifier):
                return appState.actions.first(where: { $0.id == identifier })?.isAvailableOnCurrentSystem == true
            }
        }.count
    }
}

private struct SettingsMetricPill: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.headline.monospacedDigit())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(NSColor.windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct SettingsSidebarButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let accent: Color
    let isSelected: Bool
    let action: () -> Void

    private let cornerRadius: CGFloat = 16

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.10) : Color.clear)

                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        isSelected ? Color.accentColor.opacity(0.25) : Color.secondary.opacity(0.10),
                        lineWidth: 1
                    )

                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(accent.opacity(isSelected ? 0.18 : 0.12))
                        Image(systemName: icon)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(accent)
                    }
                    .frame(width: 34, height: 34)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        if !subtitle.isEmpty {
                            Text(subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
            }
            .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .buttonStyle(.plain)
    }
}

private struct SettingsHeroBanner: View {
    let tab: AssistantSettingsTab

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(tab.accent.opacity(0.12))
                Image(systemName: tab.icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(tab.accent)
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 5) {
                Text(tab.title)
                    .font(.title2.weight(.semibold))
                Text(tab.summary)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(18)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

#Preview {
    AssistantSettingsView()
}
