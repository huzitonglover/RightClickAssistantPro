import AppKit
import CryptoKit
import SwiftUI
import UniformTypeIdentifiers

struct DirectoryAccessSnapshot: Sendable {
    let rootPath: String
    let bookmark: Data
}

struct FileInfoHashUpdate: Sendable {
    let path: String
    let md5: String?
    let sha256: String?
}

private struct DirectoryContentSummary: Sendable {
    let totalBytes: Int64
    let directItemCount: Int
    let directFileCount: Int
    let directFolderCount: Int
}

struct FileInfoCenterItem: Identifiable, Sendable {
    let name: String
    let path: String
    let typeDescription: String
    let kindDescription: String
    let sizeDescription: String
    let createdDescription: String
    let modifiedDescription: String
    var md5: String?
    var sha256: String?
    var isHashPending: Bool
    let childCountDescription: String?

    var id: String { path }

    var summaryText: String {
        var lines = [
            "\(AssistantLocalized.text(zh: "名称", en: "Name")): \(name)",
            "\(AssistantLocalized.text(zh: "类型", en: "Type")): \(typeDescription)",
            "\(AssistantLocalized.text(zh: "路径", en: "Path")): \(path)",
            "\(AssistantLocalized.text(zh: "大小", en: "Size")): \(sizeDescription)",
            "\(AssistantLocalized.text(zh: "创建时间", en: "Created")): \(createdDescription)",
            "\(AssistantLocalized.text(zh: "修改时间", en: "Modified")): \(modifiedDescription)"
        ]

        if let childCountDescription {
            lines.append("\(AssistantLocalized.text(zh: "包含项目", en: "Items")): \(childCountDescription)")
        }

        if let md5 {
            lines.append("MD5: \(md5)")
        }

        if let sha256 {
            lines.append("SHA256: \(sha256)")
        }

        return lines.joined(separator: "\n")
    }
}

enum FileInfoLoader {
    static func loadMetadata(paths: [String], directories: [DirectoryAccessSnapshot]) throws -> [FileInfoCenterItem] {
        let normalizedDirectories = directories.sorted(by: { $0.rootPath.count > $1.rootPath.count })

        return try paths
            .map { $0.removingPercentEncoding ?? $0 }
            .filter { !$0.isEmpty }
            .map {
                try Task.checkCancellation()
                return try loadMetadataItem(atPath: $0, directories: normalizedDirectories)
            }
    }

    static func loadHashUpdates(paths: [String], directories: [DirectoryAccessSnapshot]) throws -> [FileInfoHashUpdate] {
        let normalizedDirectories = directories.sorted(by: { $0.rootPath.count > $1.rootPath.count })
        var updates: [FileInfoHashUpdate] = []
        updates.reserveCapacity(paths.count)

        for rawPath in paths {
            try Task.checkCancellation()

            let path = rawPath.removingPercentEncoding ?? rawPath
            guard !path.isEmpty else {
                continue
            }

            updates.append(loadHashUpdate(atPath: path, directories: normalizedDirectories))
        }

        return updates
    }

    private static func loadMetadataItem(atPath path: String, directories: [DirectoryAccessSnapshot]) throws -> FileInfoCenterItem {
        let url = URL(fileURLWithPath: path)
        let stopAccess = startReadableAccess(forPath: path, directories: directories)
        defer { stopAccess?() }

        let resourceKeys: Set<URLResourceKey> = [
            .isDirectoryKey,
            .localizedTypeDescriptionKey,
            .creationDateKey,
            .contentModificationDateKey,
            .fileSizeKey
        ]

        let values = try url.resourceValues(forKeys: resourceKeys)
        let isDirectory = values.isDirectory ?? false
        let typeDescription = values.localizedTypeDescription ?? fallbackTypeDescription(for: url, isDirectory: isDirectory)
        let kindDescription = isDirectory
            ? AssistantLocalized.text(zh: "文件夹", en: "Folder")
            : AssistantLocalized.text(zh: "文件", en: "File")
        let createdDescription = format(date: values.creationDate)
        let modifiedDescription = format(date: values.contentModificationDate)

        if isDirectory {
            let summary = try directoryContentSummary(for: url)
            return FileInfoCenterItem(
                name: url.lastPathComponent,
                path: path,
                typeDescription: typeDescription,
                kindDescription: kindDescription,
                sizeDescription: format(bytes: summary.totalBytes),
                createdDescription: createdDescription,
                modifiedDescription: modifiedDescription,
                md5: nil,
                sha256: nil,
                isHashPending: false,
                childCountDescription: format(directoryContentSummary: summary)
            )
        }

        let sizeDescription = format(bytes: values.fileSize)

        return FileInfoCenterItem(
            name: url.lastPathComponent,
            path: path,
            typeDescription: typeDescription,
            kindDescription: kindDescription,
            sizeDescription: sizeDescription,
            createdDescription: createdDescription,
            modifiedDescription: modifiedDescription,
            md5: nil,
            sha256: nil,
            isHashPending: true,
            childCountDescription: nil
        )
    }

