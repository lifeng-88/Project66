import Foundation
import UserNotifications

final class VividePushNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = VividePushNotificationDelegate()

    private override init() {
        super.init()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        VividePushManager.shared.deliverPayload(
            notification.request.content.userInfo,
            source: "willPresent"
        )
        if #available(iOS 14.0, *) {
            completionHandler([.banner, .list, .sound, .badge])
        } else {
            completionHandler([.alert, .sound, .badge])
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        VividePushManager.shared.deliverPayload(
            response.notification.request.content.userInfo,
            source: "didReceive"
        )
        completionHandler()
    }
}
