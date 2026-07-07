import Foundation
import Photos
import PhotosUI
import UIKit
import WebKit

final class BSideBridge: NSObject, WKScriptMessageHandler, WKNavigationDelegate, PHPickerViewControllerDelegate {
    static let messageName = "syncAppInfo"
    #if DEBUG
    private static let bridgeVersion = "2026-07-04.1"
    private static let diagnosticMethods = [
        "getCapabilities",
        "debugLog",
        "logAnalyticsEvent",
        "getCachedVideoURL",
        "prefetchVideo",
        "getTemplateFeedCache",
        "setTemplateFeedCache",
        "getTemplateDetailCache",
        "setTemplateDetailCache"
    ]
    #endif
    private static let toastViewTag = 92_051_502

    private weak var host: BSideBridgeHost?
    private var pendingPhotoRequestId: String?
    private weak var activePaymentBrowser: BSidePaymentController?
    private var activePaymentBrowserContext: [String: Any]?
    private var activePaymentRequestId: String?

    init(host: BSideBridgeHost) {
        self.host = host
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePushPayloadNotification(_:)),
            name: .vivideBSidePushPayloadReceived,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePushTokenNotification(_:)),
            name: .vivideBSidePushTokenUpdated,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePaymentCallbackNotification(_:)),
            name: .vivideBSidePaymentCallbackReceived,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePaymentTransactionNotification(_:)),
            name: .vivideBSidePaymentTransactionUpdated,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard
            let body = message.body as? [String: Any],
            let requestId = body["requestId"] as? String,
            let typeName = body["typeName"] as? String
        else { return }

        switch typeName {
        #if DEBUG
        case "getCapabilities":
            respond(requestId: requestId, result: [
                "bridgeVersion": Self.bridgeVersion,
                "messageName": Self.messageName,
                "typeNames": Self.diagnosticMethods
            ])
        case "debugLog":
            if BSideConfig.debugLogging {
                let params = body["params"] as? [String: Any]
                let level = (params?["level"] as? String) ?? "log"
                let message = (params?["message"] as? String) ?? ""
                print("🧭 [BSide \(level)] \(message)")
            }
            respond(requestId: requestId, result: ["logged": true])
        case "logAnalyticsEvent":
            let params = Self.params(from: body)
            let eventName = Self.eventNameParam(from: params)
            let eventValues = Self.eventValuesParam(from: params)
            let channel = Self.stringParam("channel", from: body)
            Task {
                let result = await VivideAFManager.shared.logEvent(
                    channelId: channel,
                    eventName: eventName,
                    values: eventValues
                )
                await MainActor.run {
                    if (result["logged"] as? Bool) == true {
                        self.respond(requestId: requestId, result: result)
                    } else {
                        self.respond(requestId: requestId, error: [
                            "code": (result["code"] as? String) ?? "AF_LOG_EVENT_FAILED",
                            "message": (result["message"] as? String) ?? "AppsFlyer logEvent failed."
                        ])
                    }
                }
            }
        case "getCachedVideoURL":
            let urlString = Self.stringParam("url", from: body)
            let cachedURL = BSideMediaCache.shared.displayURL(for: urlString, mediaType: "video")
            respond(requestId: requestId, result: [
                "url": cachedURL?.absoluteString ?? NSNull(),
                "cached": cachedURL != nil
            ])
        case "prefetchVideo":
            let urlString = Self.stringParam("url", from: body)
            Task {
                _ = await BSideMediaCache.shared.prefetch(remoteURLString: urlString, mediaType: "video")
                let cachedURL = BSideMediaCache.shared.displayURL(for: urlString, mediaType: "video")
                await MainActor.run {
                    self.respond(requestId: requestId, result: [
                        "url": cachedURL?.absoluteString ?? NSNull(),
                        "cached": cachedURL != nil
                    ])
                }
            }
        case "getTemplateFeedCache":
            let key = Self.stringParam("key", from: body)
            respond(requestId: requestId, result: BSideJSONCache.shared.value(namespace: "templateFeed", key: key))
        case "setTemplateFeedCache":
            let params = Self.params(from: body)
            let key = params["key"] as? String ?? ""
            let value = params["value"] ?? NSNull()
            let ttl = params["ttlSeconds"] as? TimeInterval
            let saved = BSideJSONCache.shared.setValue(namespace: "templateFeed", key: key, value: value, ttlSeconds: ttl)
            respond(requestId: requestId, result: ["saved": saved])
        case "getTemplateDetailCache":
            let key = Self.stringParam("key", from: body)
            respond(requestId: requestId, result: BSideJSONCache.shared.value(namespace: "templateDetail", key: key))
        case "setTemplateDetailCache":
            let params = Self.params(from: body)
            let key = params["key"] as? String ?? ""
            let value = params["value"] ?? NSNull()
            let ttl = params["ttlSeconds"] as? TimeInterval
            let saved = BSideJSONCache.shared.setValue(namespace: "templateDetail", key: key, value: value, ttlSeconds: ttl)
            respond(requestId: requestId, result: ["saved": saved])
        #endif
        case "getAppInfo":
            let appLocale = AppSettings.resolvedL10nCode()
            let storedLanguage = UserDefaults.standard.string(forKey: "vivide_language") ?? AppLanguage.system.rawValue
            var result: [String: Any] = [
                "platform": "ios",
                "appName": BSideConfig.appDisplayName,
                "appVersion": BSideConfig.appVersion,
                "systemVersion": UIDevice.current.systemVersion,
                "systemLocale": storedLanguage == AppLanguage.system.rawValue
                    ? Locale.current.identifier
                    : appLocale,
                "appLanguage": storedLanguage,
                "appLocale": appLocale
            ]
            if let privacyURL = BSideConfig.privacyURL {
                result["privacyURL"] = privacyURL.absoluteString
            }
            #if DEBUG
            result["buildConfiguration"] = BSideConfig.buildConfigurationLabel
            result["bridgeVersion"] = Self.bridgeVersion
            result["deviceModel"] = UIDevice.current.model
            result["debugTypeNames"] = Self.diagnosticMethods
            #endif
            if let channel = BSideConfig.channel {
                result["channel"] = channel
            }
            respond(requestId: requestId, result: result)
        case "prepareLoginAttribution":
            let channel = Self.stringParam("channel", from: body)
            Task {
                let result = await VivideAFManager.shared.prepareLoginAttribution(channelId: channel)
                await MainActor.run {
                    self.respond(requestId: requestId, result: result)
                }
            }
        case "markLoginCompleted":
            VivideAFManager.shared.markLoginCompleted()
            respond(requestId: requestId, result: ["completed": true])
        case "Ready":
            host?.hostMarkReady()
            respond(requestId: requestId, result: ["ready": true])
        case "getCachedMediaURL":
            let urlString = Self.stringParam("url", from: body)
            let mediaType = Self.stringParam("mediaType", from: body)
            let cachedURL = BSideMediaCache.shared.displayURL(for: urlString, mediaType: mediaType)
            respond(requestId: requestId, result: [
                "url": cachedURL?.absoluteString ?? NSNull(),
                "cached": cachedURL != nil
            ])
        case "prefetchMedia":
            let urlString = Self.stringParam("url", from: body)
            let mediaType = Self.stringParam("mediaType", from: body)
            Task {
                _ = await BSideMediaCache.shared.prefetch(remoteURLString: urlString, mediaType: mediaType)
                let cachedURL = BSideMediaCache.shared.displayURL(for: urlString, mediaType: mediaType)
                await MainActor.run {
                    self.respond(requestId: requestId, result: [
                        "url": cachedURL?.absoluteString ?? NSNull(),
                        "cached": cachedURL != nil
                    ])
                }
            }
        case "saveMediaToAlbum":
            let urlString = Self.stringParam("url", from: body)
            let mediaType = Self.stringParam("mediaType", from: body)
            let fileName = Self.stringParam("fileName", from: body)
            Task {
                do {
                    let result = try await Self.saveMediaToAlbum(urlString: urlString, mediaType: mediaType, fileName: fileName)
                    await MainActor.run {
                        self.respond(requestId: requestId, result: result)
                    }
                } catch {
                    let nsError = error as NSError
                    let code = nsError.domain == "BSideAlbum" && nsError.code == -2
                        ? "PHOTO_LIBRARY_PERMISSION_DENIED"
                        : "SAVE_ALBUM_FAILED"
                    await MainActor.run {
                        self.respond(requestId: requestId, error: [
                            "code": code,
                            "message": error.localizedDescription
                        ])
                    }
                }
            }
        case "getJSONCache":
            let params = Self.params(from: body)
            let namespace = params["namespace"] as? String ?? "default"
            let key = params["key"] as? String ?? ""
            respond(requestId: requestId, result: BSideJSONCache.shared.value(namespace: namespace, key: key))
        case "setJSONCache":
            let params = Self.params(from: body)
            let namespace = params["namespace"] as? String ?? "default"
            let key = params["key"] as? String ?? ""
            let value = params["value"] ?? NSNull()
            let ttl = params["ttlSeconds"] as? TimeInterval
            let saved = BSideJSONCache.shared.setValue(namespace: namespace, key: key, value: value, ttlSeconds: ttl)
            respond(requestId: requestId, result: ["saved": saved])
        case "pickPhoto":
            guard pendingPhotoRequestId == nil else {
                respond(requestId: requestId, error: [
                    "code": "PHOTO_PICKER_BUSY",
                    "message": "Photo picker is already presented"
                ])
                return
            }
            pendingPhotoRequestId = requestId
            presentPhotoPicker()
        case "clearCache":
            let jsonFiles = BSideJSONCache.shared.clearAll()
            let mediaFiles = BSideMediaCache.shared.clearAll()
            respond(requestId: requestId, result: [
                "cleared": jsonFiles > 0 || mediaFiles > 0,
                "jsonFiles": jsonFiles,
                "mediaFiles": mediaFiles
            ])
        case "registerPush":
            VividePushManager.shared.register { [weak self] result in
                DispatchQueue.main.async {
                    self?.respond(requestId: requestId, result: result)
                }
            }
        case "getLaunchPushPayload":
            respond(requestId: requestId, result: VividePushManager.shared.consumeLaunchPayload())
        case "openPayment":
            let urlString = Self.stringParam("url", from: body)
            let type = Self.stringParam("type", from: body)
            if type == "apple_pay" && urlString.isEmpty {
                let params = Self.params(from: body)
                Task {
                    let result = await VividePaymentManager.shared.purchase(params: params)
                    await MainActor.run {
                        self.respond(requestId: requestId, result: result)
                    }
                }
                return
            }
            guard let url = URL(string: urlString) else {
                respond(requestId: requestId, error: [
                    "code": "INVALID_URL",
                    "message": "Payment URL is invalid"
                ])
                return
            }
            let opened = presentPaymentBrowser(url: url, params: Self.params(from: body), requestId: requestId)
            if !opened {
                respond(requestId: requestId, result: ["opened": false, "status": "failed"])
            }
        case "restorePayment":
            Task {
                let result = await VividePaymentManager.shared.restoreTransactions()
                await MainActor.run {
                    self.respond(requestId: requestId, result: result)
                }
            }
        case "finishPaymentTransaction":
            let transactionId = Self.stringParam("transactionId", from: body)
            Task {
                let result = await VividePaymentManager.shared.finishTransaction(transactionId: transactionId)
                await MainActor.run {
                    self.respond(requestId: requestId, result: result)
                }
            }
        case "openURL":
            let urlString = Self.stringParam("url", from: body)
            guard let url = URL(string: urlString), UIApplication.shared.canOpenURL(url) else {
                respond(requestId: requestId, result: ["opened": false])
                return
            }
            UIApplication.shared.open(url) { [weak self] opened in
                self?.respond(requestId: requestId, result: ["opened": opened])
            }
        case "openWebView":
            let urlString = Self.stringParam("url", from: body)
            let title = Self.stringParam("title", from: body)
            guard let url = URL(string: urlString), ["http", "https"].contains(url.scheme?.lowercased() ?? "") else {
                respond(requestId: requestId, result: ["opened": false])
                return
            }
            let opened = presentBrowserWebView(url: url, title: title)
            respond(requestId: requestId, result: ["opened": opened])
        case "openSettings":
            guard let url = URL(string: UIApplication.openSettingsURLString) else {
                respond(requestId: requestId, result: ["opened": false])
                return
            }
            UIApplication.shared.open(url) { [weak self] opened in
                self?.respond(requestId: requestId, result: ["opened": opened])
            }
        case "showToast":
            let message = Self.stringParam("message", from: body)
            showToast(message: message)
            respond(requestId: requestId, result: ["shown": !message.isEmpty])
        case "back":
            if host?.hostWebView.canGoBack == true {
                host?.hostWebView.goBack()
                respond(requestId: requestId, result: ["handled": true])
            } else {
                respond(requestId: requestId, result: ["handled": false])
            }
        default:
            respond(requestId: requestId, error: [
                "code": "METHOD_NOT_IMPLEMENTED",
                "message": "Native action is not implemented: \(typeName)"
            ])
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        host?.hostNavigationFinished()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        host?.hostFail(error.localizedDescription)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        host?.hostFail(error.localizedDescription)
    }

    private func respond(requestId: String, result: [String: Any]) {
        send(requestId: requestId, payload: ["ok": true, "result": result])
    }

    private func respond(requestId: String, error: [String: Any]) {
        send(requestId: requestId, payload: ["ok": false, "error": error])
    }

    private func send(requestId: String, payload: [String: Any]) {
        guard
            let data = try? JSONSerialization.data(withJSONObject: payload),
            let json = String(data: data, encoding: .utf8)
        else { return }

        let escapedId = requestId.replacingOccurrences(of: "'", with: "\\'")
        let script = "window.__syncAppInfoResolve && window.__syncAppInfoResolve('\(escapedId)', \(json));"
        DispatchQueue.main.async { [weak host] in
            host?.hostWebView.evaluateJavaScript(script)
        }
    }

    func dispatchNativeEvent(name: String, payload: [String: Any]) {
        let detail: [String: Any] = ["name": name, "payload": payload]
        guard
            let data = try? JSONSerialization.data(withJSONObject: detail),
            let json = String(data: data, encoding: .utf8)
        else { return }

        let script = "window.dispatchEvent(new CustomEvent('peachgen:native-event', { detail: \(json) }));"
        DispatchQueue.main.async { [weak host] in
            host?.hostWebView.evaluateJavaScript(script)
        }
    }

    @objc private func handlePushPayloadNotification(_ notification: Notification) {
        guard let payload = notification.userInfo?["payload"] as? [String: Any] else { return }
        let source = notification.userInfo?["source"] as? String ?? "unknown"
        presentForegroundPushToastIfNeeded(payload: payload, source: source)
        dispatchNativeEvent(name: "push.payload", payload: payload)
    }

    @objc private func handlePushTokenNotification(_ notification: Notification) {
        guard let token = notification.userInfo?["token"] as? String, !token.isEmpty else { return }
        dispatchNativeEvent(name: "push.token", payload: ["token": token])
    }

    @objc private func handlePaymentCallbackNotification(_ notification: Notification) {
        guard let payload = notification.userInfo?["payload"] as? [String: Any] else { return }
        let hasActiveRequest = activePaymentRequestId != nil
        if let requestId = activePaymentRequestId {
            activePaymentRequestId = nil
            respond(requestId: requestId, result: payload)
        }
        activePaymentBrowserContext = nil
        dismissActivePaymentBrowser()
        if !hasActiveRequest {
            dispatchNativeEvent(name: "payment.callback", payload: payload)
        }
    }

    @objc private func handlePaymentTransactionNotification(_ notification: Notification) {
        guard let payload = notification.userInfo?["payload"] as? [String: Any] else { return }
        dispatchNativeEvent(name: "payment.transaction", payload: payload)
    }

    private func presentForegroundPushToastIfNeeded(payload: [String: Any], source: String) {
        guard source.contains("willPresent") || source.contains("foreground") else { return }
        let message = (payload["title"] as? String)
            ?? (payload["body"] as? String)
            ?? (payload["alert"] as? String)
        guard let message, !message.isEmpty else { return }
        showToast(message: message)
    }

    private func presentPaymentBrowser(url: URL, params: [String: Any], requestId: String) -> Bool {
        guard let presenter = Self.topViewController() else { return false }
        if let activePaymentBrowser {
            if let activePaymentRequestId {
                respond(requestId: activePaymentRequestId, result: [
                    "opened": false,
                    "status": "cancelled",
                    "result": "cancelled",
                    "message": "Payment page was replaced."
                ])
            }
            activePaymentRequestId = nil
            activePaymentBrowser.dismiss(animated: false)
        }

        activePaymentRequestId = requestId
        activePaymentBrowserContext = paymentBrowserContext(from: params, url: url)
        let browser = BSidePaymentController(url: url) { [weak self] in
            self?.handlePaymentBrowserClosed()
        }
        browser.modalPresentationStyle = .fullScreen
        activePaymentBrowser = browser
        presenter.present(browser, animated: true)
        return true
    }

    private func paymentBrowserContext(from params: [String: Any], url: URL) -> [String: Any] {
        var context: [String: Any] = [
            "url": url.absoluteString,
            "status": "cancelled",
            "message": "Payment page was closed."
        ]
        for key in ["orderId", "order_id", "payChannelId", "pay_channel_id", "packageId", "package_id", "type"] {
            if let value = params[key] {
                context[key] = value
            }
        }
        if context["order_id"] == nil, let orderId = context["orderId"] {
            context["order_id"] = orderId
        }
        return context
    }

    private func dismissActivePaymentBrowser() {
        guard let browser = activePaymentBrowser else { return }
        activePaymentBrowser = nil
        browser.dismiss(animated: true)
    }

    private func handlePaymentBrowserClosed() {
        activePaymentBrowser = nil

        var payload = activePaymentBrowserContext ?? [:]
        payload["status"] = payload["status"] ?? "cancelled"
        payload["result"] = payload["result"] ?? "cancelled"
        activePaymentBrowserContext = nil
        if let requestId = activePaymentRequestId {
            activePaymentRequestId = nil
            respond(requestId: requestId, result: payload)
        }
    }

    private func showToast(message: String) {
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty else { return }

        DispatchQueue.main.async {
            guard let container = Self.topViewController()?.view else { return }
            container.viewWithTag(Self.toastViewTag)?.removeFromSuperview()

            let toast = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
            toast.tag = Self.toastViewTag
            toast.alpha = 0
            toast.layer.cornerRadius = 18
            toast.clipsToBounds = true

            let label = UILabel()
            label.text = trimmedMessage
            label.textColor = UIColor.white.withAlphaComponent(0.92)
            label.font = .systemFont(ofSize: 15, weight: .semibold)
            label.numberOfLines = 2
            label.textAlignment = .center

            container.addSubview(toast)
            toast.contentView.addSubview(label)
            toast.translatesAutoresizingMaskIntoConstraints = false
            label.translatesAutoresizingMaskIntoConstraints = false

            NSLayoutConstraint.activate([
                toast.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                toast.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                toast.widthAnchor.constraint(lessThanOrEqualTo: container.widthAnchor, constant: -64),
                label.leadingAnchor.constraint(equalTo: toast.contentView.leadingAnchor, constant: 18),
                label.trailingAnchor.constraint(equalTo: toast.contentView.trailingAnchor, constant: -18),
                label.topAnchor.constraint(equalTo: toast.contentView.topAnchor, constant: 12),
                label.bottomAnchor.constraint(equalTo: toast.contentView.bottomAnchor, constant: -12)
            ])

            UIView.animate(withDuration: 0.18) {
                toast.alpha = 1
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                UIView.animate(withDuration: 0.2) {
                    toast.alpha = 0
                } completion: { _ in
                    toast.removeFromSuperview()
                }
            }
        }
    }

    private func presentBrowserWebView(url: URL, title: String) -> Bool {
        guard let presenter = Self.topViewController() else { return false }
        let browser = BSidePageController(
            url: url,
            title: title.isEmpty ? BSideConfig.appDisplayName : title
        )
        browser.modalPresentationStyle = .fullScreen
        presenter.present(browser, animated: true)
        return true
    }

    private func presentPhotoPicker() {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = 1

        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self

        guard let presenter = Self.topViewController() else {
            if let requestId = pendingPhotoRequestId {
                respond(requestId: requestId, error: [
                    "code": "PRESENTER_UNAVAILABLE",
                    "message": "Unable to present photo picker"
                ])
            }
            pendingPhotoRequestId = nil
            return
        }

        presenter.present(picker, animated: true)
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)

        guard let requestId = pendingPhotoRequestId else { return }
        pendingPhotoRequestId = nil

        guard let provider = results.first?.itemProvider else {
            respond(requestId: requestId, error: [
                "code": "PHOTO_CANCELLED",
                "message": "Photo selection was cancelled"
            ])
            return
        }

        guard provider.canLoadObject(ofClass: UIImage.self) else {
            respond(requestId: requestId, error: [
                "code": "PHOTO_UNSUPPORTED",
                "message": "Selected item is not a supported image"
            ])
            return
        }

        provider.loadObject(ofClass: UIImage.self) { [weak self] object, error in
            if let error {
                DispatchQueue.main.async {
                    self?.respond(requestId: requestId, error: [
                        "code": "PHOTO_LOAD_FAILED",
                        "message": error.localizedDescription
                    ])
                }
                return
            }

            guard let image = object as? UIImage,
                  let encodedPhoto = Self.encodePhotoForBridge(image) else {
                DispatchQueue.main.async {
                    self?.respond(requestId: requestId, error: [
                        "code": "PHOTO_ENCODE_FAILED",
                        "message": "Unable to encode selected photo"
                    ])
                }
                return
            }

            let base64 = encodedPhoto.data.base64EncodedString()
            DispatchQueue.main.async {
                self?.respond(requestId: requestId, result: [
                    "dataURL": "data:image/jpeg;base64,\(base64)",
                    "fileName": "photo.jpg",
                    "mimeType": "image/jpeg",
                    "width": encodedPhoto.width,
                    "height": encodedPhoto.height,
                    "fileSize": encodedPhoto.data.count,
                    "validation": [
                        "isValid": true,
                        "skipped": true,
                        "faceCount": 0,
                        "reasons": [] as [String]
                    ]
                ])
            }
        }
    }

    private static func stringParam(_ key: String, from body: [String: Any]) -> String {
        params(from: body)[key] as? String ?? ""
    }

    private static func params(from body: [String: Any]) -> [String: Any] {
        body["params"] as? [String: Any] ?? [:]
    }

    private static func eventNameParam(from params: [String: Any]) -> String {
        let candidates = ["eventName", "name", "event"]
        for key in candidates {
            if let value = params[key] as? String {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { return trimmed }
            }
        }
        return ""
    }

    private static func eventValuesParam(from params: [String: Any]) -> [String: Any]? {
        let candidates = ["values", "eventValues", "params", "properties"]
        for key in candidates {
            if let value = params[key] as? [String: Any] {
                return value
            }
        }
        return nil
    }

    private static func saveMediaToAlbum(urlString: String, mediaType: String, fileName: String) async throws -> [String: Any] {
        guard !urlString.isEmpty, let url = URL(string: urlString) else {
            throw NSError(domain: "BSideAlbum", code: -1, userInfo: [NSLocalizedDescriptionKey: "Media URL is invalid"])
        }

        let authorized = await requestPhotoAddPermission()
        guard authorized else {
            throw NSError(domain: "BSideAlbum", code: -2, userInfo: [NSLocalizedDescriptionKey: "Photo library permission denied"])
        }

        let resolvedType = resolveMediaType(mediaType: mediaType, url: url, fileName: fileName)
        if resolvedType == "video" {
            let (localURL, shouldCleanupLocalURL) = try await localMediaURL(
                for: url,
                originalURLString: urlString,
                mediaType: resolvedType,
                fileName: fileName.isEmpty ? "creation.mp4" : fileName
            )
            defer {
                if shouldCleanupLocalURL {
                    try? FileManager.default.removeItem(at: localURL)
                }
            }
            var requested = false
            try await PHPhotoLibrary.shared().performChanges {
                requested = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: localURL) != nil
            }
            guard requested else {
                throw NSError(domain: "BSideAlbum", code: -3, userInfo: [NSLocalizedDescriptionKey: "Unable to save video"])
            }
            return ["saved": true, "mediaType": "video"]
        }

        let data = try await mediaData(from: url, originalURLString: urlString, mediaType: resolvedType)
        guard let image = UIImage(data: data) else {
            throw NSError(domain: "BSideAlbum", code: -4, userInfo: [NSLocalizedDescriptionKey: "Unable to read image"])
        }
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }
        return ["saved": true, "mediaType": "image"]
    }

    private static func requestPhotoAddPermission() async -> Bool {
        let current = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        if current == .authorized || current == .limited { return true }
        if current == .denied || current == .restricted { return false }
        let next = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        return next == .authorized || next == .limited
    }

    private static func resolveMediaType(mediaType: String, url: URL, fileName: String) -> String {
        let raw = mediaType.lowercased()
        if raw == "video" || raw == "image" { return raw }
        let path = (fileName.isEmpty ? url.path : fileName).lowercased()
        if path.hasSuffix(".mp4") || path.hasSuffix(".mov") || path.hasSuffix(".m4v") { return "video" }
        return "image"
    }

    private static func mediaData(from url: URL, originalURLString: String, mediaType: String) async throws -> Data {
        if url.isFileURL {
            return try Data(contentsOf: url)
        }
        if let cachedURL = cachedMediaURLForAlbum(url: url, originalURLString: originalURLString, mediaType: mediaType) {
            return try Data(contentsOf: cachedURL)
        }
        let (data, response) = try await URLSession.shared.data(from: url)
        if let httpResponse = response as? HTTPURLResponse,
           !(200..<300).contains(httpResponse.statusCode) {
            throw NSError(domain: "BSideAlbum", code: -5, userInfo: [NSLocalizedDescriptionKey: "Media download failed"])
        }
        return data
    }

    private static func localMediaURL(for url: URL, originalURLString: String, mediaType: String, fileName: String) async throws -> (url: URL, shouldCleanup: Bool) {
        if url.isFileURL { return (url, false) }
        if let cachedURL = cachedMediaURLForAlbum(url: url, originalURLString: originalURLString, mediaType: mediaType) {
            return (cachedURL, false)
        }
        let remoteURLString = cacheSourceURLString(from: url, fallback: originalURLString)
        if !remoteURLString.isEmpty,
           let prefetchedURL = await BSideMediaCache.shared.prefetch(remoteURLString: remoteURLString, mediaType: mediaType) {
            return (prefetchedURL, false)
        }
        return try await downloadMediaToTemporaryFile(from: url, fileName: fileName)
    }

    private static func downloadMediaToTemporaryFile(from url: URL, fileName: String) async throws -> (url: URL, shouldCleanup: Bool) {
        let (downloadedURL, response) = try await URLSession.shared.download(from: url)
        if let httpResponse = response as? HTTPURLResponse,
           !(200..<300).contains(httpResponse.statusCode) {
            try? FileManager.default.removeItem(at: downloadedURL)
            throw NSError(domain: "BSideAlbum", code: -5, userInfo: [NSLocalizedDescriptionKey: "Media download failed"])
        }
        let safeName = fileName.replacingOccurrences(of: "/", with: "_")
        let fallbackExtension = (safeName as NSString).pathExtension.isEmpty
            ? (url.pathExtension.isEmpty ? "mp4" : url.pathExtension)
            : (safeName as NSString).pathExtension
        let localURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(fallbackExtension)
        try FileManager.default.moveItem(at: downloadedURL, to: localURL)
        return (localURL, true)
    }

    private static func cachedMediaURLForAlbum(url: URL, originalURLString: String, mediaType: String) -> URL? {
        let remoteURLString = cacheSourceURLString(from: url, fallback: originalURLString)
        guard !remoteURLString.isEmpty else { return nil }
        return BSideMediaCache.shared.cachedURL(for: remoteURLString, mediaType: mediaType)
    }

    private static func cacheSourceURLString(from url: URL, fallback: String) -> String {
        if url.scheme == MediaCacheSchemeHandler.scheme,
           let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let remote = components.queryItems?.first(where: { $0.name == "url" })?.value,
           !remote.isEmpty {
            return remote
        }
        return fallback
    }

    private static func encodePhotoForBridge(_ image: UIImage) -> (data: Data, width: Int, height: Int)? {
        let maxPixel: CGFloat = 2048
        let maxBytes = 12 * 1024 * 1024
        let sourceWidth = image.size.width * image.scale
        let sourceHeight = image.size.height * image.scale
        let longestSide = max(sourceWidth, sourceHeight)
        let resizeScale = longestSide > maxPixel ? maxPixel / longestSide : 1
        let outputWidth = max(1, Int(sourceWidth * resizeScale))
        let outputHeight = max(1, Int(sourceHeight * resizeScale))
        let outputSize = CGSize(width: outputWidth, height: outputHeight)
        let outputImage: UIImage

        if resizeScale < 1 {
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            outputImage = UIGraphicsImageRenderer(size: outputSize, format: format).image { _ in
                image.draw(in: CGRect(origin: .zero, size: outputSize))
            }
        } else {
            outputImage = image
        }

        let qualities: [CGFloat] = [0.9, 0.82, 0.74, 0.66, 0.58, 0.5]
        for quality in qualities {
            guard let data = outputImage.jpegData(compressionQuality: quality) else { continue }
            if data.count <= maxBytes || quality == qualities.last {
                return (data, outputWidth, outputHeight)
            }
        }
        return nil
    }

    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        var controller = scene?.windows.first { $0.isKeyWindow }?.rootViewController

        while let presented = controller?.presentedViewController {
            controller = presented
        }
        return controller
    }
}
