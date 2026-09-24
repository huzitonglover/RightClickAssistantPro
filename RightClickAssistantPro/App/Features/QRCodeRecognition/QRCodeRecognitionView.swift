//
//  QRCodeRecognitionView.swift
//  RightClickAssistantPro
//
//  Created by 老谭 on 2026/4/30.
//

import AppKit
import ImageIO
import SwiftUI
import UniformTypeIdentifiers
import Vision

struct QRCodeRecognitionPayload: Identifiable, Hashable, Sendable {
    let id: String
    let content: String

    init(content: String, sourcePath: String, index: Int) {
        self.id = "\(sourcePath)#\(index)#\(content)"
        self.content = content
    }

    var browserURL: URL? {
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmedContent),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            return nil
        }

        return url
    }
}

struct QRCodeRecognitionItem: Identifiable, Sendable {
    let path: String
    let displayName: String
    let payloads: [QRCodeRecognitionPayload]
    let statusMessage: String?

    var id: String { path }

    var hasPayloads: Bool {
        !payloads.isEmpty
    }
}

enum QRCodeRecognitionLoader {
    static func recognize(
        paths: [String],
        directories: [AuthorizedDirectoryAccessSnapshot]
    ) throws -> [QRCodeRecognitionItem] {
        let sortedDirectories = directories.sorted(by: { $0.rootPath.count > $1.rootPath.count })
        var seenPaths: Set<String> = []
        var results: [QRCodeRecognitionItem] = []

        for rawPath in paths {
            try Task.checkCancellation()

            let path = rawPath.removingPercentEncoding ?? rawPath
            guard !path.isEmpty, seenPaths.insert(path).inserted else {
                continue
            }

            results.append(recognizeSingleItem(atPath: path, directories: sortedDirectories))
        }

        return results
    }

    private static func recognizeSingleItem(
        atPath path: String,
        directories: [AuthorizedDirectoryAccessSnapshot]
    ) -> QRCodeRecognitionItem {
        let url = URL(fileURLWithPath: path)
        let displayName = url.lastPathComponent.isEmpty ? path : url.lastPathComponent

        if isDirectory(atPath: path) {
            return QRCodeRecognitionItem(
                path: path,
                displayName: displayName,
                payloads: [],
                statusMessage: AssistantLocalized.text(zh: "文件夹暂不支持二维码识别。", en: "Folders are not supported for QR code recognition.")
            )
        }

        let stopAccess = startReadableAccess(forPath: path, directories: directories)
        defer { stopAccess?() }

        guard FileManager.default.fileExists(atPath: path) else {
            return QRCodeRecognitionItem(
                path: path,
                displayName: displayName,
                payloads: [],
                statusMessage: AssistantLocalized.text(zh: "文件不存在或已被移动。", en: "The file does not exist or has been moved.")
            )
        }

        guard isSupportedImage(at: url) else {
            return QRCodeRecognitionItem(
                path: path,
                displayName: displayName,
                payloads: [],
                statusMessage: AssistantLocalized.text(zh: "当前仅支持图片文件识别二维码。", en: "Only image files are supported for QR code recognition.")
            )
        }

        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return QRCodeRecognitionItem(
                path: path,
                displayName: displayName,
                payloads: [],
                statusMessage: AssistantLocalized.text(zh: "无法读取图片内容。", en: "The image content could not be read.")
            )
        }

        let imageCount = CGImageSourceGetCount(source)
        guard imageCount > 0 else {
            return QRCodeRecognitionItem(
                path: path,
                displayName: displayName,
                payloads: [],
                statusMessage: AssistantLocalized.text(zh: "图片内容为空。", en: "The image content is empty.")
            )
        }

        var uniquePayloads: [String] = []
        var seenPayloads: Set<String> = []
        let maxFrameCount = min(imageCount, 8)

        for index in 0 ..< maxFrameCount {
            guard let cgImage = CGImageSourceCreateImageAtIndex(source, index, nil) else {
                continue
            }

            let payloads = detectPayloads(in: cgImage)
            for payload in payloads {
                let trimmedPayload = payload.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedPayload.isEmpty, seenPayloads.insert(trimmedPayload).inserted else {
                    continue
                }
                uniquePayloads.append(trimmedPayload)
            }
        }

