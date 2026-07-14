import Foundation

#if canImport(AppsFlyerLib)
import AppsFlyerLib
#endif

extension Notification.Name {
    /// AF 归因数据首次就绪或从超时占位升级为真实数据时发出。
    static let vivideAFAttributionDidUpdate = Notification.Name("vivideAFAttributionDidUpdate")
}

private let nativeAFHasObtainedAttributionKey = "vivide.af_has_obtained_attribution"
private let nativeAFHasCompletedLoginKey = "vivide.af_has_completed_login"
private let nativeAFAttributionJSONKey = "vivide.af_attribution_json"
private let nativeAFAfIDKey = "vivide.af_af_id"
private let nativeAFAdIDKey = "vivide.af_ad_id"
private let nativeAFSourceKey = "vivide.af_source"
private let nativeAFAttributionTimeoutSeconds: TimeInterval = 10

struct AFAttributionResult {
    var afId: String?
    var adId: String?
    var source: String?
    var attributionJson: String?

    static func timeoutFallback() -> AFAttributionResult {
        let timeoutJson = Self.jsonString(from: [
            "timeout": true,
            "af_status": "timeout"
        ])
        return AFAttributionResult(afId: nil, adId: nil, source: nil, attributionJson: timeoutJson)
    }

    var hasRealAttributionPayload: Bool {
        guard let json = attributionJson?.trimmedNonEmpty else { return false }
        if json.contains("\"timeout\":true") || json.contains("\"timeout\": true") { return false }
        return true
    }

    var loginParameters: [String: Any] {
        var params: [String: Any] = [:]
        if let source = source?.trimmedNonEmpty { params["source"] = source }
        if let afId = afId?.trimmedNonEmpty { params["afId"] = afId }
        if let adId = adId?.trimmedNonEmpty { params["adId"] = adId }
        if let attributionJson = attributionJson?.trimmedNonEmpty {
            params["afAttributionJson"] = attributionJson
        }
        return params
    }

    static func jsonString(from object: [String: Any]) -> String? {
        guard JSONSerialization.isValidJSONObject(object),
              let data = try? JSONSerialization.data(withJSONObject: object, options: []),
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return string
    }

    static func jsonString(fromConversionInfo conversionInfo: [AnyHashable: Any]) -> String? {
        let sanitized = sanitizeDictionary(conversionInfo)
        guard JSONSerialization.isValidJSONObject(sanitized),
              let data = try? JSONSerialization.data(withJSONObject: sanitized, options: []),
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return string
    }

    private static func sanitizeDictionary(_ raw: [AnyHashable: Any]) -> [String: Any] {
        var result: [String: Any] = [:]
        for (key, value) in raw {
            guard let sanitized = sanitizeValue(value) else { continue }
            result["\(key)"] = sanitized
        }
        return result
    }

    private static func sanitizeValue(_ value: Any) -> Any? {
        switch value {
        case is NSNull:
            return NSNull()
        case let string as String:
            return string
        case let number as NSNumber:
            return number
        case let bool as Bool:
            return bool
        case let int as Int:
            return int
        case let double as Double:
            return double
        case let dict as [String: Any]:
            var nested: [String: Any] = [:]
            for (key, nestedValue) in dict {
                if let sanitized = sanitizeValue(nestedValue) {
                    nested[key] = sanitized
                }
            }
            return nested
        case let dict as [AnyHashable: Any]:
            return sanitizeDictionary(dict)
        case let array as [Any]:
            return array.compactMap { sanitizeValue($0) }
        default:
            return "\(value)"
        }
    }
}

@MainActor
final class VivideAFManager {
    static let shared = VivideAFManager()

    private let defaults = UserDefaults.standard
    private var attributionResult: AFAttributionResult?
    private var attributionContinuation: CheckedContinuation<AFAttributionResult?, Never>?
    private var startedConfigurationKey: String?

    private init() {}

    func markLoginCompleted() {
        defaults.set(true, forKey: nativeAFHasCompletedLoginKey)
    }

    func getAttributionForLogin() async -> AFAttributionResult? {
        getAttributionForLoginCached()
    }

    func initAFAsync(channelId: String?) async {
        let effectiveChannel = effectiveChannel(channelId: channelId)
        _ = await configureAndStart(channelId: effectiveChannel)
    }

    func handleBecomeActive() {
        guard startedConfigurationKey != nil else { return }
        VivideAFSDKBridge.start()
    }

    var isConfigured: Bool {
        startedConfigurationKey != nil
    }

    func prepareForFirstLaunch(channelId: String?) async -> (canLogin: Bool, attribution: AFAttributionResult?) {
        let effectiveChannel = effectiveChannel(channelId: channelId)
        #if DEBUG
        if ProcessInfo.processInfo.environment["SIMULATE_AF_TIMEOUT"] == "1" {
            return (true, AFAttributionResult.timeoutFallback())
        }
        #endif
        guard await configureAndStart(channelId: effectiveChannel) else {
            return (true, AFAttributionResult.timeoutFallback())
        }
        let attribution = await waitForAttributionOrTimeout()
        return (true, attribution ?? AFAttributionResult.timeoutFallback())
    }

