import Foundation
import UIKit
import UserNotifications

extension Notification.Name {
    static let vivideBSidePushPayloadReceived = Notification.Name("vivideBSidePushPayloadReceived")
    static let vivideBSidePushTokenUpdated = Notification.Name("vivideBSidePushTokenUpdated")
}

final class VividePushManager {
    static let shared = VividePushManager()

    private let defaults = UserDefaults.standard
    private let tokenKey = "vivide.push.token"
    private let errorKey = "vivide.push.lastError"
    private let launchPayloadKey = "vivide.push.launchPayload"
    private let registrationTimeout: TimeInterval = 8

    private var registrationCompletions: [([String: Any]) -> Void] = []
    private var registrationTimeoutWorkItem: DispatchWorkItem?
    private var isRegisteringForRemoteNotifications = false

    private init() {}

    func register(completion: @escaping ([String: Any]) -> Void) {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { [weak self] settings in
            guard let self else { return }

            switch settings.authorizationStatus {
            case .authorized, .ephemeral:
                self.registerForRemoteNotifications(completion: completion)
            case .provisional, .notDetermined:
                self.requestFullNotificationAuthorization(center: center) { granted in
                    if granted {
                        self.registerForRemoteNotifications(completion: completion)
                    } else {
                        let reason = self.defaults.string(forKey: self.errorKey)
                            ?? "Notification permission was denied."
                        completion(self.registrationResult(registered: false, reason: reason))
                    }
                }
            case .denied:
                completion(self.registrationResult(registered: false, reason: "Notification permission was denied."))
            @unknown default:
                completion(self.registrationResult(registered: false, reason: "Notification authorization status is unknown."))
            }
        }
    }

    func updateDeviceToken(_ deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        DispatchQueue.main.async {
            self.defaults.set(token, forKey: self.tokenKey)
            self.defaults.removeObject(forKey: self.errorKey)
            self.isRegisteringForRemoteNotifications = false
            self.registrationTimeoutWorkItem?.cancel()
            self.registrationTimeoutWorkItem = nil
            self.finishPendingRegistrations(with: self.registrationResult(registered: true, reason: nil))
            if BSideConfig.debugLogging {
                print("📬 [Push] APNs token: \(token)")
            }
            NotificationCenter.default.post(
                name: .vivideBSidePushTokenUpdated,
                object: nil,
                userInfo: ["token": token]
            )
        }
    }

    func updateRegistrationFailure(_ error: Error) {
        DispatchQueue.main.async {
            self.storeRegistrationError(error.localizedDescription)
            self.isRegisteringForRemoteNotifications = false
            self.registrationTimeoutWorkItem?.cancel()
            self.registrationTimeoutWorkItem = nil
            self.finishPendingRegistrations(with: self.registrationResult(
                registered: false,
                reason: error.localizedDescription
            ))
        }
    }