        return QRCodeRecognitionItem(
            path: path,
            displayName: displayName,
            payloads: uniquePayloads.enumerated().map {
                QRCodeRecognitionPayload(content: $0.element, sourcePath: path, index: $0.offset)
            },
            statusMessage: uniquePayloads.isEmpty ? AssistantLocalized.text(zh: "未识别到二维码。", en: "No QR code was detected.") : nil
        )
    }

    private static func detectPayloads(in image: CGImage) -> [String] {
        let request = VNDetectBarcodesRequest()
        request.symbologies = [.qr]

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        do {
            try handler.perform([request])
            return request.results?.compactMap(\.payloadStringValue) ?? []
        } catch {
            return []
        }
    }

    private static func isSupportedImage(at url: URL) -> Bool {
        guard let type = UTType(filenameExtension: url.pathExtension) else {
            return false
        }
        return type.conforms(to: .image)
    }

    private static func isDirectory(atPath path: String) -> Bool {
        var isDirectoryFlag: ObjCBool = false
        FileManager.default.fileExists(atPath: path, isDirectory: &isDirectoryFlag)
        return isDirectoryFlag.boolValue
    }

    private static func startReadableAccess(
        forPath path: String,
        directories: [AuthorizedDirectoryAccessSnapshot]
    ) -> (() -> Void)? {
        guard let directory = directories.first(where: { snapshot in
            let prefix = snapshot.rootPath.hasSuffix("/") ? snapshot.rootPath : snapshot.rootPath + "/"
            return path == snapshot.rootPath || path.hasPrefix(prefix)
        }) else {
            return nil
        }

        var isStale = false
        do {
            let scopedURL = try URL(
                resolvingBookmarkData: directory.bookmark,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            guard scopedURL.startAccessingSecurityScopedResource() else {
                return nil
            }

            return { scopedURL.stopAccessingSecurityScopedResource() }
        } catch {
            return nil
        }
    }
}

@MainActor
final class QRCodeRecognitionViewModel: ObservableObject {
    @Published var items: [QRCodeRecognitionItem] = []
    @Published var isLoading = true
    @Published var errorMessage: String?

    private var loadTask: Task<Void, Never>?

    var recognizedItems: [QRCodeRecognitionItem] {
        items.filter(\.hasPayloads)
    }

    var skippedItems: [QRCodeRecognitionItem] {
        items.filter { !$0.hasPayloads }
    }

    var totalPayloadCount: Int {
        items.reduce(into: 0) { result, item in
            result += item.payloads.count
        }
    }

    var summaryText: String {
        if isLoading {
            return AssistantLocalized.text(zh: "正在识别选中文件中的二维码。", en: "Recognizing QR codes from the selected files.")
        }

        if let errorMessage {
            return errorMessage
        }

        if items.isEmpty {
            return AssistantLocalized.text(zh: "没有可识别的文件。", en: "There are no files available to scan.")
        }

        if totalPayloadCount == 0 {
            return AssistantLocalized.text(zh: "已扫描 \(items.count) 个文件，未识别到二维码。", en: "Scanned \(items.count) file(s) and found no QR code.")
        }

        return AssistantLocalized.text(zh: "已扫描 \(items.count) 个文件，识别到 \(totalPayloadCount) 条二维码内容。", en: "Scanned \(items.count) file(s) and recognized \(totalPayloadCount) QR result(s).")
    }

    func load(paths: [String], directories: [AuthorizedDirectoryAccessSnapshot]) {
        loadTask?.cancel()
        isLoading = true
        errorMessage = nil
        items = []

        loadTask = Task.detached(priority: .userInitiated) {
            do {
                let results = try QRCodeRecognitionLoader.recognize(paths: paths, directories: directories)
                await MainActor.run {
                    self.items = results
                    self.isLoading = false
                }
            } catch is CancellationError {
                await MainActor.run {
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.items = []
                    self.errorMessage = AssistantLocalized.text(zh: "识别失败：\(error.localizedDescription)", en: "Recognition failed: \(error.localizedDescription)")
                    self.isLoading = false
                }
            }
        }
    }

