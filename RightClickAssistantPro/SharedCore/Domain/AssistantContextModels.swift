//
//  AssistantModelIdentity.swift
//  RightClickAssistantPro
//
//  Created by 老谭 on 2026/4/30.
//
import Foundation

protocol AssistantModelIdentity: Hashable, Identifiable, Codable {
    var id: String { get }
}

private struct AssistantFolderIconRecipe {
    let rank: Int
    let zhTitle: String
    let enTitle: String
    let assetName: String
    let pixelSize: Int
    let identifier: String
}

private enum FolderIconTemplateCatalog {
    static let recipes: [AssistantFolderIconRecipe] = [
        .init(rank: 0, zhTitle: "App", enTitle: "App", assetName: "FolderIconApp", pixelSize: 128, identifier: "builtin-folder-icon-app"),
        .init(rank: 1, zhTitle: "Apple", enTitle: "Apple", assetName: "FolderIconApple", pixelSize: 128, identifier: "builtin-folder-icon-apple"),
        .init(rank: 2, zhTitle: "书本", enTitle: "Book", assetName: "FolderIconBook", pixelSize: 128, identifier: "builtin-folder-icon-book"),
        .init(rank: 3, zhTitle: "日历", enTitle: "Calendar", assetName: "FolderIconCalendar", pixelSize: 128, identifier: "builtin-folder-icon-calendar"),
        .init(rank: 4, zhTitle: "云端", enTitle: "Cloud", assetName: "FolderIconCloud", pixelSize: 128, identifier: "builtin-folder-icon-cloud"),
        .init(rank: 5, zhTitle: "Excel", enTitle: "Excel", assetName: "FolderIconExcel", pixelSize: 128, identifier: "builtin-folder-icon-excel"),
        .init(rank: 6, zhTitle: "文件", enTitle: "File", assetName: "FolderIconFile", pixelSize: 128, identifier: "builtin-folder-icon-file"),
        .init(rank: 7, zhTitle: "谷歌", enTitle: "Google", assetName: "FolderIconGoogle", pixelSize: 128, identifier: "builtin-folder-icon-google"),
        .init(rank: 11, zhTitle: "邮件", enTitle: "Mail", assetName: "FolderIconMail", pixelSize: 128, identifier: "builtin-folder-icon-mail"),
        .init(rank: 12, zhTitle: "音乐", enTitle: "Music", assetName: "FolderIconMusic", pixelSize: 128, identifier: "builtin-folder-icon-music"),
        .init(rank: 13, zhTitle: "PPT", enTitle: "PPT", assetName: "FolderIconPPT", pixelSize: 128, identifier: "builtin-folder-icon-ppt"),
        .init(rank: 14, zhTitle: "图片", enTitle: "Picture", assetName: "FolderIconPicture", pixelSize: 128, identifier: "builtin-folder-icon-picture"),
        .init(rank: 15, zhTitle: "QQ", enTitle: "QQ", assetName: "FolderIconQQ", pixelSize: 128, identifier: "builtin-folder-icon-qq"),
        .init(rank: 16, zhTitle: "视频", enTitle: "Video", assetName: "FolderIconVideo", pixelSize: 128, identifier: "builtin-folder-icon-video"),
        .init(rank: 17, zhTitle: "微信", enTitle: "WeChat", assetName: "FolderIconWeChat", pixelSize: 128, identifier: "builtin-folder-icon-wechat"),
        .init(rank: 18, zhTitle: "Word", enTitle: "Word", assetName: "FolderIconWord", pixelSize: 128, identifier: "builtin-folder-icon-word"),
        .init(rank: 19, zhTitle: "图标 005", enTitle: "Icon 005", assetName: "FolderIconCustom005", pixelSize: 256, identifier: "builtin-folder-icon-custom-005"),
        .init(rank: 20, zhTitle: "图标 006", enTitle: "Icon 006", assetName: "FolderIconCustom006", pixelSize: 128, identifier: "builtin-folder-icon-custom-006"),
        .init(rank: 21, zhTitle: "图标 007", enTitle: "Icon 007", assetName: "FolderIconCustom007", pixelSize: 256, identifier: "builtin-folder-icon-custom-007"),
        .init(rank: 22, zhTitle: "图标 008", enTitle: "Icon 008", assetName: "FolderIconCustom008", pixelSize: 256, identifier: "builtin-folder-icon-custom-008"),
        .init(rank: 23, zhTitle: "图标 009", enTitle: "Icon 009", assetName: "FolderIconCustom009", pixelSize: 256, identifier: "builtin-folder-icon-custom-009"),
        .init(rank: 24, zhTitle: "图标 010", enTitle: "Icon 010", assetName: "FolderIconCustom010", pixelSize: 256, identifier: "builtin-folder-icon-custom-010"),
        .init(rank: 25, zhTitle: "图标 011", enTitle: "Icon 011", assetName: "FolderIconCustom011", pixelSize: 256, identifier: "builtin-folder-icon-custom-011"),
        .init(rank: 26, zhTitle: "图标 012", enTitle: "Icon 012", assetName: "FolderIconCustom012", pixelSize: 256, identifier: "builtin-folder-icon-custom-012"),
        .init(rank: 27, zhTitle: "图标 013", enTitle: "Icon 013", assetName: "FolderIconCustom013", pixelSize: 256, identifier: "builtin-folder-icon-custom-013"),
        .init(rank: 28, zhTitle: "图标 014", enTitle: "Icon 014", assetName: "FolderIconCustom014", pixelSize: 256, identifier: "builtin-folder-icon-custom-014"),
        .init(rank: 29, zhTitle: "图标 015", enTitle: "Icon 015", assetName: "FolderIconCustom015", pixelSize: 256, identifier: "builtin-folder-icon-custom-015"),
        .init(rank: 30, zhTitle: "图标 016", enTitle: "Icon 016", assetName: "FolderIconCustom016", pixelSize: 256, identifier: "builtin-folder-icon-custom-016"),
        .init(rank: 31, zhTitle: "图标 017", enTitle: "Icon 017", assetName: "FolderIconCustom017", pixelSize: 256, identifier: "builtin-folder-icon-custom-017"),
        .init(rank: 32, zhTitle: "图标 018", enTitle: "Icon 018", assetName: "FolderIconCustom018", pixelSize: 256, identifier: "builtin-folder-icon-custom-018"),
        .init(rank: 33, zhTitle: "图标 019", enTitle: "Icon 019", assetName: "FolderIconCustom019", pixelSize: 256, identifier: "builtin-folder-icon-custom-019"),
        .init(rank: 34, zhTitle: "图标 020", enTitle: "Icon 020", assetName: "FolderIconCustom020", pixelSize: 256, identifier: "builtin-folder-icon-custom-020"),
        .init(rank: 35, zhTitle: "图标 022", enTitle: "Icon 022", assetName: "FolderIconCustom022", pixelSize: 256, identifier: "builtin-folder-icon-custom-022"),
        .init(rank: 36, zhTitle: "图标 023", enTitle: "Icon 023", assetName: "FolderIconCustom023", pixelSize: 256, identifier: "builtin-folder-icon-custom-023"),
        .init(rank: 37, zhTitle: "图标 024", enTitle: "Icon 024", assetName: "FolderIconCustom024", pixelSize: 256, identifier: "builtin-folder-icon-custom-024"),
        .init(rank: 38, zhTitle: "图标 025", enTitle: "Icon 025", assetName: "FolderIconCustom025", pixelSize: 256, identifier: "builtin-folder-icon-custom-025"),
        .init(rank: 39, zhTitle: "图标 026", enTitle: "Icon 026", assetName: "FolderIconCustom026", pixelSize: 256, identifier: "builtin-folder-icon-custom-026"),
        .init(rank: 40, zhTitle: "图标 033", enTitle: "Icon 033", assetName: "FolderIconCustom033", pixelSize: 256, identifier: "builtin-folder-icon-custom-033"),
        .init(rank: 41, zhTitle: "图标 057", enTitle: "Icon 057", assetName: "FolderIconCustom057", pixelSize: 128, identifier: "builtin-folder-icon-custom-057"),
        .init(rank: 42, zhTitle: "图标 079", enTitle: "Icon 079", assetName: "FolderIconCustom079", pixelSize: 128, identifier: "builtin-folder-icon-custom-079"),
        .init(rank: 43, zhTitle: "图标 085", enTitle: "Icon 085", assetName: "FolderIconCustom085", pixelSize: 128, identifier: "builtin-folder-icon-custom-085"),
        .init(rank: 44, zhTitle: "图标 113", enTitle: "Icon 113", assetName: "FolderIconCustom113", pixelSize: 256, identifier: "builtin-folder-icon-custom-113")
    ]

