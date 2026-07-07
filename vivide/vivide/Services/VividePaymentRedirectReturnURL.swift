import Foundation

enum VividePaymentRedirectReturnURL {
    static let string = "/local/recharge/return"
    private static let path = "/local/recharge/return"

    static func matches(_ url: URL) -> Bool {
        if url.path.lowercased() == path {
            return true
        }

        guard url.scheme?.lowercased() == "app" else { return false }
        guard url.host?.lowercased() == "recharge" else { return false }
        let returnPath = url.path.lowercased()
        return returnPath == "/return" || returnPath == "return"
    }
}
