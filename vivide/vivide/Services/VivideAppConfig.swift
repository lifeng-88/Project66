import Foundation

final class VivideAppConfig: @unchecked Sendable {
    static let shared = VivideAppConfig()

    private init() {}

    func getChannel() async -> String {
        Self.resolvedChannel()
    }

    static func resolvedChannel() -> String {
        for key in ["AppChannel", "ChannelId", "VIVIDE_H5_CHANNEL"] {
            if let value = plistString(for: key) {
                return value
            }
        }
        if let url = BSideConfig.localURL, let channel = BSideConfig.channel(from: url) {
            return channel
        }
        return BSideConfig.channel ?? "IOS10066"
    }

    static func plistString(for key: String) -> String? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: key) as? String else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !(trimmed.hasPrefix("$(") && trimmed.hasSuffix(")")) else { return nil }
        return trimmed
    }
}
