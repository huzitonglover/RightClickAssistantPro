//
//  NewFileTemplate.swift
//  RightClickAssistantPro
//
//  Created by 老谭 on 2026/4/30.
//

import Foundation

private struct AssistantTemplateRecipe {
    let rank: Int
    let suffix: String
    let title: String
    let iconName: String
    let identifier: String
    let enabled: Bool
}

private enum NewFileTemplateCatalog {
    static let recipes: [AssistantTemplateRecipe] = [
        .init(rank: 0, suffix: ".txt", title: "TXT", iconName: "icon-assistant-text", identifier: "builtin-newfile-txt", enabled: true),
        .init(rank: 1, suffix: ".rtf", title: "RTF", iconName: "doc.richtext", identifier: "builtin-newfile-rtf", enabled: true),
        .init(rank: 2, suffix: ".xml", title: "XML", iconName: "chevron.left.forwardslash.chevron.right", identifier: "builtin-newfile-xml", enabled: true),
        .init(rank: 3, suffix: ".docx", title: "Word", iconName: "icon-assistant-docx", identifier: "builtin-newfile-docx", enabled: true),
        .init(rank: 4, suffix: ".xlsx", title: "Excel", iconName: "icon-assistant-xlsx", identifier: "builtin-newfile-xlsx", enabled: true),
        .init(rank: 5, suffix: ".pptx", title: "PPT", iconName: "icon-assistant-pptx", identifier: "builtin-newfile-pptx", enabled: true),
        .init(rank: 6, suffix: ".wps", title: "WPS 文字", iconName: "doc.text", identifier: "builtin-newfile-wps", enabled: true),
        .init(rank: 7, suffix: ".et", title: "WPS 表格", iconName: "tablecells", identifier: "builtin-newfile-et", enabled: true),
        .init(rank: 8, suffix: ".dps", title: "WPS 演示", iconName: "rectangle.on.rectangle", identifier: "builtin-newfile-dps", enabled: true),
        .init(rank: 9, suffix: ".pages", title: "Pages", iconName: "doc.text", identifier: "builtin-newfile-pages", enabled: true),
        .init(rank: 10, suffix: ".numbers", title: "Numbers", iconName: "chart.bar.doc.horizontal", identifier: "builtin-newfile-numbers", enabled: true),
        .init(rank: 11, suffix: ".key", title: "Keynote", iconName: "rectangle.inset.filled", identifier: "builtin-newfile-key", enabled: true),
        .init(rank: 12, suffix: ".ai", title: "Ai", iconName: "pencil.and.outline", identifier: "builtin-newfile-ai", enabled: true),
        .init(rank: 13, suffix: ".psd", title: "PSD", iconName: "photo", identifier: "builtin-newfile-psd", enabled: true),
        .init(rank: 14, suffix: ".md", title: "Markdown", iconName: "icon-assistant-markdown", identifier: "builtin-newfile-md", enabled: true)
    ]

    private static let recipeByIdentifier = Dictionary(
        uniqueKeysWithValues: recipes.map { ($0.identifier, $0) }
    )

    static func template(for identifier: String) -> NewFileTemplate {
        guard let recipe = recipeByIdentifier[identifier] else {
            preconditionFailure("Unknown new file identifier: \(identifier)")
        }
        return makeTemplate(from: recipe)
    }

    static func makeTemplate(from recipe: AssistantTemplateRecipe) -> NewFileTemplate {
        NewFileTemplate(
            ext: recipe.suffix,
            name: recipe.title,
            enabled: recipe.enabled,
            idx: recipe.rank,
            icon: recipe.iconName,
            id: recipe.identifier
        )
    }

