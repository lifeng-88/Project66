import Combine
import SwiftUI
import WebKit

final class BSideViewModel: ObservableObject {
    @Published var isReady = false
    @Published var errorMessage: String?

    let pageURL: URL

    private var bridge: BSideBridge?

    private(set) lazy var webView: WKWebView = {
        let contentController = WKUserContentController()
        let bridge = BSideBridge(host: self)
        self.bridge = bridge
        contentController.add(bridge, name: BSideBridge.messageName)

        let configuration = WKWebViewConfiguration()
        configuration.userContentController = contentController
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.allowsInlineMediaPlayback = true
        configuration.setURLSchemeHandler(MediaCacheSchemeHandler(), forURLScheme: MediaCacheSchemeHandler.scheme)

        let webView = WKWebView(frame: .zero, configuration: configuration)
        BSideConfig.configureWebViewInspectability(webView)
        BSideConfig.configureNavigationGestures(webView)
        webView.navigationDelegate = bridge
        webView.uiDelegate = bridge
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.scrollView.alwaysBounceVertical = false
        webView.scrollView.keyboardDismissMode = .none
        webView.isOpaque = false
        webView.backgroundColor = .clear
        installKeyboardScrollGuard(for: webView)
        return webView
    }()

    private var didLoad = false
    private var keyboardObservers: [NSObjectProtocol] = []
    private var readyFallbackWorkItem: DispatchWorkItem?
    private var loadSequence = 0

    init(pageURL: URL) {
        self.pageURL = pageURL
    }

    deinit {
        keyboardObservers.forEach(NotificationCenter.default.removeObserver)
    }

    private func installKeyboardScrollGuard(for webView: WKWebView) {
        let center = NotificationCenter.default
        let notifications: [Notification.Name] = [
            UIResponder.keyboardWillChangeFrameNotification,
            UIResponder.keyboardDidChangeFrameNotification,
            UIResponder.keyboardWillHideNotification,
            UIResponder.keyboardDidHideNotification
        ]

        keyboardObservers = notifications.map { name in
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self, weak webView] notification in
                self?.handleKeyboardNotification(notification, webView: webView)
            }
        }
    }

    private func handleKeyboardNotification(_ notification: Notification, webView: WKWebView?) {
        guard let webView else { return }
        Self.resetWebViewScroll(webView)
    }

    private static func resetWebViewScroll(_ webView: WKWebView) {
        let scrollView = webView.scrollView
        scrollView.contentInset = .zero
        scrollView.scrollIndicatorInsets = .zero
        scrollView.setContentOffset(.zero, animated: false)

        [0.05, 0.12, 0.24, 0.42, 0.68].forEach { delay in
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak webView] in
                guard let webView else { return }
                webView.scrollView.contentInset = .zero
                webView.scrollView.scrollIndicatorInsets = .zero
                webView.scrollView.setContentOffset(.zero, animated: false)
            }
        }
    }

    func loadIfNeeded() {
        guard !didLoad else { return }
        didLoad = true
        VividePaymentManager.shared.startListening()
        Task {
            await VivideAFManager.shared.initAFAsync(channelId: BSideConfig.channel)
        }
        load(pageURL)
    }

    func reload() {
        isReady = false
        errorMessage = nil
        VividePaymentManager.shared.startListening()
        Task {
            await VivideAFManager.shared.initAFAsync(channelId: BSideConfig.channel)
        }
        load(pageURL)
    }

    private func load(_ url: URL) {
        errorMessage = nil
        isReady = false
        readyFallbackWorkItem?.cancel()
        loadSequence += 1

        #if DEBUG
        let cachePolicy: URLRequest.CachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        #else
        let cachePolicy: URLRequest.CachePolicy = .returnCacheDataElseLoad
        #endif

        webView.load(URLRequest(url: url, cachePolicy: cachePolicy, timeoutInterval: 15))
    }

    func markReady() {
        readyFallbackWorkItem?.cancel()
        isReady = true
        errorMessage = nil
    }

    func fail(_ message: String) {
        readyFallbackWorkItem?.cancel()
        isReady = false
        errorMessage = message
    }

    func navigationFinished() {
        let sequence = loadSequence
        readyFallbackWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self, self.loadSequence == sequence, !self.isReady else { return }
            self.markReady()
        }
        readyFallbackWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 8, execute: workItem)
    }
}
