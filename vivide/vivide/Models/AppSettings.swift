import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable, Codable {
    case system
    case zhHans = "zh-Hans"
    case english = "en"

    var id: String { rawValue }

    var locale: Locale {
        switch self {
        case .system: return .autoupdatingCurrent
        case .zhHans: return Locale(identifier: "zh-Hans")
        case .english: return Locale(identifier: "en")
        }
    }

    var l10nCode: String {
        switch self {
        case .system:
            let preferred = Locale.preferredLanguages.first ?? "zh-Hans"
            return preferred.hasPrefix("zh") ? "zh-Hans" : "en"
        case .zhHans: return "zh-Hans"
        case .english: return "en"
        }
    }
}

enum AppearanceMode: String, CaseIterable, Identifiable, Codable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

@MainActor
final class AppSettings: ObservableObject {
    @Published var language: AppLanguage {
        didSet { persist() }
    }
    @Published var appearance: AppearanceMode {
        didSet { persist() }
    }
    @Published var showHiddenPhotos: Bool {
        didSet { persist() }
    }
    @Published var importFolderId: String? {
        didSet { persist() }
    }

    init() {
        let storedLang = UserDefaults.standard.string(forKey: Keys.language)
        language = AppLanguage(rawValue: storedLang ?? "") ?? .system
        let storedAppearance = UserDefaults.standard.string(forKey: Keys.appearance)
        appearance = AppearanceMode(rawValue: storedAppearance ?? "") ?? .system
        if UserDefaults.standard.object(forKey: Keys.showHiddenPhotos) != nil {
            showHiddenPhotos = UserDefaults.standard.bool(forKey: Keys.showHiddenPhotos)
        } else {
            showHiddenPhotos = false
        }
        if let storedFolder = UserDefaults.standard.string(forKey: Keys.importFolderId) {
            importFolderId = storedFolder.isEmpty ? nil : storedFolder
        } else {
            importFolderId = nil
        }
        validateImportFolder()
    }

    func validateImportFolder() {
        guard let importFolderId else { return }
        let folders = LocalPhotoStorage.loadFolders()
        if !folders.contains(where: { $0.id == importFolderId }) {
            self.importFolderId = nil
        }
    }

    func t(_ key: L10nKey) -> String {
        L10n.string(key, language: language.l10nCode)
    }

    func resolvedColorScheme(_ system: ColorScheme) -> ColorScheme {
        appearance.colorScheme ?? system
    }

    private func persist() {
        UserDefaults.standard.set(language.rawValue, forKey: Keys.language)
        UserDefaults.standard.set(appearance.rawValue, forKey: Keys.appearance)
        UserDefaults.standard.set(showHiddenPhotos, forKey: Keys.showHiddenPhotos)
        UserDefaults.standard.set(importFolderId ?? "", forKey: Keys.importFolderId)
    }

    private enum Keys {
        static let language = "vivide_language"
        static let appearance = "vivide_appearance"
        static let showHiddenPhotos = "vivide_show_hidden_photos"
        static let importFolderId = "vivide_import_folder_id"
    }
}
