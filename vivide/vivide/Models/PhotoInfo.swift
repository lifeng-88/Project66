import Photos
import UIKit

enum PhotoMediaKind: String {
    case image
    case video
    case audio
    case unknown
}

enum PhotoSubtypeTag: String, CaseIterable {
    case panorama
    case hdr
    case screenshot
    case livePhoto
    case depthEffect
}

enum PhotoSourceKind: String {
    case userLibrary
    case cloudShared
    case iTunesSynced
    case other
}

struct PhotoInfo: Identifiable {
    let id: String
    let asset: PHAsset
    var thumbnail: UIImage?

    let pixelWidth: Int
    let pixelHeight: Int
    let creationDate: Date?
    let modificationDate: Date?
    let locationDescription: String?
    let mediaKind: PhotoMediaKind
    let subtypeTags: [PhotoSubtypeTag]
    let sourceKind: PhotoSourceKind
    let filename: String?
    let fileSize: Int64?
    let isFavorite: Bool
    let isHidden: Bool
    let duration: TimeInterval

    var resolutionText: String {
        "\(pixelWidth) × \(pixelHeight)"
    }

    var aspectRatioText: String {
        guard pixelHeight > 0 else { return "—" }
        let ratio = Double(pixelWidth) / Double(pixelHeight)
        return String(format: "%.2f : 1", ratio)
    }

    var durationText: String? {
        guard duration > 0 else { return nil }
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = duration >= 3600 ? [.hour, .minute, .second] : [.minute, .second]
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: duration)
    }

    var isVideo: Bool { mediaKind == .video }

    init(asset: PHAsset, filename: String? = nil, fileSize: Int64? = nil) {
        self.id = asset.localIdentifier
        self.asset = asset
        self.pixelWidth = asset.pixelWidth
        self.pixelHeight = asset.pixelHeight
        self.creationDate = asset.creationDate
        self.modificationDate = asset.modificationDate
        self.isFavorite = asset.isFavorite
        self.isHidden = asset.isHidden
        self.duration = asset.duration
        self.filename = filename
        self.fileSize = fileSize

        switch asset.mediaType {
        case .image: mediaKind = .image
        case .video: mediaKind = .video
        case .audio: mediaKind = .audio
        default: mediaKind = .unknown
        }

        var subtypes: [PhotoSubtypeTag] = []
        if asset.mediaSubtypes.contains(.photoPanorama) { subtypes.append(.panorama) }
        if asset.mediaSubtypes.contains(.photoHDR) { subtypes.append(.hdr) }
        if asset.mediaSubtypes.contains(.photoScreenshot) { subtypes.append(.screenshot) }
        if asset.mediaSubtypes.contains(.photoLive) { subtypes.append(.livePhoto) }
        if asset.mediaSubtypes.contains(.photoDepthEffect) { subtypes.append(.depthEffect) }
        self.subtypeTags = subtypes

        switch asset.sourceType {
        case .typeUserLibrary: sourceKind = .userLibrary
        case .typeCloudShared: sourceKind = .cloudShared
        case .typeiTunesSynced: sourceKind = .iTunesSynced
        default: sourceKind = .other
        }

        if let location = asset.location {
            let lat = String(format: "%.4f°", location.coordinate.latitude)
            let lon = String(format: "%.4f°", location.coordinate.longitude)
            locationDescription = "\(lat), \(lon)"
        } else {
            locationDescription = nil
        }
    }
}

extension PhotoMediaKind {
    func localizedTitle(languageCode: String) -> String {
        let key: L10nKey
        switch self {
        case .image: key = .mediaImage
        case .video: key = .mediaVideo
        case .audio: key = .mediaAudio
        case .unknown: key = .mediaUnknown
        }
        return L10n.string(key, language: languageCode)
    }
}

extension PhotoSubtypeTag {
    func localizedTitle(languageCode: String) -> String {
        let key: L10nKey
        switch self {
        case .panorama: key = .subtypePanorama
        case .hdr: key = .subtypeHDR
        case .screenshot: key = .subtypeScreenshot
        case .livePhoto: key = .subtypeLivePhoto
        case .depthEffect: key = .subtypeDepthEffect
        }
        return L10n.string(key, language: languageCode)
    }
}

extension PhotoSourceKind {
    func localizedTitle(languageCode: String) -> String {
        let key: L10nKey
        switch self {
        case .userLibrary: key = .sourceUserLibrary
        case .cloudShared: key = .sourceCloudShared
        case .iTunesSynced: key = .sourceITunes
        case .other: key = .sourceOther
        }
        return L10n.string(key, language: languageCode)
    }
}
