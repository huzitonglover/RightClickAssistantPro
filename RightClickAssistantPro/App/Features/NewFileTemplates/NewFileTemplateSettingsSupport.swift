//
//  NewFileTemplateSettingsSupport.swift
//  RightClickAssistantPro
//
//  Created by 老谭 on 2026/4/30.
//

import AppKit
import OSLog
import SwiftUI

enum TemplateLibrary {
    private static let fileManager = FileManager.default

    static var rootDirectory: URL? {
        fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("RightClickAssistantPro/TemplateLibrary", isDirectory: true)
    }

    static func storeCopy(
        source: URL?,
        keeping existingURL: URL?,
        logger: AssistantRuntimeLogger
    ) -> URL? {
        guard let source else {
            removeManagedCopy(at: existingURL, logger: logger)
            return nil
        }

        if source == existingURL {
            return existingURL
        }

        guard let rootDirectory else {
            logger.error("Template library root directory is unavailable.")
            return existingURL
        }

        do {
            try fileManager.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
            let destination = rootDirectory.appendingPathComponent("\(UUID().uuidString)-\(source.lastPathComponent)")
            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }
            try fileManager.copyItem(at: source, to: destination)
            removeManagedCopy(at: existingURL, excluding: destination, logger: logger)
            return destination
        } catch {
            logger.error("Failed to store template copy: \(error.localizedDescription)")
            return existingURL
        }
    }

    static func removeManagedCopy(
        at url: URL?,
        excluding preservedURL: URL? = nil,
        logger: AssistantRuntimeLogger
    ) {
        guard let url,
              url != preservedURL,
              let rootDirectory,
              url.path.hasPrefix(rootDirectory.path),
              fileManager.fileExists(atPath: url.path)
        else {
            return
        }

        do {
            try fileManager.removeItem(at: url)
        } catch {
            logger.error("Failed to remove stale template copy: \(error.localizedDescription)")
        }
    }
}

struct NewFileTemplateRow: View {
    @Binding var item: NewFileTemplate
    @State private var isEditingName = false
    @FocusState private var isNameFieldFocused: Bool

    let columns: [GridItem]
    let showIconImage: Bool
    let isSelected: Bool
    let onSelect: () -> Void
    let onChanged: () -> Void
    let onDelete: () -> Void

    var body: some View {
        ZStack {
            Rectangle()
                .fill(isSelected ? Color.accentColor.opacity(0.18) : Color.clear)

            LazyVGrid(columns: columns, spacing: 0) {
                Toggle("", isOn: $item.enabled)
                    .labelsHidden()
                    .toggleStyle(.checkbox)
                    .onChange(of: item.enabled) { _ in onChanged() }

                TemplateIconPreview(template: item, showIconImage: showIconImage)

                nameEditor

                Text(item.suffixDisplayText)
                    .font(.body.monospacedDigit())
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
        }
        .frame(height: 48)
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .contextMenu {
            if !item.id.hasPrefix("builtin-newfile-") {
                Button(role: .destructive, action: onDelete) {
                    Text(AssistantLocalized.text(zh: "删除", en: "Delete"))
                }
            }
        }
    }

    @ViewBuilder
    private var nameEditor: some View {
        if isEditingName {
            TextField("", text: $item.name)
                .textFieldStyle(.roundedBorder)
                .focused($isNameFieldFocused)
                .onSubmit(finishNameEditing)
                .onChange(of: item.name) { _ in onChanged() }
                .onChange(of: isNameFieldFocused) { focused in
                    if !focused {
                        finishNameEditing()
                    }
                }
                .onAppear {
                    isNameFieldFocused = true
                }
        } else {
            Text(item.displayName)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture(count: 2) {
                    onSelect()
                    beginNameEditing()
                }
                .onTapGesture {
                    onSelect()
                }
        }
    }

    private func beginNameEditing() {
        isEditingName = true
    }

    private func finishNameEditing() {
        guard isEditingName else { return }
        let trimmedName = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty {
            item.name = AssistantLocalized.text(zh: "未命名模版", en: "Untitled Template")
        } else if trimmedName != item.name {
            item.name = trimmedName
        }
        isEditingName = false
        onChanged()
    }
}

struct TemplateIconPreview: View {
    let template: NewFileTemplate
    let showIconImage: Bool

    var body: some View {
        Group {
            if showIconImage {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "doc")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 34, height: 34)
    }

    private var icon: NSImage {
        if let templateURL = template.template {
            return AssistantFileIconCache.icon(forPath: templateURL.path)
        }

        let temporaryPath = NSTemporaryDirectory()
            .appending("assistant-template-icon")
            .appending(template.ext)
        return AssistantFileIconCache.icon(forPath: temporaryPath)
    }
}

private extension NewFileTemplate {
    var suffixDisplayText: String {
        ext.trimmingCharacters(in: CharacterSet(charactersIn: "."))
    }
}