    private static func loadHashUpdate(atPath path: String, directories: [DirectoryAccessSnapshot]) -> FileInfoHashUpdate {
        let url = URL(fileURLWithPath: path)
        let stopAccess = startReadableAccess(forPath: path, directories: directories)
        defer { stopAccess?() }

        do {
            let hashes = try calculateHashes(for: url)
            return FileInfoHashUpdate(path: path, md5: hashes.md5, sha256: hashes.sha256)
        } catch {
            return FileInfoHashUpdate(path: path, md5: nil, sha256: nil)
        }
    }

    private static func fallbackTypeDescription(for url: URL, isDirectory: Bool) -> String {
        if isDirectory {
            return AssistantLocalized.text(zh: "文件夹", en: "Folder")
        }

        if let utType = UTType(filenameExtension: url.pathExtension),
           let description = utType.localizedDescription {
            return description
        }

        return url.pathExtension.isEmpty
            ? AssistantLocalized.text(zh: "未知文件", en: "Unknown File")
            : AssistantLocalized.text(zh: "\(url.pathExtension.uppercased()) 文件", en: "\(url.pathExtension.uppercased()) File")
    }

    private static func format(date: Date?) -> String {
        guard let date else { return AssistantLocalized.text(zh: "未知", en: "Unknown") }
        return sharedDateFormatter.string(from: date)
    }

    private static func format(bytes: Int?) -> String {
        guard let bytes else { return AssistantLocalized.text(zh: "未知", en: "Unknown") }
        return sharedByteCountFormatter.string(fromByteCount: Int64(bytes))
    }

    private static func format(bytes: Int64) -> String {
        sharedByteCountFormatter.string(fromByteCount: bytes)
    }

    private static func format(directoryContentSummary summary: DirectoryContentSummary) -> String {
        if summary.directItemCount == 0 {
            return AssistantLocalized.text(zh: "空文件夹", en: "Empty Folder")
        }

        if summary.directFileCount > 0, summary.directFolderCount > 0 {
            return AssistantLocalized.text(
                zh: "\(summary.directItemCount) 项（\(summary.directFileCount) 个文件，\(summary.directFolderCount) 个文件夹）",
                en: "\(summary.directItemCount) items (\(summary.directFileCount) files, \(summary.directFolderCount) folders)"
            )
        }

        if summary.directFolderCount > 0 {
            return AssistantLocalized.text(
                zh: "\(summary.directFolderCount) 个文件夹",
                en: "\(summary.directFolderCount) folders"
            )
        }

        return AssistantLocalized.text(
            zh: "\(summary.directFileCount) 个文件",
            en: "\(summary.directFileCount) files"
        )
    }

    private static func directoryContentSummary(for directoryURL: URL) throws -> DirectoryContentSummary {
        let fileManager = FileManager.default
        let directChildKeys: Set<URLResourceKey> = [
            .isDirectoryKey,
            .isSymbolicLinkKey
        ]

        let directChildren = try fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: Array(directChildKeys),
            options: []
        )

        var directFileCount = 0
        var directFolderCount = 0

        for childURL in directChildren {
            try Task.checkCancellation()

            let values = try childURL.resourceValues(forKeys: directChildKeys)
            if values.isSymbolicLink == true {
                directFileCount += 1
                continue
            }

            if values.isDirectory == true {
                directFolderCount += 1
            } else {
                directFileCount += 1
            }
        }

        let recursiveKeys: Set<URLResourceKey> = [
            .isDirectoryKey,
            .isSymbolicLinkKey,
            .fileSizeKey,
            .totalFileAllocatedSizeKey,
            .fileAllocatedSizeKey
        ]

        let enumerator = fileManager.enumerator(
            at: directoryURL,
            includingPropertiesForKeys: Array(recursiveKeys),
            options: [],
            errorHandler: { _, _ in true }
        )

        var totalBytes: Int64 = 0

        while let nextURL = enumerator?.nextObject() as? URL {
            try Task.checkCancellation()

            let values = try nextURL.resourceValues(forKeys: recursiveKeys)

            if values.isSymbolicLink == true {
                if values.isDirectory == true {
                    enumerator?.skipDescendants()
                }
                continue
            }

            guard values.isDirectory != true else {
                continue
            }

            if let allocatedSize = values.totalFileAllocatedSize ?? values.fileAllocatedSize {
                totalBytes += Int64(allocatedSize)
            } else if let fileSize = values.fileSize {
                totalBytes += Int64(fileSize)
            }
        }