    static func localizedTitle(for identifier: String, fallback: String) -> String {
        guard let recipe = recipeByIdentifier[identifier],
              fallback == recipe.title else {
            return fallback
        }

        switch identifier {
        case "builtin-newfile-md":
            return AssistantLocalized.text(zh: "Markdown", en: "Markdown")
        case "builtin-newfile-docx":
            return AssistantLocalized.text(zh: "Word", en: "Word")
        case "builtin-newfile-xlsx":
            return AssistantLocalized.text(zh: "Excel", en: "Excel")
        case "builtin-newfile-pptx":
            return AssistantLocalized.text(zh: "PPT", en: "PPT")
        case "builtin-newfile-wps":
            return AssistantLocalized.text(zh: "WPS 文字", en: "WPS Writer")
        case "builtin-newfile-et":
            return AssistantLocalized.text(zh: "WPS 表格", en: "WPS Spreadsheet")
        case "builtin-newfile-dps":
            return AssistantLocalized.text(zh: "WPS 演示", en: "WPS Presentation")
        default:
            return fallback
        }
    }
}

struct NewFileTemplate: AssistantModelIdentity {
    var ext: String
    var name: String
    var enabled = true
    var idx: Int
    var icon: String
    var id: String
    var openApp: URL?
    var template: URL?
    var showInMainMenu = false

    init(
        ext: String,
        name: String,
        enabled: Bool = true,
        idx: Int,
        icon: String = "document",
        id: String = UUID().uuidString
    ) {
        self.ext = ext
        self.name = name
        self.enabled = enabled
        self.idx = idx
        self.icon = icon
        self.id = id
    }

    private enum CodingKeys: String, CodingKey {
        case ext
        case name
        case enabled
        case idx
        case icon
        case id
        case openApp
        case template
        case showInMainMenu
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        ext = try container.decode(String.self, forKey: .ext)
        name = try container.decode(String.self, forKey: .name)
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        idx = try container.decode(Int.self, forKey: .idx)
        icon = try container.decodeIfPresent(String.self, forKey: .icon) ?? "document"
        id = try container.decode(String.self, forKey: .id)
        openApp = try container.decodeIfPresent(URL.self, forKey: .openApp)
        template = try container.decodeIfPresent(URL.self, forKey: .template)
        showInMainMenu = try container.decodeIfPresent(Bool.self, forKey: .showInMainMenu) ?? false
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension NewFileTemplate {
    var displayName: String {
        NewFileTemplateCatalog.localizedTitle(for: id, fallback: name)
    }

    static var all: [Self] {
        NewFileTemplateCatalog.recipes.map(NewFileTemplateCatalog.makeTemplate)
    }

    static var txt: Self { NewFileTemplateCatalog.template(for: "builtin-newfile-txt") }
    static var rtf: Self { NewFileTemplateCatalog.template(for: "builtin-newfile-rtf") }
    static var xml: Self { NewFileTemplateCatalog.template(for: "builtin-newfile-xml") }
    static var docx: Self { NewFileTemplateCatalog.template(for: "builtin-newfile-docx") }
    static var xlsx: Self { NewFileTemplateCatalog.template(for: "builtin-newfile-xlsx") }
    static var pptx: Self { NewFileTemplateCatalog.template(for: "builtin-newfile-pptx") }
    static var wps: Self { NewFileTemplateCatalog.template(for: "builtin-newfile-wps") }
    static var et: Self { NewFileTemplateCatalog.template(for: "builtin-newfile-et") }
    static var dps: Self { NewFileTemplateCatalog.template(for: "builtin-newfile-dps") }
    static var pages: Self { NewFileTemplateCatalog.template(for: "builtin-newfile-pages") }
    static var numbers: Self { NewFileTemplateCatalog.template(for: "builtin-newfile-numbers") }
    static var key: Self { NewFileTemplateCatalog.template(for: "builtin-newfile-key") }
    static var ai: Self { NewFileTemplateCatalog.template(for: "builtin-newfile-ai") }
    static var psd: Self { NewFileTemplateCatalog.template(for: "builtin-newfile-psd") }
    static var md: Self { NewFileTemplateCatalog.template(for: "builtin-newfile-md") }
}
