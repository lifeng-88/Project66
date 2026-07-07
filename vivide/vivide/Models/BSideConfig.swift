import Foundation
import WebKit

enum BSideConfig {
    /// 代码内显式 B 面入口（优先级最高）。
    static let entryURLString = ""

    /// Release H5 根地址（不含 cfg 参数）。
    static let remoteH5BaseURL = ""

    /// H5 通过 `?cfg=` 拉取的 RuntimeConfig JSON（`{ResBaseURL}/config/{channel}.json`）。
    static var runtimeConfigURL: String {
        let channelId = channel ?? "IOS10066"
        return "\(VivideAPIConfig.effectiveResBaseURL)/config/\(channelId).json"
    }

    /// 默认 B 面 H5 落地页（不含 query，运行时拼接 channel / did）。
    static let defaultLandingURLString = "https://vividshe.xin/h5/landing"

    /// Info.plist `VIVIDE_B_SIDE_URL`，或代码 `entryURLString`，否则默认落地页。
    static var localURL: URL? {
        if let value = entryURLString.trimmedNonEmpty, let url = URL(string: value) {
            return url
        }
        if let url = url(fromInfoKey: "VIVIDE_B_SIDE_URL") {
            return url
        }
        return URL(string: defaultLandingURLString)
    }

    /// Info.plist `VIVIDE_B_SIDE_CONFIG_URL`，返回 `{ "enabled": true, "url": "..." }`。
    static var remoteConfigURL: URL? {
        url(fromInfoKey: "VIVIDE_B_SIDE_CONFIG_URL")
    }

    static var isConfigured: Bool {
        localURL != nil
            || remoteConfigURL != nil
            || remoteH5BaseURL.trimmedNonEmpty != nil
            || debugEnvURL() != nil
    }

    static var appDisplayName: String {
        Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String ?? "Vivide"
    }

    static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    static var buildConfigurationLabel: String {
        #if DEBUG
        return "Debug"
        #else
        return "Release"
        #endif
    }

    static var channel: String? {
        #if DEBUG
        if let envValue = ProcessInfo.processInfo.environment["APP_CHANNEL"]?.trimmedNonEmpty {
            return envValue
        }
        #endif
        if let plist = VivideAppConfig.plistString(for: "AppChannel") {
            return plist
        }
        if let url = localURL, let fromURL = channel(from: url) {
            return fromURL
        }
        return "IOS10066"
    }

    static var privacyURL: URL? {
        URL(string: "https://funny-cupcake-5aba23.netlify.app/")
    }

    static var debugLogging: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    static var webViewInspectable: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    static func configureWebViewInspectability(_ webView: WKWebView) {
        if #available(iOS 16.4, *) {
            webView.isInspectable = webViewInspectable
        }
    }

    static func configureNavigationGestures(_ webView: WKWebView) {
        webView.allowsBackForwardNavigationGestures = true
    }

    static func channel(from url: URL) -> String? {
        guard let raw = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == "channel" })?
            .value?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !raw.isEmpty else { return nil }
        return raw
    }

    static func urlAppendingLaunchParams(_ url: URL, channel: String, deviceId: String) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }
        var items = components.queryItems ?? []
        items.removeAll { $0.name == "channel" || $0.name == "did" || $0.name == "cfg" }
        items.append(URLQueryItem(name: "cfg", value: runtimeConfigURL))
        items.append(URLQueryItem(name: "channel", value: channel))
        items.append(URLQueryItem(name: "did", value: deviceId))
        components.queryItems = items
        return components.url ?? url
    }

    static func urlAppendingDeviceId(_ url: URL, deviceId: String) -> URL {
        urlAppendingLaunchParams(url, channel: channel ?? "IOS10066", deviceId: deviceId)
    }

    static func codeFallbackURL() -> URL? {
        guard let base = remoteH5BaseURL.trimmedNonEmpty else { return nil }
        return h5StartURL(base: base.hasSuffix("/") ? base : base + "/") ?? URL(string: base)
    }

    static func debugEnvURL() -> URL? {
        #if DEBUG
        if let debugH5URL = ProcessInfo.processInfo.environment["APP_H5_URL"]?.trimmedNonEmpty,
           let url = URL(string: debugH5URL) {
            return url
        }
        return nil
        #else
        return nil
        #endif
    }

    private static func h5StartURL(base: String) -> URL? {
        var components = URLComponents(string: base)
        components?.queryItems = [URLQueryItem(name: "cfg", value: runtimeConfigURL)]
        return components?.url
    }

    private static func url(fromInfoKey key: String) -> URL? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: key) as? String,
              !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let url = URL(string: raw) else { return nil }
        return url
    }
}

extension String {
    nonisolated var trimmedNonEmpty: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}

struct BSideRemoteConfig: Decodable {
    let enabled: Bool
    let url: String?

    var resolvedURL: URL? {
        guard enabled, let url, !url.isEmpty else { return nil }
        return URL(string: url)
    }
}
