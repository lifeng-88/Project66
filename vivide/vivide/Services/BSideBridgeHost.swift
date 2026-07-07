import WebKit

protocol BSideBridgeHost: AnyObject {
    var hostWebView: WKWebView { get }
    func hostMarkReady()
    func hostNavigationFinished()
    func hostFail(_ message: String)
}

extension BSideViewModel: BSideBridgeHost {
    var hostWebView: WKWebView { webView }

    func hostMarkReady() {
        markReady()
    }

    func hostNavigationFinished() {
        navigationFinished()
    }

    func hostFail(_ message: String) {
        fail(message)
    }
}

final class BSidePageBridgeHost: BSideBridgeHost {
    private weak var webView: WKWebView?

    func attach(webView: WKWebView) {
        self.webView = webView
    }

    var hostWebView: WKWebView {
        guard let webView else {
            preconditionFailure("BSidePageBridgeHost webView is not attached")
        }
        return webView
    }

    func hostMarkReady() {}

    func hostNavigationFinished() {}

    func hostFail(_ message: String) {
        #if DEBUG
        print("⚠️ [BSidePage] \(message)")
        #endif
    }
}
