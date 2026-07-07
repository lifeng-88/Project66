import UIKit
import UserNotifications

final class VivideAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = VividePushNotificationDelegate.shared

        if let userInfo = launchOptions?[.remoteNotification] as? [AnyHashable: Any] {
            VividePushManager.shared.captureLaunchPayload(userInfo, source: "launchOptions")
        }

        return true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        Task { @MainActor in
            VivideAFManager.shared.handleBecomeActive()
        }
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        VividePushManager.shared.updateDeviceToken(deviceToken)
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        VividePushManager.shared.updateRegistrationFailure(error)
    }
}
