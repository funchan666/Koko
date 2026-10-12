import SwiftUI

enum KokoLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case simplifiedChinese = "zh-Hans"
    case spanish = "es"
    case french = "fr"
    case japanese = "ja"

    var id: String { rawValue }
    var nativeName: String {
        switch self {
        case .english: "English"
        case .simplifiedChinese: "简体中文"
        case .spanish: "Español"
        case .french: "Français"
        case .japanese: "日本語"
        }
    }
    var englishName: String {
        switch self {
        case .english: "English"
        case .simplifiedChinese: "Simplified Chinese"
        case .spanish: "Spanish"
        case .french: "French"
        case .japanese: "Japanese"
        }
    }
}

@MainActor
final class KokoLanguagePreference: ObservableObject {
    static let storageKey = "koko.interface-language"
    @Published private(set) var selected: KokoLanguage
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        selected = defaults.string(forKey: Self.storageKey).flatMap(KokoLanguage.init(rawValue:)) ?? .english
    }

    func select(_ language: KokoLanguage) {
        guard selected != language else { return }
        defaults.set(language.rawValue, forKey: Self.storageKey)
        selected = language
    }
}

enum KokoCopy {
    static func text(_ key: String, language: KokoLanguage? = nil) -> String {
        let selected = language ?? UserDefaults.standard.string(forKey: "koko.interface-language")
            .flatMap(KokoLanguage.init(rawValue:)) ?? .english
        guard let path = Bundle.main.path(forResource: selected.rawValue, ofType: "lproj"),
              let bundle = Bundle(path: path) else { return key }
        return bundle.localizedString(forKey: key, value: key, table: "Localizable")
    }
}
