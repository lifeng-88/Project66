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

    @Published private(set) var phase: Phase = .native

    var canSwitchToBSide: Bool {
        #if DEBUG
        return BSideConfig.isConfigured
        #else
        return false
        #endif
    }

    private var bootstrapInFlight: Task<Void, Never>?
    private var remoteRefreshInFlight: Task<Void, Never>?

    private init() {
        phase = Self.initialPhase()
    }

    func bootstrapFromRemote() async {
        if VivideAppConfigPersistence.hasPersistedSuccessfulFetch {
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
        VivideAppConfigPersistence.persistSuccessfulPresentationType(1)
    }

    private static func initialPhase() -> Phase {
        .native
    }

    private func performFirstLaunchBootstrap() async {
        await prepareAffiliationOnly()
        let channel = await VivideAppConfig.shared.getChannel()
        let rawAttribution = await VivideAFManager.shared.getAttributionForLogin()
        await applyAppConfigResponse(await requestAppConfig(channel: channel, attribution: rawAttribution))
    }

    private func prepareAffiliationOnly() async {
        let channel = await VivideAppConfig.shared.getChannel()
        await VivideAFManager.shared.initAFAsync(channelId: channel)
        _ = await VivideAFManager.shared.prepareForFirstLaunch(channelId: channel)
    }

    private func fetchAppConfigFromNetwork() async {
        let channel = await VivideAppConfig.shared.getChannel()
        let rawAttribution = await VivideAFManager.shared.getAttributionForLogin()
        let result = await requestAppConfig(channel: channel, attribution: rawAttribution)
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
        attribution raw: AFAttributionResult?
    ) async -> Result<VivideAppConfigResponse, VivideAppConfigError> {
        let attribution = raw ?? AFAttributionResult.timeoutFallback()
        let deviceId = await VivideDeviceManager.shared.getDeviceId()
        let version = await VivideDeviceManager.shared.getAppVersion()
        let request = VivideAppConfigRequest(
            devId: deviceId,
            source: attribution.source,
            channel: channel,
            version: version,
            afAttributionJson: attribution.attributionJson
        )
        return await VivideAppConfigService.fetchAppConfig(request: request)
    }

    private func applyAppConfigResponse(_ result: Result<VivideAppConfigResponse, VivideAppConfigError>) async {
        switch result {
        case .success(let response):
            if let type = response.type, type == 1 || type == 2 {
                VivideAppConfigPersistence.persistSuccessfulPresentationType(type)
                await applyPresentationType(type)
            } else if !VivideAppConfigPersistence.hasPersistedSuccessfulFetch {
                applyFirstLaunchFailure(reason: "invalid_type")
            }
        case .failure(let error):
            if !VivideAppConfigPersistence.hasPersistedSuccessfulFetch {
                applyFirstLaunchFailure(reason: error.localizedDescription)
            }
        }
    }

    private func applyPresentationType(_ type: Int) async {
        guard type == 1 else { return }
        phase = .native
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