    func prepareLoginAttribution(channelId: String?) async -> [String: Any] {
        let (_, rawAttribution) = await prepareForFirstLaunch(channelId: channelId)
        if let rawAttribution {
            return rawAttribution.loginParameters
        }
        return AFAttributionResult.timeoutFallback().loginParameters
    }

    func logEvent(
        channelId: String?,
        eventName: String,
        values: [String: Any]?
    ) async -> [String: Any] {
        let trimmedEventName = eventName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEventName.isEmpty else {
            return [
                "logged": false,
                "code": "INVALID_EVENT_NAME",
                "message": "Event name is required."
            ]
        }

        let effectiveChannel = effectiveChannel(channelId: channelId)
        guard await configureAndStart(channelId: effectiveChannel) else {
            return [
                "logged": false,
                "code": "AF_NOT_CONFIGURED",
                "message": "AppsFlyer is not configured. Check remote AF config or Info.plist keys."
            ]
        }

        let afValues = Self.normalizedEventValues(values)
        return await withCheckedContinuation { continuation in
            VivideAFSDKBridge.logEvent(name: trimmedEventName, values: afValues.isEmpty ? nil : afValues) { result in
                Task { @MainActor in
                    switch result {
                    case let .success(response):
                        var payload: [String: Any] = [
                            "logged": true,
                            "eventName": trimmedEventName
                        ]
                        if !response.isEmpty {
                            payload["response"] = response
                        }
                        continuation.resume(returning: payload)
                    case let .failure(error):
                        continuation.resume(returning: [
                            "logged": false,
                            "code": "AF_LOG_EVENT_FAILED",
                            "message": error.localizedDescription,
                            "eventName": trimmedEventName
                        ])
                    }
                }
            }
        }
    }

    func setAttribution(afId: String?, adId: String?, source: String?, attributionJson: String?) {
        let previousHadRealPayload = attributionResult?.hasRealAttributionPayload
            ?? getAttributionForLoginCached()?.hasRealAttributionPayload
            ?? false

        let result = AFAttributionResult(
            afId: afId,
            adId: adId,
            source: source,
            attributionJson: attributionJson
        )
        attributionResult = result
        if let afId = afId?.trimmedNonEmpty { defaults.set(afId, forKey: nativeAFAfIDKey) }
        if let adId = adId?.trimmedNonEmpty { defaults.set(adId, forKey: nativeAFAdIDKey) }
        if let source = source?.trimmedNonEmpty { defaults.set(source, forKey: nativeAFSourceKey) }
        if let attributionJson = attributionJson?.trimmedNonEmpty {
            defaults.set(attributionJson, forKey: nativeAFAttributionJSONKey)
        }

        let hasUsableData = result.hasRealAttributionPayload
            || afId?.trimmedNonEmpty != nil
            || source?.trimmedNonEmpty != nil
        if hasUsableData {
            defaults.set(true, forKey: nativeAFHasObtainedAttributionKey)
        }

        let wasWaiting = attributionContinuation != nil
        if let continuation = attributionContinuation {
            attributionContinuation = nil
            continuation.resume(returning: result)
        }

        // 仅「等待已超时后」迟到的真实归因才通知补传，避免与首启请求重复
        if hasUsableData, !previousHadRealPayload, !wasWaiting {
            NotificationCenter.default.post(name: .vivideAFAttributionDidUpdate, object: nil)
        }
    }

    private static func normalizedEventValues(_ values: [String: Any]?) -> [String: Any] {
        guard let values else { return [:] }
        var result: [String: Any] = [:]
        for (key, value) in values {
            let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedKey.isEmpty, let normalized = normalizedEventValue(value) else { continue }
            result[trimmedKey] = normalized
        }
        return result
    }

    private static func normalizedEventValue(_ value: Any) -> Any? {
        switch value {
        case let string as String: return string
        case let number as NSNumber: return number
        case let bool as Bool: return bool
        case let int as Int: return int
        case let double as Double: return double
        case let dict as [String: Any]:
            let nested = normalizedEventValues(dict)
            return nested.isEmpty ? nil : nested
        case let array as [Any]:
            let normalized = array.compactMap { normalizedEventValue($0) }
            return normalized.isEmpty ? nil : normalized
        default:
            return nil
        }
    }

