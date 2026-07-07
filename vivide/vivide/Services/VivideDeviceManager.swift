import Foundation
import UIKit

actor VivideDeviceManager {
    static let shared = VivideDeviceManager()

    private static let legacyDeviceIdKey = "vivide.device_id"

    private init() {}

    func getDeviceId() async -> String {
        await resolvedKeychainDeviceId()
    }

    func getAppVersion() async -> String {
        await MainActor.run {
            Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        }
    }

    private func resolvedKeychainDeviceId() async -> String {
        let keychain = VivideKeychainManager.shared
        if let saved = await keychain.load(key: VivideKeychainKey.devId),
           !saved.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return saved
        }

        if let legacy = UserDefaults.standard.string(forKey: Self.legacyDeviceIdKey),
           !legacy.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            try? await keychain.save(key: VivideKeychainKey.devId, value: legacy)
            UserDefaults.standard.removeObject(forKey: Self.legacyDeviceIdKey)
            return legacy
        }

        let newId = await MainActor.run {
            UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        }

        do {
            try await keychain.save(key: VivideKeychainKey.devId, value: newId)
        } catch {
            // Keep going with the generated id if Keychain write fails.
        }
        return newId
    }
}
