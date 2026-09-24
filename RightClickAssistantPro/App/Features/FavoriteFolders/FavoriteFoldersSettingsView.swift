//
//  FavoriteFoldersSettingsView.swift
//  RightClickAssistantPro
//
//  Created by 老谭 on 2026/4/30.
//

import SwiftUI
import UniformTypeIdentifiers

struct FavoriteFoldersSettingsView: View {
    @AssistantLogger(category: "settings-general")
    private var logger

    @EnvironmentObject private var store: AssistantRuntimeState
    @State private var showCommonDirImporter = false

    private var summary: FavoriteFolderSummary {
        FavoriteFolderSummary(items: store.cdirs)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                folderContent
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 8)
        }
        .fileImporter(
            isPresented: $showCommonDirImporter,
            allowedContentTypes: [.directory],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                addCommonDirectory(url)
            case .failure(let error):
                logger.error("Failed to select common folder: \(error.localizedDescription)")
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(summary.headline)
                    .font(.headline)
                Text(summary.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Button {
                showCommonDirImporter = true
            } label: {
                Label(AssistantLocalized.text(zh: "添加目录", en: "Add Folder"), systemImage: "folder.badge.plus")
            }
        }
    }

    @ViewBuilder
    private var folderContent: some View {
        if summary.isEmpty {
            VStack(alignment: .center, spacing: 10) {
                Image(systemName: "folder.badge.questionmark")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.secondary)

                Text(AssistantLocalized.text(zh: "暂无常用目录", en: "No Favorite Folders"))
                    .font(.headline)

                Text(
                    AssistantLocalized.text(
                        zh: "添加后可以从右键菜单直接打开常用目录。",
                        en: "Add folders here to open frequently used locations from the context menu."
                    )
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 36)
        } else {
            LazyVStack(spacing: 12) {
                ForEach(store.cdirs) { item in
                    FavoriteFolderCard(directory: item) {
                        removeFavoriteFolder(item)
                    }
                }
            }
        }
    }

    @MainActor
    private func addCommonDirectory(_ url: URL) {
        do {
            _ = try FavoriteFoldersMutationCoordinator.insert(url, into: store)
        } catch {
            logger.error("Failed to persist common folders: \(error.localizedDescription)")
        }
    }

    @MainActor
    private func removeFavoriteFolder(_ item: FavoriteDirectory) {
        do {
            _ = try FavoriteFoldersMutationCoordinator.remove(item, from: store)
        } catch {
            logger.error("Failed to persist common folders: \(error.localizedDescription)")
        }
    }
}
