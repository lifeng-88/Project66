import Foundation

struct VivideAppConfigRequest {
    let devId: String
    let source: String?
    let channel: String?
    let version: String
    let afId: String?
    let afAttributionJson: String?

    func toRequestParameters() -> [String: Any] {
        var params: [String: Any] = [
            "dev_id": devId,
            "version": version
        ]
        if let source, !source.isEmpty { params["source"] = source }
        if let channel, !channel.isEmpty { params["channel"] = channel }
        if let afId, !afId.isEmpty { params["af_id"] = afId }
        if let afAttributionJson, !afAttributionJson.isEmpty {
            params["af_attribution_json"] = afAttributionJson
        }
        return params
    }
}

struct VivideAppConfigResponse: Decodable {
    let type: Int?

    enum CodingKeys: String, CodingKey {
        case type
        case rechargePresentationType = "recharge_presentation_type"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fromType = Self.decodeFlexibleInt(from: container, forKey: .type)
        let fromSnake = Self.decodeFlexibleInt(from: container, forKey: .rechargePresentationType)
        type = fromType ?? fromSnake
    }

    private static func decodeFlexibleInt(
        from container: KeyedDecodingContainer<CodingKeys>,
        forKey key: CodingKeys
    ) -> Int? {
        if let value = try? container.decode(Int.self, forKey: key) { return value }
        if let raw = try? container.decode(String.self, forKey: key), let value = Int(raw) { return value }
        if let value = try? container.decode(Int32.self, forKey: key) { return Int(value) }
        return nil
    }
}

enum VivideAppConfigPersistence {
    static let presentationTypeKey = "vivide.v1.app_config.presentation_type"
    static let fetchSucceededKey = "vivide.v1.app_config.fetch_succeeded"
    static let lastRemoteRefreshKey = "vivide.v1.app_config.last_remote_refresh"

    static var hasPersistedSuccessfulFetch: Bool {
        UserDefaults.standard.bool(forKey: fetchSucceededKey)
    }

    static func readPersistedPresentationType(defaultValue: Int = 1) -> Int {
        guard let raw = UserDefaults.standard.object(forKey: presentationTypeKey) as? Int else {
            return defaultValue
        }
        return raw == 1 || raw == 2 ? raw : defaultValue
    }

    /// 是否已持久化为 B 面（type=2）。一旦为 true，后续 type=1 不应覆盖。
    static var hasPersistedBSide: Bool {
        hasPersistedSuccessfulFetch && readPersistedPresentationType() == 2
    }

    static func persistSuccessfulPresentationType(_ value: Int, force: Bool = false) {
        guard value == 1 || value == 2 else { return }
        // type=2 粘性：已进过 B 面后，不允许被远程 type=1 降级覆盖（手动切换可 force）
        if value == 1, !force, hasPersistedBSide { return }
        let defaults = UserDefaults.standard
        defaults.set(value, forKey: presentationTypeKey)
        defaults.set(true, forKey: fetchSucceededKey)
    }
}

enum VivideAppConfigError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpStatus(Int)
    case decodingFailed
    case notConfigured

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid app_config URL"
        case .invalidResponse: return "Invalid app_config response"
        case .httpStatus(let code): return "app_config HTTP \(code)"
        case .decodingFailed: return "Failed to decode app_config"
        case .notConfigured: return "API base URL is not configured"
        }
    }
}

enum VivideAppConfigService {
    static func fetchAppConfig(request: VivideAppConfigRequest) async -> Result<VivideAppConfigResponse, VivideAppConfigError> {
        guard let base = VivideAPIConfig.effectiveAPIBaseURL,
              var components = URLComponents(string: base + "/v1/app_config") else {
            return .failure(.notConfigured)
        }

        components.queryItems = request.toRequestParameters().map {
            URLQueryItem(name: $0.key, value: "\($0.value)")
        }

        guard let url = components.url else {
            return .failure(.invalidURL)
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        urlRequest.timeoutInterval = 15
        urlRequest.cachePolicy = .reloadIgnoringLocalCacheData

        do {
            let (data, response) = try await URLSession.shared.data(for: urlRequest)
            guard let http = response as? HTTPURLResponse else {
                return .failure(.invalidResponse)
            }
            guard (200...299).contains(http.statusCode) else {
                return .failure(.httpStatus(http.statusCode))
            }
            let decoded = try JSONDecoder().decode(VivideAppConfigResponse.self, from: data)
            return .success(decoded)
        } catch is DecodingError {
            return .failure(.decodingFailed)
        } catch {
            return .failure(.invalidResponse)
        }
    }
}