    static func makeTemplate(from recipe: AssistantFolderIconRecipe) -> FolderIconTemplate {
        FolderIconTemplate(
            id: recipe.identifier,
            name: AssistantLocalized.text(zh: recipe.zhTitle, en: recipe.enTitle),
            assetName: recipe.assetName,
            pixelSize: recipe.pixelSize,
            idx: recipe.rank,
            isBuiltIn: true
        )
    }
}

struct FolderIconTemplate: AssistantModelIdentity {
    var id: String
    var name: String
    var enabled = true
    var assetName: String
    var imagePath: String? = nil
    var pixelSize: Int
    var idx: Int
    var isBuiltIn: Bool

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension FolderIconTemplate {
    static let setIconActionPrefix = "set-folder-icon::"

    var displayName: String {
        name
    }

    var sizeText: String {
        "\(pixelSize) x \(pixelSize)"
    }

    var actionIdentifier: String {
        Self.setIconActionPrefix + id
    }

    static func templateID(fromActionIdentifier identifier: String) -> String? {
        guard identifier.hasPrefix(setIconActionPrefix) else {
            return nil
        }

        return String(identifier.dropFirst(setIconActionPrefix.count))
    }

    static var all: [Self] {
        FolderIconTemplateCatalog.recipes.map(FolderIconTemplateCatalog.makeTemplate)
    }
}
