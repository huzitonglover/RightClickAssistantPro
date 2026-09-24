//
//  FeatureCenterModule.swift
//  RightClickAssistantPro
//
//  Created by Codex on 2026/5/15.
//

import AppKit
import SwiftUI

enum FeatureCenterModuleID: String, CaseIterable, Identifiable {
    case shortcutAssistant = "shortcut-assistant"

    var id: String { rawValue }
}

enum FeatureCenterModuleStatus {
    case ready
    case preview

    var title: String {
        switch self {
        case .ready:
            AssistantLocalized.text(zh: "可用", en: "Ready")
        case .preview:
            AssistantLocalized.text(zh: "预览", en: "Preview")
        }
    }

    var color: Color {
        switch self {
        case .ready:
            .green
        case .preview:
            .orange
        }
    }
}

struct FeatureCenterModule: Identifiable {
    let id: FeatureCenterModuleID
    let title: String
    let summary: String
    let detail: String
    let icon: String
    let accent: Color
    let status: FeatureCenterModuleStatus
    let permissionNotes: [String]
}

enum FeatureCenterRegistry {
    static var modules: [FeatureCenterModule] {
        [
            FeatureCenterModule(
                id: .shortcutAssistant,
                title: AssistantLocalized.text(zh: "快捷键助手", en: "Shortcut Assistant"),
                summary: AssistantLocalized.text(
                    zh: "搜索和查看 macOS 常用系统快捷键。",
                    en: "Search and browse common macOS system shortcuts."
                ),
                detail: AssistantLocalized.text(
                    zh: "内置 macOS 高频快捷键库，可按功能名称、分类或按键组合快速搜索；不读取其他 App，也不需要额外权限。",
                    en: "Includes a macOS shortcut library with search by command name, category, or key combination. It does not read other apps and requires no extra permissions."
                ),
                icon: "keyboard",
                accent: .indigo,
                status: .ready,
                permissionNotes: []
            )
        ]
    }

    static func module(for id: FeatureCenterModuleID) -> FeatureCenterModule {
        modules.first { $0.id == id } ?? modules[0]
    }
}
