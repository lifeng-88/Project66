import Foundation

struct BSideContentLocation: Sendable {
    let url: URL
    let source: BSideContentSource
    let errorMessage: String?

    init(url: URL, source: BSideContentSource, errorMessage: String? = nil) {
        self.url = url
        self.source = source
        self.errorMessage = errorMessage
    }
}

enum BSideContentSource: Equatable, Sendable {
    case debug
    case remoteHTML
    case unavailable
}

struct BSideContentLoader {
    static let shared = BSideContentLoader()

    func startLocation() async -> BSideContentLocation {
        if let url = BSideConfig.debugEnvURL() {
            return BSideContentLocation(url: url, source: .debug)
        }

        if let url = BSideConfig.localURL ?? BSideConfig.codeFallbackURL() {
            return BSideContentLocation(url: url, source: .remoteHTML)
        }

        return BSideContentLocation(
            url: URL(string: "about:blank")!,
            source: .unavailable,
            errorMessage: "B 面 URL 未配置。"
        )
    }
}