    private func waitForAttributionOrTimeout() async -> AFAttributionResult? {
        if defaults.bool(forKey: nativeAFHasObtainedAttributionKey),
           let cached = getAttributionForLoginCached(),
           cached.hasRealAttributionPayload || cached.afId?.trimmedNonEmpty != nil {
            return cached
        }

        return await withCheckedContinuation { continuation in
            attributionContinuation = continuation
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64(nativeAFAttributionTimeoutSeconds * 1_000_000_000))
                VivideAFManager.shared.timeoutAttribution()
            }
        }
    }

    private func timeoutAttribution() {
        guard let continuation = attributionContinuation else { return }
        attributionContinuation = nil
        // 超时不把「已获取归因」置真，避免迟到的 conversion 回调被忽略等待逻辑；迟到数据仍可通过 setAttribution 补存
        continuation.resume(returning: getAttributionForLoginCached() ?? AFAttributionResult.timeoutFallback())
    }

    private func getAttributionForLoginCached() -> AFAttributionResult? {
        if let attributionResult { return attributionResult }
        let afId = defaults.string(forKey: nativeAFAfIDKey)
        let adId = defaults.string(forKey: nativeAFAdIDKey)
        let source = defaults.string(forKey: nativeAFSourceKey)
        let json = defaults.string(forKey: nativeAFAttributionJSONKey)
        if afId?.trimmedNonEmpty != nil || adId?.trimmedNonEmpty != nil || source?.trimmedNonEmpty != nil || json?.trimmedNonEmpty != nil {
            return AFAttributionResult(afId: afId, adId: adId, source: source, attributionJson: json)
        }
        return nil
    }

    private func configureAndStart(channelId: String) async -> Bool {
        let appleAppID = await VivideAFRemoteConfig.shared.getAppleAppID(channelId: channelId)
        let appsFlyerDevKey = await VivideAFRemoteConfig.shared.getAppsFlyerDevKey(channelId: channelId)

        guard let appleAppID, let appsFlyerDevKey else {
            if BSideConfig.debugLogging {
                print("[AF] Missing AF config for channel=\(channelId)")
            }
            return false
        }

        let configurationKey = "\(appleAppID)|\(appsFlyerDevKey)"
        if startedConfigurationKey == configurationKey {
            return true
        }

        VivideAFSDKBridge.configure(
            appleAppID: appleAppID,
            appsFlyerDevKey: appsFlyerDevKey,
            customerUserID: await VivideDeviceManager.shared.getDeviceId()
        )
        VivideAFSDKBridge.start()
        startedConfigurationKey = configurationKey
        if BSideConfig.debugLogging {
            print("✅ [AF] started channel=\(channelId) appID=\(appleAppID)")
        }
        return true
    }

    private func effectiveChannel(channelId: String?) -> String {
        channelId?.trimmedNonEmpty
            ?? BSideConfig.channel
            ?? VivideAppConfig.resolvedChannel()
    }
}

enum VivideAFSDKBridge {
    static func configure(appleAppID: String, appsFlyerDevKey: String, customerUserID: String) {
        #if canImport(AppsFlyerLib)
        AppsFlyerLib.shared().appleAppID = appleAppID
        AppsFlyerLib.shared().appsFlyerDevKey = appsFlyerDevKey
        AppsFlyerLib.shared().customerUserID = customerUserID
        AppsFlyerLib.shared().delegate = VivideAFDelegateWrapper.shared
        #else
        _ = appleAppID
        _ = appsFlyerDevKey
        _ = customerUserID
        #endif
    }

    static func start() {
        #if canImport(AppsFlyerLib)
        AppsFlyerLib.shared().start()
        #endif
    }

    static func logEvent(
        name: String,
        values: [String: Any]?,
        completion: @escaping (Result<[String: Any], Error>) -> Void
    ) {
        #if canImport(AppsFlyerLib)
        AppsFlyerLib.shared().logEvent(
            name: name,
            values: values,
            completionHandler: { response, error in
                if let error {
                    completion(.failure(error))
                    return
                }
                completion(.success(response ?? [:]))
            }
        )
        #else
        _ = name
        _ = values
        completion(.success([:]))
        #endif
    }
}

#if canImport(AppsFlyerLib)
private final class VivideAFDelegateWrapper: NSObject, AppsFlyerLibDelegate {
    static let shared = VivideAFDelegateWrapper()

    private override init() {
        super.init()
    }

    func onConversionDataSuccess(_ conversionInfo: [AnyHashable: Any]) {
        let afId = AppsFlyerLib.shared().getAppsFlyerUID()
        let attributionJson = AFAttributionResult.jsonString(fromConversionInfo: conversionInfo)
        let source = (conversionInfo["media_source"] as? String)
            ?? (conversionInfo["mediaSource"] as? String)
        let adId = (conversionInfo["advertising_id"] as? String)
            ?? (conversionInfo["idfa"] as? String)

        if BSideConfig.debugLogging {
            let preview = attributionJson.map { String($0.prefix(240)) } ?? "nil"
            print("✅ [AF] conversion success afId=\(afId ?? "nil") source=\(source ?? "nil") json=\(preview)")
        }

        Task { @MainActor in
            VivideAFManager.shared.setAttribution(
                afId: afId,
                adId: adId,
                source: source,
                attributionJson: attributionJson
            )
        }
    }

    func onConversionDataFail(_ error: Error) {
        let afId = AppsFlyerLib.shared().getAppsFlyerUID()
        let failureJson = AFAttributionResult.jsonString(from: [
            "af_status": "failure",
            "error": error.localizedDescription
        ])

        if BSideConfig.debugLogging {
            print("⚠️ [AF] conversion failed: \(error.localizedDescription)")
        }

        Task { @MainActor in
            // 失败时仍带上 afId，避免服务端完全无设备侧标识；不假装已有完整归因
            VivideAFManager.shared.setAttribution(
                afId: afId,
                adId: nil,
                source: nil,
                attributionJson: failureJson
            )
        }
    }
}
#endif