        return DirectoryContentSummary(
            totalBytes: totalBytes,
            directItemCount: directChildren.count,
            directFileCount: directFileCount,
            directFolderCount: directFolderCount
        )
    }

    private static func calculateHashes(for url: URL) throws -> (md5: String, sha256: String) {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        var md5Hasher = Insecure.MD5()
        var sha256Hasher = SHA256()
        let chunkSize = 1_048_576

        while true {
            try Task.checkCancellation()

            let data = try autoreleasepool { () throws -> Data in
                try handle.read(upToCount: chunkSize) ?? Data()
            }

            guard !data.isEmpty else {
                break
            }

            md5Hasher.update(data: data)
            sha256Hasher.update(data: data)
        }

        let md5 = md5Hasher.finalize().map { String(format: "%02x", $0) }.joined()
        let sha256 = sha256Hasher.finalize().map { String(format: "%02x", $0) }.joined()
        return (md5, sha256)
    }

    private static let sharedDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    private static let sharedByteCountFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter
    }()

    private static func startReadableAccess(forPath path: String, directories: [DirectoryAccessSnapshot]) -> (() -> Void)? {
        guard let snapshot = directories.first(where: { snapshot in
                let prefix = snapshot.rootPath.hasSuffix("/") ? snapshot.rootPath : snapshot.rootPath + "/"
                return path == snapshot.rootPath || path.hasPrefix(prefix)
            })
        else {
            return nil
        }

        var isStale = false
        do {
            let scopedURL = try URL(
                resolvingBookmarkData: snapshot.bookmark,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            if scopedURL.startAccessingSecurityScopedResource() {
                return { scopedURL.stopAccessingSecurityScopedResource() }
            }
        } catch {
            return nil
        }

        return nil
    }
}

@MainActor
final class FileInfoCenterViewModel: ObservableObject {
    @Published var items: [FileInfoCenterItem] = []
    @Published var isLoading = true
    @Published var errorMessage: String?
    private var loadTask: Task<Void, Never>?
    private var hashTask: Task<Void, Never>?

    var summaryText: String {
        items.map(\.summaryText).joined(separator: "\n\n")
    }

    deinit {
        loadTask?.cancel()
        hashTask?.cancel()
    }

