import Combine
import Foundation

@MainActor
final class BSideManager: ObservableObject {
    static let shared = BSideManager()

    enum Phase: Equatable {
        case loading
        case native
        case web(URL)
    }

    @Published private(set) var phase: Phase = .loading

    var canSwitchToBSide: Bool {
        #if DEBUG
        return BSideConfig.isConfigured
        #else
        return false
        #endif
    }

    private var bootstrapInFlight: Task<Void, Never>?
    private var remoteRefreshInFlight: Task<Void, Never>?
    private var attributionUpdateObserver: NSObjectProtocol?

    private init() {
        phase = Self.initialPhase()
        attributionUpdateObserver = NotificationCenter.default.addObserver(
            forName: .vivideAFAttributionDidUpdate,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                // 首启因超时已用占位 JSON 打过 app_config 时，迟到归因强制补传
                await self?.refreshIfNeeded(force: true)
            }
        }
    }

    deinit {
        if let attributionUpdateObserver {
            NotificationCenter.default.removeObserver(attributionUpdateObserver)
        }
    }

    func bootstrapFromRemote() async {
        if VivideAppConfigPersistence.hasPersistedSuccessfulFetch {
            await applyPersistedPresentationType(VivideAppConfigPersistence.readPersistedPresentationType())
            Task(priority: .utility) { await self.refreshIfNeeded() }
            return
        }

        if !VivideAPIConfig.isConfigured {
            await prepareAffiliationOnly()
            phase = .native
            return
        }

        if let inFlight = bootstrapInFlight {
            await inFlight.value
            return
        }

        let task = Task { await self.performFirstLaunchBootstrap() }
        bootstrapInFlight = task
        await task.value
        bootstrapInFlight = nil
    }

    func refreshIfNeeded(minInterval: TimeInterval = 300, force: Bool = false) async {
        guard VivideAPIConfig.isConfigured else { return }

        if !VivideAppConfigPersistence.hasPersistedSuccessfulFetch {
            await bootstrapFromRemote()
            return
        }

        if !force {
            let last = UserDefaults.standard.double(forKey: VivideAppConfigPersistence.lastRemoteRefreshKey)
            guard last <= 0 || Date().timeIntervalSince1970 - last >= minInterval else { return }
        }

        if let inFlight = remoteRefreshInFlight {
            await inFlight.value
            return
        }

        let task = Task { await self.fetchAppConfigFromNetwork() }
        remoteRefreshInFlight = task
        await task.value
        remoteRefreshInFlight = nil
    }

    func switchToBSide() async {
        if let url = await resolveBSideURL() {
            phase = .web(url)
            VivideAppConfigPersistence.persistSuccessfulPresentationType(2)
        }
    }

    func switchToNative() {
        phase = .native
        VivideAppConfigPersistence.persistSuccessfulPresentationType(1, force: true)
    }

    private static func initialPhase() -> Phase {
        guard VivideAppConfigPersistence.hasPersistedSuccessfulFetch else {
            return VivideAPIConfig.isConfigured ? .loading : .native
        }
        let type = VivideAppConfigPersistence.readPersistedPresentationType()
        if type == 2, BSideConfig.isConfigured {
            return .loading
        }
        return .native
    }

    private func performFirstLaunchBootstrap() async {
        phase = .loading
        let attribution = await prepareAffiliationOnly()
        // 对齐流程图：仅 onConversionDataSuccess 归因缓存后才请求 app_config
        guard let attribution, attribution.hasRealAttributionPayload else {
            applyFirstLaunchFailure(reason: "waiting_af_conversion_or_unavailable")
            return
        }
        let channel = await VivideAppConfig.shared.getChannel()
        await applyAppConfigResponse(await requestAppConfig(channel: channel, attribution: attribution))
    }

    @discardableResult
    private func prepareAffiliationOnly() async -> AFAttributionResult? {
        let channel = await VivideAppConfig.shared.getChannel()
        await VivideAFManager.shared.initAFAsync(channelId: channel)
        let (_, attribution) = await VivideAFManager.shared.prepareForFirstLaunch(channelId: channel)
        return attribution
    }

    private func fetchAppConfigFromNetwork() async {
        let channel = await VivideAppConfig.shared.getChannel()
        let rawAttribution = await VivideAFManager.shared.getAttributionForLogin()
        // 刷新同样要求真实 conversion，避免 timeout 占位回传
        guard let attribution = rawAttribution, attribution.hasRealAttributionPayload else {
            if BSideConfig.debugLogging {
                print("⏭ [BSideManager] skip app_config refresh: no conversion attribution yet")
            }
            return
        }
        let result = await requestAppConfig(channel: channel, attribution: attribution)
        if case .success = result {
            UserDefaults.standard.set(
                Date().timeIntervalSince1970,
                forKey: VivideAppConfigPersistence.lastRemoteRefreshKey
            )
        }
        await applyAppConfigResponse(result)
    }

    private func requestAppConfig(
        channel: String,
        attribution: AFAttributionResult
    ) async -> Result<VivideAppConfigResponse, VivideAppConfigError> {
        let deviceId = await VivideDeviceManager.shared.getDeviceId()
        let version = await VivideDeviceManager.shared.getAppVersion()
        let request = VivideAppConfigRequest(
            devId: deviceId,
            source: attribution.source,
            channel: channel,
            version: version,
            afId: attribution.afId,
            afAttributionJson: attribution.attributionJson
        )
        return await VivideAppConfigService.fetchAppConfig(request: request)
    }

    private func applyAppConfigResponse(_ result: Result<VivideAppConfigResponse, VivideAppConfigError>) async {
        switch result {
        case .success(let response):
            if let type = response.type, type == 1 || type == 2 {
                // type=2 持久化后粘性保留：刷新若返回 1，仍按本地 2 进 B 面
                let effectiveType = VivideAppConfigPersistence.hasPersistedBSide ? 2 : type
                VivideAppConfigPersistence.persistSuccessfulPresentationType(type)
                await applyPresentationType(effectiveType)
            } else if VivideAppConfigPersistence.hasPersistedBSide {
                await applyPresentationType(2)
            } else if !VivideAppConfigPersistence.hasPersistedSuccessfulFetch {
                applyFirstLaunchFailure(reason: "invalid_type")
            }
        case .failure(let error):
            if VivideAppConfigPersistence.hasPersistedBSide {
                await applyPresentationType(2)
            } else if !VivideAppConfigPersistence.hasPersistedSuccessfulFetch {
                applyFirstLaunchFailure(reason: error.localizedDescription)
            }
        }
    }

    private func applyPresentationType(_ type: Int) async {
        if type == 2, let url = await resolveBSideURL() {
            phase = .web(url)
        } else {
            phase = .native
        }
    }

    private func applyPersistedPresentationType(_ type: Int) async {
        if type == 2, let url = await resolveBSideURL() {
            phase = .web(url)
        } else {
            phase = .native
        }
    }

    private func applyFirstLaunchFailure(reason: String) {
        phase = .native
        if BSideConfig.debugLogging {
            print("❌ [BSideManager] app_config 首启失败(\(reason))，进 A 面且不保存")
        }
    }

    private func resolveBSideURL() async -> URL? {
        let deviceId = await VivideDeviceManager.shared.getDeviceId()
        let channel = await VivideAppConfig.shared.getChannel()
        let baseURL: URL?
        #if DEBUG
        if let debugURL = BSideConfig.debugEnvURL() {
            baseURL = debugURL
        } else if let localURL = BSideConfig.localURL {
            baseURL = localURL
        } else if let configURL = BSideConfig.remoteConfigURL {
            baseURL = await fetchRemoteURL(from: configURL)
        } else if let codeURL = BSideConfig.codeFallbackURL() {
            baseURL = codeURL
        } else {
            baseURL = nil
        }
        #else
        if let localURL = BSideConfig.localURL {
            baseURL = localURL
        } else if let configURL = BSideConfig.remoteConfigURL {
            baseURL = await fetchRemoteURL(from: configURL)
        } else if let codeURL = BSideConfig.codeFallbackURL() {
            baseURL = codeURL
        } else {
            baseURL = nil
        }
        #endif
        guard let baseURL else { return nil }
        return BSideConfig.urlAppendingLaunchParams(baseURL, channel: channel, deviceId: deviceId)
    }

    private func fetchRemoteURL(from configURL: URL) async -> URL? {
        var request = URLRequest(url: configURL)
        request.timeoutInterval = 8
        request.cachePolicy = .reloadIgnoringLocalCacheData

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse,
                  (200...299).contains(http.statusCode) else { return nil }
            let config = try JSONDecoder().decode(BSideRemoteConfig.self, from: data)
            return config.resolvedURL
        } catch {
            return nil
        }
    }
}
