//
//  ShortcutAssistantView.swift
//  RightClickAssistantPro
//
//  Created by Codex on 2026/5/15.
//

import AppKit
import SwiftUI

private struct ShortcutAssistantSection: Identifiable {
    let id: String
    let title: String
    let icon: String
    let items: [ShortcutAssistantItem]
}

private struct ShortcutAssistantItem: Identifiable {
    let id: String
    let name: String
    let keys: [String]

    func matchesSearchQuery(_ query: String, sectionTitle: String? = nil) -> Bool {
        [
            sectionTitle,
            name,
            keys.joined(),
            keys.joined(separator: "+"),
            keys.shortcutSearchAliasText
        ]
            .compactMap { $0 }
            .map(\.normalizedShortcutSearchQuery)
            .contains { $0.contains(query) }
    }
}

struct ShortcutAssistantView: View {
    let onClose: () -> Void

    @State private var searchText = ""

    private let systemShortcutSections: [ShortcutAssistantSection] = [
        ShortcutAssistantSection(
            id: "mac-basic-editing",
            title: AssistantLocalized.text(zh: "基础编辑", en: "Basic Editing"),
            icon: "pencil.line",
            items: [
                ShortcutAssistantItem(id: "copy", name: AssistantLocalized.text(zh: "复制", en: "Copy"), keys: ["⌘", "C"]),
                ShortcutAssistantItem(id: "paste", name: AssistantLocalized.text(zh: "粘贴", en: "Paste"), keys: ["⌘", "V"]),
                ShortcutAssistantItem(id: "cut", name: AssistantLocalized.text(zh: "剪切", en: "Cut"), keys: ["⌘", "X"]),
                ShortcutAssistantItem(id: "undo", name: AssistantLocalized.text(zh: "撤销", en: "Undo"), keys: ["⌘", "Z"]),
                ShortcutAssistantItem(id: "redo", name: AssistantLocalized.text(zh: "重做", en: "Redo"), keys: ["⇧", "⌘", "Z"]),
                ShortcutAssistantItem(id: "select-all", name: AssistantLocalized.text(zh: "全选", en: "Select All"), keys: ["⌘", "A"]),
                ShortcutAssistantItem(id: "find", name: AssistantLocalized.text(zh: "查找", en: "Find"), keys: ["⌘", "F"]),
                ShortcutAssistantItem(id: "find-next", name: AssistantLocalized.text(zh: "查找下一个", en: "Find Next"), keys: ["⌘", "G"]),
                ShortcutAssistantItem(id: "find-previous", name: AssistantLocalized.text(zh: "查找上一个", en: "Find Previous"), keys: ["⇧", "⌘", "G"]),
                ShortcutAssistantItem(id: "save", name: AssistantLocalized.text(zh: "保存", en: "Save"), keys: ["⌘", "S"]),
                ShortcutAssistantItem(id: "print", name: AssistantLocalized.text(zh: "打印", en: "Print"), keys: ["⌘", "P"]),
                ShortcutAssistantItem(id: "preferences", name: AssistantLocalized.text(zh: "打开设置", en: "Open Settings"), keys: ["⌘", ","])
            ]
        ),
        ShortcutAssistantSection(
            id: "mac-system-windows",
            title: AssistantLocalized.text(zh: "系统与窗口", en: "System & Windows"),
            icon: "macwindow",
            items: [
                ShortcutAssistantItem(id: "close-window", name: AssistantLocalized.text(zh: "关闭窗口", en: "Close Window"), keys: ["⌘", "W"]),
                ShortcutAssistantItem(id: "minimize", name: AssistantLocalized.text(zh: "最小化", en: "Minimize"), keys: ["⌘", "M"]),
                ShortcutAssistantItem(id: "hide-app", name: AssistantLocalized.text(zh: "隐藏当前 App", en: "Hide App"), keys: ["⌘", "H"]),
                ShortcutAssistantItem(id: "hide-others", name: AssistantLocalized.text(zh: "隐藏其他 App", en: "Hide Others"), keys: ["⌥", "⌘", "H"]),
                ShortcutAssistantItem(id: "quit-app", name: AssistantLocalized.text(zh: "退出当前 App", en: "Quit App"), keys: ["⌘", "Q"]),
                ShortcutAssistantItem(id: "force-quit", name: AssistantLocalized.text(zh: "强制退出窗口", en: "Force Quit Window"), keys: ["⌥", "⌘", "Esc"]),
                ShortcutAssistantItem(id: "switch-app", name: AssistantLocalized.text(zh: "切换 App", en: "Switch App"), keys: ["⌘", "Tab"]),
                ShortcutAssistantItem(id: "switch-window", name: AssistantLocalized.text(zh: "切换当前 App 窗口", en: "Switch App Window"), keys: ["⌘", "`"]),
                ShortcutAssistantItem(id: "fullscreen", name: AssistantLocalized.text(zh: "进入或退出全屏", en: "Enter or Exit Full Screen"), keys: ["⌃", "⌘", "F"]),
                ShortcutAssistantItem(id: "lock-screen", name: AssistantLocalized.text(zh: "锁定屏幕", en: "Lock Screen"), keys: ["⌃", "⌘", "Q"])
            ]
        ),
        ShortcutAssistantSection(
            id: "mac-screenshots",
            title: AssistantLocalized.text(zh: "截图与录屏", en: "Screenshots & Recording"),
            icon: "camera.viewfinder",
            items: [
                ShortcutAssistantItem(id: "screenshot-screen", name: AssistantLocalized.text(zh: "截取整个屏幕", en: "Capture Entire Screen"), keys: ["⇧", "⌘", "3"]),
                ShortcutAssistantItem(id: "screenshot-area", name: AssistantLocalized.text(zh: "截取选定区域", en: "Capture Selected Area"), keys: ["⇧", "⌘", "4"]),
                ShortcutAssistantItem(id: "screenshot-window", name: AssistantLocalized.text(zh: "截取窗口或菜单", en: "Capture Window or Menu"), keys: ["⇧", "⌘", "4", "Space"]),
                ShortcutAssistantItem(id: "screenshot-toolbar", name: AssistantLocalized.text(zh: "打开截图与录屏工具", en: "Open Screenshot Toolbar"), keys: ["⇧", "⌘", "5"]),
                ShortcutAssistantItem(id: "screenshot-touchbar", name: AssistantLocalized.text(zh: "截取触控栏", en: "Capture Touch Bar"), keys: ["⇧", "⌘", "6"])
            ]
        ),
        ShortcutAssistantSection(
            id: "mac-finder",
            title: AssistantLocalized.text(zh: "Finder", en: "Finder"),
            icon: "folder",
            items: [
                ShortcutAssistantItem(id: "new-folder", name: AssistantLocalized.text(zh: "新建文件夹", en: "New Folder"), keys: ["⇧", "⌘", "N"]),
                ShortcutAssistantItem(id: "get-info", name: AssistantLocalized.text(zh: "显示简介", en: "Get Info"), keys: ["⌘", "I"]),
                ShortcutAssistantItem(id: "duplicate", name: AssistantLocalized.text(zh: "复制项目", en: "Duplicate"), keys: ["⌘", "D"]),
                ShortcutAssistantItem(id: "make-alias", name: AssistantLocalized.text(zh: "制作替身", en: "Make Alias"), keys: ["⌃", "⌘", "A"]),
                ShortcutAssistantItem(id: "quick-look", name: AssistantLocalized.text(zh: "快速查看", en: "Quick Look"), keys: ["Space"]),
                ShortcutAssistantItem(id: "move-trash", name: AssistantLocalized.text(zh: "移到废纸篓", en: "Move to Trash"), keys: ["⌘", "⌫"]),
                ShortcutAssistantItem(id: "empty-trash", name: AssistantLocalized.text(zh: "清倒废纸篓", en: "Empty Trash"), keys: ["⇧", "⌘", "⌫"]),
                ShortcutAssistantItem(id: "go-computer", name: AssistantLocalized.text(zh: "前往电脑", en: "Go to Computer"), keys: ["⇧", "⌘", "C"]),
                ShortcutAssistantItem(id: "go-desktop", name: AssistantLocalized.text(zh: "前往桌面", en: "Go to Desktop"), keys: ["⇧", "⌘", "D"]),
                ShortcutAssistantItem(id: "go-downloads", name: AssistantLocalized.text(zh: "前往下载", en: "Go to Downloads"), keys: ["⌥", "⌘", "L"]),
                ShortcutAssistantItem(id: "go-home", name: AssistantLocalized.text(zh: "前往个人文件夹", en: "Go to Home"), keys: ["⇧", "⌘", "H"]),
                ShortcutAssistantItem(id: "go-applications", name: AssistantLocalized.text(zh: "前往应用程序", en: "Go to Applications"), keys: ["⇧", "⌘", "A"]),
                ShortcutAssistantItem(id: "connect-server", name: AssistantLocalized.text(zh: "连接服务器", en: "Connect to Server"), keys: ["⌘", "K"]),
                ShortcutAssistantItem(id: "show-hidden-files", name: AssistantLocalized.text(zh: "显示或隐藏隐藏文件", en: "Show or Hide Hidden Files"), keys: ["⇧", "⌘", "."])
            ]
        ),
        ShortcutAssistantSection(
            id: "mac-search",
            title: AssistantLocalized.text(zh: "搜索与启动", en: "Search & Launch"),
            icon: "magnifyingglass",
            items: [
                ShortcutAssistantItem(id: "spotlight", name: AssistantLocalized.text(zh: "打开 Spotlight", en: "Open Spotlight"), keys: ["⌘", "Space"]),
                ShortcutAssistantItem(id: "finder-search", name: AssistantLocalized.text(zh: "打开 Finder 搜索", en: "Open Finder Search"), keys: ["⌥", "⌘", "Space"]),
                ShortcutAssistantItem(id: "spotlight-open-result", name: AssistantLocalized.text(zh: "打开 Spotlight 结果", en: "Open Spotlight Result"), keys: ["↩"]),
                ShortcutAssistantItem(id: "spotlight-quicklook", name: AssistantLocalized.text(zh: "预览 Spotlight 结果", en: "Preview Spotlight Result"), keys: ["Space"]),
                ShortcutAssistantItem(id: "spotlight-show-file", name: AssistantLocalized.text(zh: "在 Finder 中显示结果", en: "Reveal Result in Finder"), keys: ["⌘", "↩"])
            ]
        ),
        ShortcutAssistantSection(
            id: "mac-text-navigation",
            title: AssistantLocalized.text(zh: "文本与光标", en: "Text & Cursor"),
            icon: "text.cursor",
            items: [
                ShortcutAssistantItem(id: "line-start", name: AssistantLocalized.text(zh: "移到行首", en: "Move to Line Start"), keys: ["⌘", "←"]),
                ShortcutAssistantItem(id: "line-end", name: AssistantLocalized.text(zh: "移到行尾", en: "Move to Line End"), keys: ["⌘", "→"]),
                ShortcutAssistantItem(id: "document-start", name: AssistantLocalized.text(zh: "移到文稿开头", en: "Move to Document Start"), keys: ["⌘", "↑"]),
                ShortcutAssistantItem(id: "document-end", name: AssistantLocalized.text(zh: "移到文稿结尾", en: "Move to Document End"), keys: ["⌘", "↓"]),
                ShortcutAssistantItem(id: "word-left", name: AssistantLocalized.text(zh: "移到上一个词", en: "Move to Previous Word"), keys: ["⌥", "←"]),
                ShortcutAssistantItem(id: "word-right", name: AssistantLocalized.text(zh: "移到下一个词", en: "Move to Next Word"), keys: ["⌥", "→"]),
                ShortcutAssistantItem(id: "select-line-start", name: AssistantLocalized.text(zh: "选择到行首", en: "Select to Line Start"), keys: ["⇧", "⌘", "←"]),
                ShortcutAssistantItem(id: "select-line-end", name: AssistantLocalized.text(zh: "选择到行尾", en: "Select to Line End"), keys: ["⇧", "⌘", "→"]),
                ShortcutAssistantItem(id: "delete-word-left", name: AssistantLocalized.text(zh: "删除前一个词", en: "Delete Previous Word"), keys: ["⌥", "⌫"]),
                ShortcutAssistantItem(id: "delete-line-left", name: AssistantLocalized.text(zh: "删除到行首", en: "Delete to Line Start"), keys: ["⌘", "⌫"])
            ]
        ),
        ShortcutAssistantSection(
            id: "mac-keyboard-focus",
            title: AssistantLocalized.text(zh: "键盘焦点", en: "Keyboard Focus"),
            icon: "keyboard",
            items: [
                ShortcutAssistantItem(id: "focus-menu-bar", name: AssistantLocalized.text(zh: "聚焦菜单栏", en: "Focus Menu Bar"), keys: ["Fn", "⌃", "F2"]),
                ShortcutAssistantItem(id: "focus-dock", name: AssistantLocalized.text(zh: "聚焦 Dock", en: "Focus Dock"), keys: ["Fn", "⌃", "F3"]),
                ShortcutAssistantItem(id: "focus-window", name: AssistantLocalized.text(zh: "聚焦活动窗口", en: "Focus Active Window"), keys: ["Fn", "⌃", "F4"]),
                ShortcutAssistantItem(id: "focus-toolbar", name: AssistantLocalized.text(zh: "聚焦工具栏", en: "Focus Toolbar"), keys: ["Fn", "⌃", "F5"]),
                ShortcutAssistantItem(id: "focus-status-menu", name: AssistantLocalized.text(zh: "聚焦状态菜单", en: "Focus Status Menus"), keys: ["Fn", "⌃", "F8"]),
                ShortcutAssistantItem(id: "emoji-viewer", name: AssistantLocalized.text(zh: "打开表情与符号", en: "Open Emoji & Symbols"), keys: ["⌃", "⌘", "Space"])
            ]
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    searchField

                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        sectionHeader(
                            title: AssistantLocalized.text(zh: "系统快捷键", en: "System Shortcuts"),
                            icon: "books.vertical"
                        )

                        Spacer(minLength: 0)

                        Text(verbatim: "\(filteredShortcutCount)")
                            .font(.headline.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }

                    if filteredSystemShortcutSections.isEmpty {
                        messageCard(
                            title: AssistantLocalized.text(zh: "没有匹配的快捷键", en: "No Matching Shortcuts"),
                            body: AssistantLocalized.text(
                                zh: "可以搜索功能名称、分类或按键组合，例如 Finder、截图、Command Space。",
                                en: "Search by command name, category, or key combination, such as Finder, screenshot, or Command Space."
                            )
                        )
                    } else {
                        LazyVGrid(
                            columns: [
                                GridItem(.adaptive(minimum: 250, maximum: 360), spacing: 14, alignment: .top)
                            ],
                            alignment: .leading,
                            spacing: 14
                        ) {
                            ForEach(filteredSystemShortcutSections) { section in
                                sectionCard(section)
                            }
                        }
                    }
                }
                .padding(18)
            }
        }
        .frame(minWidth: 680, minHeight: 520)
    }

    private var header: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.indigo.opacity(0.14))
                Image(systemName: "keyboard")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.indigo)
            }
            .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 4) {
                Text(AssistantLocalized.text(zh: "快捷键助手", en: "Shortcut Assistant"))
                    .font(.title2.weight(.semibold))
                Text(
                    AssistantLocalized.text(
                        zh: "搜索和查看 macOS 常用系统快捷键，无需额外权限。",
                        en: "Search and browse common macOS system shortcuts. No extra permissions are required."
                    )
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.borderless)
        }
        .padding(18)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(
                AssistantLocalized.text(zh: "搜索系统快捷键或按键组合", en: "Search system shortcuts or keys"),
                text: $searchText
            )
            .textFieldStyle(.plain)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .help(AssistantLocalized.text(zh: "清空搜索", en: "Clear search"))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.secondary.opacity(0.16), lineWidth: 1)
        )
    }

    private var filteredSystemShortcutSections: [ShortcutAssistantSection] {
        let query = searchText.normalizedShortcutSearchQuery
        guard !query.isEmpty else {
            return systemShortcutSections
        }

        return systemShortcutSections.compactMap { section in
            let items = section.items.filter { item in
                item.matchesSearchQuery(query, sectionTitle: section.title)
            }

            guard !items.isEmpty else {
                return nil
            }

            return ShortcutAssistantSection(
                id: section.id,
                title: section.title,
                icon: section.icon,
                items: items
            )
        }
    }

    private var filteredShortcutCount: Int {
        filteredSystemShortcutSections.reduce(0) { $0 + $1.items.count }
    }

    private func sectionCard(_ section: ShortcutAssistantSection) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(section.title, systemImage: section.icon)
                .font(.headline)

            VStack(spacing: 8) {
                ForEach(section.items) { item in
                    HStack(spacing: 10) {
                        Text(item.name)
                            .font(.subheadline)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        keyCaps(item.keys)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func sectionHeader(title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.title3.weight(.semibold))
    }

    private func keyCaps(_ keys: [String]) -> some View {
        HStack(spacing: 4) {
            ForEach(keys, id: \.self) { key in
                Text(key)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .frame(minWidth: 28, minHeight: 24)
                    .padding(.horizontal, key.count > 1 ? 6 : 0)
                    .background(Color(NSColor.windowBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
                    )
            }
        }
    }

    private func messageCard(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
            Text(body)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private extension String {
    var normalizedShortcutSearchQuery: String {
        folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .replacingOccurrences(of: "command", with: "cmd")
            .replacingOccurrences(of: "option", with: "opt")
            .replacingOccurrences(of: "control", with: "ctrl")
            .replacingOccurrences(of: "shift", with: "shift")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "+", with: "")
            .lowercased()
    }
}

private extension Array where Element == String {
    var shortcutSearchAliasText: String {
        map { key in
            switch key {
            case "⌘":
                "command cmd"
            case "⌥":
                "option opt alt"
            case "⌃":
                "control ctrl"
            case "⇧":
                "shift"
            case "⌫":
                "delete backspace"
            case "↩":
                "return enter"
            default:
                key
            }
        }
        .joined(separator: " ")
    }
}

#Preview {
    ShortcutAssistantView(onClose: {})
}
