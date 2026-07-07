import Foundation

enum VivideAPIConfig {
    private static let apiInfoKeys = ["VIVIDE_API_BASE_URL", "APIBaseURL"]
    private static let resInfoKeys = ["VIVIDE_RES_BASE_URL", "ResBaseURL"]

    static var effectiveAPIBaseURL: String? {
        let value = normalizedBaseURL(from: apiInfoKeys)
        return value.isEmpty ? nil : value
    }

    static var effectiveResBaseURL: String {
        normalizedBaseURL(from: resInfoKeys, defaultValue: "https://res.vividshe.xin")
    }

    static var baseURL: URL? {
        guard let base = effectiveAPIBaseURL else { return nil }
        return URL(string: base)
    }

    static var isConfigured: Bool {
        baseURL != nil
    }

    private static func normalizedBaseURL(from keys: [String], defaultValue: String? = nil) -> String {
        for key in keys {
            if let raw = Bundle.main.object(forInfoDictionaryKey: key) as? String {
                let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty, !(trimmed.hasPrefix("$(") && trimmed.hasSuffix(")")) {
                    return trimmed.hasSuffix("/") ? String(trimmed.dropLast()) : trimmed
                }
            }
        }
        return defaultValue ?? ""
    }
}
