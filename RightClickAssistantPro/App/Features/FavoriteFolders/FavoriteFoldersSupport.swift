//
//  FavoriteFoldersSupport.swift
//  RightClickAssistantPro
//
//  Created by 老谭 on 2026/4/30.
//

import AppKit
import SwiftUI

struct FavoriteFolderSummary {
    let count: Int

    init(items: [FavoriteDirectory]) {
        count = items.count
    }

    var headline: String {
        AssistantLocalized.text(zh: "共 \(count) 个常用目录", en: "\(count) favorite folders")
    }

    var detail: String {
        AssistantLocalized.text(
            zh: "这些目录会直接出现在右键菜单里，适合放常访问路径。",
            en: "These folders appear directly in the context menu for quick access."
        )
    }

    var isEmpty: Bool {
        count == 0
    }
}

enum FavoriteFoldersMutationCoordinator {
    @MainActor
    @discardableResult
    static func insert(_ url: URL, into state: AssistantRuntimeState) throws -> Bool {
        guard !state.cdirs.contains(where: { $0.url == url }) else {
            return false
        }

        state.cdirs.append(
            FavoriteDirectory(
                id: UUID().uuidString,
                name: url.lastPathComponent,
                url: url,
                icon: "folder"
            )
        )
        try state.saveCommonDir()
        return true
    }

    @MainActor
    @discardableResult
    static func remove(_ item: FavoriteDirectory, from state: AssistantRuntimeState) throws -> Bool {
        guard let index = state.cdirs.firstIndex(of: item) else {
            return false
        }

        state.cdirs.remove(at: index)
        try state.saveCommonDir()
        return true
    }
}

struct FavoriteFolderCard: View {
    let directory: FavoriteDirectory
    let removeAction: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "folder")
                .foregroundStyle(Color.accentColor)

            VStack(alignment: .leading, spacing: 4) {
                Text(directory.name)
                    .font(.headline)
                Text(verbatim: directory.displayPath)
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
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
