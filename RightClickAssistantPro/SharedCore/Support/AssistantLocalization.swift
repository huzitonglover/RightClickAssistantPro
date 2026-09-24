//
//  AssistantLocalization.swift
//  RightClickAssistantPro
//
//  Created by Codex on 2026/6/8.
//

import Foundation

enum AssistantLanguageOption: String, CaseIterable, Identifiable {
    case system
    case simplifiedChinese = "zh-Hans"
    case english = "en"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system:
            return AssistantLocalized.text(zh: "跟随系统", en: "System")
        case .simplifiedChinese:
            return "简体中文"
        case .english:
            return "English"
        }
    }

    var locale: Locale {
        switch self {
        case .system:
            return .autoupdatingCurrent
        case .simplifiedChinese:
            return Locale(identifier: rawValue)
        case .english:
            return Locale(identifier: rawValue)
        }
    }
}

enum AssistantLocalized {
    static var appName: String {
        Bundle.main.localizedInfoDictionary?["CFBundleDisplayName"] as? String
            ?? Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String
            ?? Bundle.main.localizedInfoDictionary?["CFBundleName"] as? String
            ?? Bundle.main.infoDictionary?["CFBundleName"] as? String
            ?? "RightMenuPro"
    }

    static var currentLocale: Locale {
        selectedLanguage.locale
    }

    static func text(zh: String, en: String) -> String {
        switch selectedLanguage {
        case .simplifiedChinese:
            return zh
        case .english:
            return en
        case .system:
            return systemPrefersSimplifiedChinese ? zh : en
        }
    }

    private static var selectedLanguage: AssistantLanguageOption {
        guard let rawValue = UserDefaults.group.string(forKey: SharedPreferenceKey.appLanguage),
              let option = AssistantLanguageOption(rawValue: rawValue) else {
            return .system
        }

        return option
    }

    private static var systemPrefersSimplifiedChinese: Bool {
        let preferredIdentifier = Locale.preferredLanguages.first ?? Locale.autoupdatingCurrent.identifier
        return preferredIdentifier.lowercased().hasPrefix("zh")
    }
}