    deinit {
        loadTask?.cancel()
    }
}

struct QRCodeRecognitionView: View {
    @ObservedObject var viewModel: QRCodeRecognitionViewModel
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header

            Group {
                if viewModel.isLoading {
                    loadingState
                } else if let errorMessage = viewModel.errorMessage {
                    messageCard(title: AssistantLocalized.text(zh: "识别失败", en: "Recognition Failed"), body: errorMessage)
                } else {
                    resultContent
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            footer
        }
        .padding(22)
        .frame(minWidth: 760, minHeight: 560)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(AssistantLocalized.text(zh: "识别二维码", en: "Scan QR Code"))
                .font(.title3.weight(.semibold))
            Text(viewModel.summaryText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var loadingState: some View {
        VStack(alignment: .center, spacing: 14) {
            Spacer()
            ProgressView()
                .controlSize(.large)
            Text(AssistantLocalized.text(zh: "正在识别二维码…", en: "Recognizing QR codes..."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var resultContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if !viewModel.recognizedItems.isEmpty {
                    ForEach(viewModel.recognizedItems) { item in
                        recognizedItemCard(item)
                    }
                }

                if !viewModel.skippedItems.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(AssistantLocalized.text(zh: "未识别项目", en: "Unrecognized Items"))
                            .font(.headline)

                        ForEach(viewModel.skippedItems) { item in
                            messageCard(
                                title: item.displayName,
                                body: item.statusMessage ?? AssistantLocalized.text(zh: "未识别到二维码。", en: "No QR code was detected.")
                            )
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .textSelection(.enabled)
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            if viewModel.totalPayloadCount > 0 {
                Button(AssistantLocalized.text(zh: "复制全部结果", en: "Copy All Results")) {
                    copyAllResults()
                }
            }

            Spacer(minLength: 0)

            Button(AssistantLocalized.text(zh: "关闭", en: "Close")) {
                onClose()
            }
            .keyboardShortcut(.defaultAction)
        }
    }

    private func recognizedItemCard(_ item: QRCodeRecognitionItem) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.displayName)
                        .font(.headline)
                    Text(item.path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer(minLength: 0)

                Text(AssistantLocalized.text(zh: "\(item.payloads.count) 条结果", en: "\(item.payloads.count) result(s)"))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            ForEach(Array(item.payloads.enumerated()), id: \.element.id) { index, payload in
                VStack(alignment: .leading, spacing: 10) {
                    Text(AssistantLocalized.text(zh: "识别内容 \(index + 1)", en: "Result \(index + 1)"))
                        .font(.subheadline.weight(.semibold))

                    Text(payload.content)
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(Color(NSColor.controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    HStack(spacing: 10) {
                        Button(AssistantLocalized.text(zh: "复制", en: "Copy")) {
                            copyText(
                                payload.content,
                                successMessage: AssistantLocalized.text(zh: "二维码内容已复制到剪贴板。", en: "The QR content was copied to the clipboard.")
                            )
                        }

                        if let url = payload.browserURL {
                            Button(AssistantLocalized.text(zh: "浏览器打开", en: "Open in Browser")) {
                                NSWorkspace.shared.open(url)
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func messageCard(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(body)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func copyAllResults() {
        let values = viewModel.recognizedItems
            .flatMap(\.payloads)
            .map(\.content)

        guard !values.isEmpty else {
            return
        }

        copyText(
            values.joined(separator: "\n\n"),
            successMessage: AssistantLocalized.text(zh: "全部识别结果已复制到剪贴板。", en: "All recognition results were copied to the clipboard.")
        )
    }

    private func copyText(_ text: String, successMessage: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let succeeded = pasteboard.setString(text, forType: .string)

        AssistantBannerNotificationCenter.shared.post(
            title: succeeded
                ? AssistantLocalized.text(zh: "复制成功", en: "Copied")
                : AssistantLocalized.text(zh: "复制失败", en: "Copy Failed"),
            body: succeeded
                ? successMessage
                : AssistantLocalized.text(zh: "未能写入剪贴板，请稍后再试。", en: "Failed to write to the clipboard. Please try again later.")
        )
    }
}

struct ImageTextRecognitionItem: Identifiable, Sendable {
    let path: String
    let displayName: String
    let recognizedText: String?
    let statusMessage: String?
    let lineCount: Int

    var id: String { path }

    var hasRecognizedText: Bool {
        guard let recognizedText else {
            return false
        }

        return !recognizedText.isEmpty
    }
}

enum ImageTextRecognitionLoader {
    static func recognize(
        paths: [String],
        directories: [AuthorizedDirectoryAccessSnapshot]
    ) throws -> [ImageTextRecognitionItem] {
        let sortedDirectories = directories.sorted(by: { $0.rootPath.count > $1.rootPath.count })
        var seenPaths: Set<String> = []
        var results: [ImageTextRecognitionItem] = []

        for rawPath in paths {
            try Task.checkCancellation()

            let path = rawPath.removingPercentEncoding ?? rawPath
            guard !path.isEmpty, seenPaths.insert(path).inserted else {
                continue
            }

            results.append(recognizeSingleItem(atPath: path, directories: sortedDirectories))
        }

        return results
    }

    private static func recognizeSingleItem(
        atPath path: String,
        directories: [AuthorizedDirectoryAccessSnapshot]
    ) -> ImageTextRecognitionItem {
        let url = URL(fileURLWithPath: path)
        let displayName = url.lastPathComponent.isEmpty ? path : url.lastPathComponent

        if isDirectory(atPath: path) {
            return ImageTextRecognitionItem(
                path: path,
                displayName: displayName,
                recognizedText: nil,
                statusMessage: AssistantLocalized.text(zh: "文件夹暂不支持图片文案提取。", en: "Folders are not supported for image text extraction."),
                lineCount: 0
            )
        }

        let stopAccess = startReadableAccess(forPath: path, directories: directories)
        defer { stopAccess?() }

        guard FileManager.default.fileExists(atPath: path) else {
            return ImageTextRecognitionItem(
                path: path,
                displayName: displayName,
                recognizedText: nil,
                statusMessage: AssistantLocalized.text(zh: "文件不存在或已被移动。", en: "The file does not exist or has been moved."),
                lineCount: 0
            )
        }

        guard isSupportedImage(at: url) else {
            return ImageTextRecognitionItem(
                path: path,
                displayName: displayName,
                recognizedText: nil,
                statusMessage: AssistantLocalized.text(zh: "当前仅支持图片文件提取文字。", en: "Only image files are supported for text extraction."),
                lineCount: 0
            )
        }

        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return ImageTextRecognitionItem(
                path: path,
                displayName: displayName,
                recognizedText: nil,
                statusMessage: AssistantLocalized.text(zh: "无法读取图片内容。", en: "The image content could not be read."),
                lineCount: 0
            )
        }

        let imageCount = CGImageSourceGetCount(source)
        guard imageCount > 0 else {
            return ImageTextRecognitionItem(
                path: path,
                displayName: displayName,
                recognizedText: nil,
                statusMessage: AssistantLocalized.text(zh: "图片内容为空。", en: "The image content is empty."),
                lineCount: 0
            )
        }

        var recognizedBlocks: [String] = []
        var seenBlocks: Set<String> = []
        let maxFrameCount = min(imageCount, 8)

        for index in 0 ..< maxFrameCount {
            guard let cgImage = CGImageSourceCreateImageAtIndex(source, index, nil) else {
                continue
            }

            let block = detectText(in: cgImage)
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !block.isEmpty, seenBlocks.insert(block).inserted else {
                continue
            }
            recognizedBlocks.append(block)
        }

        let recognizedText = recognizedBlocks.joined(separator: "\n\n")
        let lineCount = recognizedText
            .split(whereSeparator: \.isNewline)
            .count

        return ImageTextRecognitionItem(
            path: path,
            displayName: displayName,
            recognizedText: recognizedText.isEmpty ? nil : recognizedText,
            statusMessage: recognizedText.isEmpty
                ? AssistantLocalized.text(zh: "未识别到图片文字。", en: "No text was detected in the image.")
                : nil,
            lineCount: lineCount
        )
    }

    private static func detectText(in image: CGImage) -> [String] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        if #available(macOS 13.0, *) {
            request.automaticallyDetectsLanguage = true
        } else {
            request.recognitionLanguages = ["zh-Hans", "en-US"]
        }

        let handler = VNImageRequestHandler(cgImage: image, options: [:])

        do {
            try handler.perform([request])
            let observations = request.results ?? []
            return observations
                .sorted(by: sortTextObservation(_:_:))
                .compactMap { observation in
                    observation.topCandidates(1).first?.string.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                .filter { !$0.isEmpty }
        } catch {
            return []
        }
    }

    private static func sortTextObservation(_ lhs: VNRecognizedTextObservation, _ rhs: VNRecognizedTextObservation) -> Bool {
        let verticalTolerance: CGFloat = 0.02
        let yDelta = lhs.boundingBox.midY - rhs.boundingBox.midY

        if abs(yDelta) > verticalTolerance {
            return yDelta > 0
        }

        return lhs.boundingBox.minX < rhs.boundingBox.minX
    }

    private static func isSupportedImage(at url: URL) -> Bool {
        guard let type = UTType(filenameExtension: url.pathExtension) else {
            return false
        }
        return type.conforms(to: .image)
    }

    private static func isDirectory(atPath path: String) -> Bool {
        var isDirectoryFlag: ObjCBool = false
        FileManager.default.fileExists(atPath: path, isDirectory: &isDirectoryFlag)
        return isDirectoryFlag.boolValue
    }

    private static func startReadableAccess(
        forPath path: String,
        directories: [AuthorizedDirectoryAccessSnapshot]
    ) -> (() -> Void)? {
        guard let directory = directories.first(where: { snapshot in
            let prefix = snapshot.rootPath.hasSuffix("/") ? snapshot.rootPath : snapshot.rootPath + "/"
            return path == snapshot.rootPath || path.hasPrefix(prefix)
        }) else {
            return nil
        }

        var isStale = false
        do {
            let scopedURL = try URL(
                resolvingBookmarkData: directory.bookmark,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            guard scopedURL.startAccessingSecurityScopedResource() else {
                return nil
            }

            return { scopedURL.stopAccessingSecurityScopedResource() }
        } catch {
            return nil
        }
    }
}

@MainActor
final class ImageTextRecognitionViewModel: ObservableObject {
    @Published var items: [ImageTextRecognitionItem] = []
    @Published var isLoading = true
    @Published var errorMessage: String?

    private var loadTask: Task<Void, Never>?

    var recognizedItems: [ImageTextRecognitionItem] {
        items.filter(\.hasRecognizedText)
    }

    var skippedItems: [ImageTextRecognitionItem] {
        items.filter { !$0.hasRecognizedText }
    }

    var recognizedFileCount: Int {
        recognizedItems.count
    }

    var totalLineCount: Int {
        items.reduce(into: 0) { result, item in
            result += item.lineCount
        }
    }

    var summaryText: String {
        if isLoading {
            return AssistantLocalized.text(zh: "正在提取选中图片中的文字。", en: "Extracting text from the selected images.")
        }

        if let errorMessage {
            return errorMessage
        }

        if items.isEmpty {
            return AssistantLocalized.text(zh: "没有可识别的文件。", en: "There are no files available to scan.")
        }

        if recognizedFileCount == 0 {
            return AssistantLocalized.text(zh: "已扫描 \(items.count) 个文件，未识别到图片文字。", en: "Scanned \(items.count) file(s) and found no text in the images.")
        }

        return AssistantLocalized.text(
            zh: "已扫描 \(items.count) 个文件，\(recognizedFileCount) 个文件识别到文字，共 \(totalLineCount) 行。",
            en: "Scanned \(items.count) file(s), detected text in \(recognizedFileCount) file(s), and extracted \(totalLineCount) lines."
        )
    }

    func load(paths: [String], directories: [AuthorizedDirectoryAccessSnapshot]) {
        loadTask?.cancel()
        isLoading = true
        errorMessage = nil
        items = []

        loadTask = Task.detached(priority: .userInitiated) {
            do {
                let results = try ImageTextRecognitionLoader.recognize(paths: paths, directories: directories)
                await MainActor.run {
                    self.items = results
                    self.isLoading = false
                }
            } catch is CancellationError {
                await MainActor.run {
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.items = []
                    self.errorMessage = AssistantLocalized.text(zh: "提取失败：\(error.localizedDescription)", en: "Extraction failed: \(error.localizedDescription)")
                    self.isLoading = false
                }
            }
        }
    }

    deinit {
        loadTask?.cancel()
    }
}

struct ImageTextRecognitionView: View {
    @ObservedObject var viewModel: ImageTextRecognitionViewModel
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header

            Group {
                if viewModel.isLoading {
                    loadingState
                } else if let errorMessage = viewModel.errorMessage {
                    messageCard(title: AssistantLocalized.text(zh: "提取失败", en: "Extraction Failed"), body: errorMessage)
                } else {
                    resultContent
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            footer
        }
        .padding(22)
        .frame(minWidth: 820, minHeight: 600)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(AssistantLocalized.text(zh: "图片文案提取", en: "Extract Image Text"))
                .font(.title3.weight(.semibold))
            Text(viewModel.summaryText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var loadingState: some View {
        VStack(alignment: .center, spacing: 14) {
            Spacer()
            ProgressView()
                .controlSize(.large)
            Text(AssistantLocalized.text(zh: "正在识别图片文字…", en: "Recognizing text in images..."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var resultContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if !viewModel.recognizedItems.isEmpty {
                    ForEach(viewModel.recognizedItems) { item in
                        recognizedItemCard(item)
                    }
                }

                if !viewModel.skippedItems.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(AssistantLocalized.text(zh: "未识别项目", en: "Unrecognized Items"))
                            .font(.headline)

                        ForEach(viewModel.skippedItems) { item in
                            messageCard(
                                title: item.displayName,
                                body: item.statusMessage ?? AssistantLocalized.text(zh: "未识别到图片文字。", en: "No text was detected in the image.")
                            )
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .textSelection(.enabled)
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            if viewModel.recognizedFileCount > 0 {
                Button(AssistantLocalized.text(zh: "复制全部结果", en: "Copy All Results")) {
                    copyAllResults()
                }
            }

            Spacer(minLength: 0)

            Button(AssistantLocalized.text(zh: "关闭", en: "Close")) {
                onClose()
            }
            .keyboardShortcut(.defaultAction)
        }
    }

    private func recognizedItemCard(_ item: ImageTextRecognitionItem) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.displayName)
                        .font(.headline)
                    Text(item.path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer(minLength: 0)

                Text(
                    AssistantLocalized.text(
                        zh: "\(item.lineCount) 行文字",
                        en: "\(item.lineCount) line(s)"
                    )
                )
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            if let recognizedText = item.recognizedText {
                Text(recognizedText)
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                HStack(spacing: 10) {
                    Button(AssistantLocalized.text(zh: "复制", en: "Copy")) {
                        copyText(
                            recognizedText,
                            successMessage: AssistantLocalized.text(zh: "图片文字已复制到剪贴板。", en: "The extracted text was copied to the clipboard.")
                        )
                    }
                }
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func messageCard(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(body)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func copyAllResults() {
        let values = viewModel.recognizedItems.compactMap { item -> String? in
            guard let recognizedText = item.recognizedText else {
                return nil
            }

            return "\(item.displayName)\n\(recognizedText)"
        }

        guard !values.isEmpty else {
            return
        }

        copyText(
            values.joined(separator: "\n\n"),
            successMessage: AssistantLocalized.text(zh: "全部提取结果已复制到剪贴板。", en: "All extracted text was copied to the clipboard.")
        )
    }

    private func copyText(_ text: String, successMessage: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let succeeded = pasteboard.setString(text, forType: .string)

        AssistantBannerNotificationCenter.shared.post(
            title: succeeded
                ? AssistantLocalized.text(zh: "复制成功", en: "Copied")
                : AssistantLocalized.text(zh: "复制失败", en: "Copy Failed"),
            body: succeeded
                ? successMessage
                : AssistantLocalized.text(zh: "未能写入剪贴板，请稍后再试。", en: "Failed to write to the clipboard. Please try again later.")
        )
    }
}