    func deliverPayload(_ userInfo: [AnyHashable: Any], source: String = "unknown") {
        var payload = Self.normalizedPayload(from: userInfo)
        if payload.isEmpty {
            payload = Self.fallbackPayload(from: userInfo)
        }

        guard !payload.isEmpty,
              JSONSerialization.isValidJSONObject(payload),
              let data = try? JSONSerialization.data(withJSONObject: payload)
        else { return }

        defaults.set(data, forKey: launchPayloadKey)
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .vivideBSidePushPayloadReceived,
                object: nil,
                userInfo: ["payload": payload, "source": source]
            )
        }
    }

    func captureLaunchPayload(_ userInfo: [AnyHashable: Any], source: String = "capture") {
        deliverPayload(userInfo, source: source)
    }

    func consumeLaunchPayload() -> [String: Any] {
        guard let data = defaults.data(forKey: launchPayloadKey),
              let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return ["payload": NSNull()]
        }

        defaults.removeObject(forKey: launchPayloadKey)
        return ["payload": payload]
    }

    private func requestFullNotificationAuthorization(
        center: UNUserNotificationCenter,
        completion: @escaping (Bool) -> Void
    ) {
        center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error {
                self.storeRegistrationError(error.localizedDescription)
            }
            center.getNotificationSettings { settings in
                completion(granted && settings.authorizationStatus == .authorized)
            }
        }
    }

    private func registerForRemoteNotifications(completion: @escaping ([String: Any]) -> Void) {
        DispatchQueue.main.async {
            if let token = self.defaults.string(forKey: self.tokenKey), !token.isEmpty {
                completion(self.registrationResult(registered: true, reason: nil))
                return
            }

            self.registrationCompletions.append(completion)
            self.scheduleRegistrationTimeout()
            self.beginRemoteNotificationRegistration()
        }
    }

    private func beginRemoteNotificationRegistration() {
        guard !isRegisteringForRemoteNotifications else { return }
        isRegisteringForRemoteNotifications = true
        UIApplication.shared.registerForRemoteNotifications()
    }

    private func registrationResult(registered: Bool, reason: String?) -> [String: Any] {
        let token = defaults.string(forKey: tokenKey)
        var result: [String: Any] = [
            "registered": registered,
            "token": token ?? NSNull(),
            "push_id": token ?? NSNull(),
            "pushId": token ?? NSNull()
        ]
        if let reason {
            result["reason"] = reason
        } else if let lastError = defaults.string(forKey: errorKey), !registered {
            result["reason"] = lastError
        }
        return result
    }

    private func scheduleRegistrationTimeout() {
        registrationTimeoutWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self, !self.registrationCompletions.isEmpty else { return }
            self.isRegisteringForRemoteNotifications = false
            self.finishPendingRegistrations(with: self.registrationResult(
                registered: false,
                reason: self.defaults.string(forKey: self.errorKey)
                    ?? "APNs token callback did not return within \(Int(self.registrationTimeout)) seconds."
            ))
        }
        registrationTimeoutWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + registrationTimeout, execute: workItem)
    }

    private func finishPendingRegistrations(with result: [String: Any]) {
        let completions = registrationCompletions
        registrationCompletions.removeAll()
        completions.forEach { $0(result) }
    }

    private func storeRegistrationError(_ message: String) {
        defaults.set(message, forKey: errorKey)
    }

    private static func normalizedPayload(from userInfo: [AnyHashable: Any]) -> [String: Any] {
        var payload: [String: Any] = [:]

        for (key, value) in userInfo {
            guard let key = stringKey(from: key), key != "aps", let normalized = normalizedValue(value) else { continue }
            payload[key] = normalized
        }

        if let aps = userInfo["aps"] as? [AnyHashable: Any] {
            payload.merge(apsSummary(from: aps), uniquingKeysWith: { current, _ in current })
        }

        if let glam = payload["glam"] as? [String: Any] {
            for (key, value) in glam where payload[key] == nil {
                payload[key] = value
            }
        }

        return payload
    }

    private static func fallbackPayload(from userInfo: [AnyHashable: Any]) -> [String: Any] {
        var payload: [String: Any] = [:]
        if let aps = userInfo["aps"] as? [AnyHashable: Any] {
            payload.merge(apsSummary(from: aps), uniquingKeysWith: { current, _ in current })
        }
        for (key, value) in userInfo {
            guard let key = stringKey(from: key), key != "aps", payload[key] == nil else { continue }
            payload[key] = normalizedValue(value) ?? String(describing: value)
        }
        return payload
    }

    private static func apsSummary(from aps: [AnyHashable: Any]) -> [String: Any] {
        var summary: [String: Any] = [:]
        if let alert = aps["alert"] {
            if let text = alert as? String {
                summary["alert"] = text
                summary["title"] = text
            } else if let alertDict = alert as? [AnyHashable: Any] {
                if let title = alertDict["title"] as? String { summary["title"] = title }
                if let body = alertDict["body"] as? String {
                    summary["body"] = body
                    if summary["title"] == nil { summary["title"] = body }
                }
            }
        }
        return summary.compactMapValues { normalizedValue($0) }
    }

    private static func stringKey(from key: AnyHashable) -> String? {
        if let string = key as? String { return string }
        if let string = key as? NSString { return string as String }
        return nil
    }

    private static func normalizedValue(_ value: Any) -> Any? {
        switch value {
        case let string as String: return string
        case let bool as Bool: return bool
        case let number as NSNumber: return number
        case let dict as [AnyHashable: Any]:
            var normalized: [String: Any] = [:]
            for (key, value) in dict {
                guard let key = stringKey(from: key), let nested = normalizedValue(value) else { continue }
                normalized[key] = nested
            }
            return normalized.isEmpty ? nil : normalized
        case let array as [Any]:
            let normalized = array.compactMap { normalizedValue($0) }
            return normalized.isEmpty ? nil : normalized
        default:
            return nil
        }
    }
}