    func load(paths: [String], directories: [DirectoryAccessSnapshot]) {
        loadTask?.cancel()
        hashTask?.cancel()
        isLoading = true
        errorMessage = nil

        loadTask = Task {
            do {
                let loadedItems = try await Task.detached(priority: .userInitiated) {
                    try FileInfoLoader.loadMetadata(paths: paths, directories: directories)
                }.value
                try Task.checkCancellation()
                items = loadedItems
                isLoading = false
                scheduleHashLoadingIfNeeded(for: loadedItems, directories: directories)
            } catch is CancellationError {
                return
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }

    func copySummary() {
        copyText(
            summaryText,
            successMessage: AssistantLocalized.text(zh: "文件摘要已复制到剪贴板。", en: "The file summary was copied to the clipboard.")
        )
    }

    func copyField(_ value: String, title: String) {
        copyText(
            value,
            successMessage: AssistantLocalized.text(zh: "\(title)已复制到剪贴板。", en: "\(title) was copied to the clipboard.")
        )
    }

    private func copyText(_ value: String, successMessage: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let succeeded = pasteboard.setString(value, forType: .string)

        AssistantBannerNotificationCenter.shared.post(
            title: succeeded
                ? AssistantLocalized.text(zh: "复制成功", en: "Copied")
                : AssistantLocalized.text(zh: "复制失败", en: "Copy Failed"),
            body: succeeded
                ? successMessage
                : AssistantLocalized.text(zh: "未能写入剪贴板，请稍后再试。", en: "Failed to write to the clipboard. Please try again later.")
        )
    }

    private func scheduleHashLoadingIfNeeded(for items: [FileInfoCenterItem], directories: [DirectoryAccessSnapshot]) {
        let hashPaths = items.compactMap { $0.isHashPending ? $0.path : nil }
        guard !hashPaths.isEmpty else { return }

        hashTask = Task {
            do {
                let updates = try await Task.detached(priority: .utility) {
                    try FileInfoLoader.loadHashUpdates(paths: hashPaths, directories: directories)
                }.value

                guard !Task.isCancelled else { return }
                applyHashUpdates(updates)
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                applyHashUpdates(
                    hashPaths.map { FileInfoHashUpdate(path: $0, md5: nil, sha256: nil) }
                )
            }
        }
    }

    private func applyHashUpdates(_ updates: [FileInfoHashUpdate]) {
        guard !updates.isEmpty else {
            return
        }

        let itemIndexByPath = Dictionary(
            uniqueKeysWithValues: items.enumerated().map { ($0.element.path, $0.offset) }
        )

        for update in updates {
            guard let index = itemIndexByPath[update.path] else {
                continue
            }

            items[index].md5 = update.md5
            items[index].sha256 = update.sha256
            items[index].isHashPending = false
        }
    }
}

struct FileInfoCenterView: View {
    @ObservedObject var viewModel: FileInfoCenterViewModel
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .frame(minWidth: 720, minHeight: 560)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(AssistantLocalized.text(zh: "文件信息中心", en: "File Info Center"))
                    .font(.system(size: 28, weight: .semibold))
                Text(
                    viewModel.items.isEmpty
                        ? AssistantLocalized.text(zh: "查看文件和文件夹的核心信息", en: "Inspect core details for files and folders")
                        : AssistantLocalized.text(zh: "共 \(viewModel.items.count) 个项目", en: "\(viewModel.items.count) item(s)")
                )
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(AssistantLocalized.text(zh: "复制摘要", en: "Copy Summary")) {
                viewModel.copySummary()
            }
            .disabled(viewModel.items.isEmpty)

            Button(AssistantLocalized.text(zh: "关闭", en: "Close")) {
                onClose()
            }
            .keyboardShortcut(.escape)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading {
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.1)
                Text(AssistantLocalized.text(zh: "正在读取文件信息...", en: "Loading file information..."))
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let errorMessage = viewModel.errorMessage {
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 28))
                    .foregroundStyle(.yellow)
                Text(AssistantLocalized.text(zh: "读取文件信息失败", en: "Failed to Load File Information"))
                    .font(.title3)
                    .fontWeight(.semibold)
                Text(errorMessage)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(24)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(viewModel.items) { item in
                        fileCard(item)
                    }
                }
                .padding(24)
            }
            .textSelection(.enabled)
        }
    }

    @ViewBuilder
    private func fileCard(_ item: FileInfoCenterItem) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                Image(nsImage: AssistantFileIconCache.icon(forPath: item.path))
                    .resizable()
                    .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text(item.kindDescription)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                infoRow(title: AssistantLocalized.text(zh: "类型", en: "Type"), value: item.typeDescription)
                infoRow(title: AssistantLocalized.text(zh: "路径", en: "Path"), value: item.path, copyValue: item.path)
                infoRow(title: AssistantLocalized.text(zh: "大小", en: "Size"), value: item.sizeDescription)
                infoRow(title: AssistantLocalized.text(zh: "创建时间", en: "Created"), value: item.createdDescription)
                infoRow(title: AssistantLocalized.text(zh: "修改时间", en: "Modified"), value: item.modifiedDescription)

                if let childCountDescription = item.childCountDescription {
                    infoRow(title: AssistantLocalized.text(zh: "包含项目", en: "Items"), value: childCountDescription)
                }

                if item.isHashPending {
                    infoRow(title: "MD5", value: AssistantLocalized.text(zh: "计算中...", en: "Calculating..."))
                    infoRow(title: "SHA256", value: AssistantLocalized.text(zh: "计算中...", en: "Calculating..."))
                } else {
                    if let md5 = item.md5 {
                        infoRow(title: "MD5", value: md5, copyValue: md5)
                    }

                    if let sha256 = item.sha256 {
                        infoRow(title: "SHA256", value: sha256, copyValue: sha256)
                    }
                }
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private func infoRow(title: String, value: String, copyValue: String? = nil) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .foregroundStyle(.secondary)
                .frame(width: 72, alignment: .leading)

            Text(value)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let copyValue {
                Button(AssistantLocalized.text(zh: "复制", en: "Copy")) {
                    viewModel.copyField(copyValue, title: title)
                }
                .buttonStyle(.borderless)
            }
        }
        .font(.body)
    }
}

#Preview {
    let model = FileInfoCenterViewModel()
    model.items = [
        FileInfoCenterItem(
            name: "example.txt",
            path: "/Users/example/Desktop/example.txt",
            typeDescription: "纯文本文件",
            kindDescription: "文件",
            sizeDescription: "24 KB",
            createdDescription: "2026-04-29 18:00:00",
            modifiedDescription: "2026-04-29 18:01:00",
            md5: "3b5d5c3712955042212316173ccf37be",
            sha256: "50d858e0985ecc7f60418aaf0cc5ab587f42c2570a884095a9e8ccacd0f6545c",
            isHashPending: false,
            childCountDescription: nil
        )
    ]

    return FileInfoCenterView(viewModel: model, onClose: {})
}
