import Foundation

struct LocalPhotoRecord: Identifiable, Codable, Equatable {
    let id: String
    let sourceAssetId: String
    let filename: String
    let relativePath: String
    let folderId: String?
    let importedAt: Date
    let fileSize: Int64
    let pixelWidth: Int
    let pixelHeight: Int
    let creationDate: Date?
    var isHidden: Bool
    let duration: TimeInterval?

    var resolutionText: String { "\(pixelWidth) × \(pixelHeight)" }

    var fileSizeText: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }

    var isVideo: Bool {
        LocalMediaKind.from(filename: filename) == .video
    }

    var durationText: String? {
        guard let duration, duration > 0 else { return nil }
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = duration >= 3600 ? [.hour, .minute, .second] : [.minute, .second]
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: duration)
    }

    func withHidden(_ hidden: Bool) -> LocalPhotoRecord {
        var copy = self
        copy.isHidden = hidden
        return copy
    }

    func relocated(toFolderId: String?, filename: String) -> LocalPhotoRecord {
        LocalPhotoRecord(
            id: id,
            sourceAssetId: sourceAssetId,
            filename: filename,
            relativePath: filename,
            folderId: toFolderId,
            importedAt: importedAt,
            fileSize: fileSize,
            pixelWidth: pixelWidth,
            pixelHeight: pixelHeight,
            creationDate: creationDate,
            isHidden: isHidden,
            duration: duration
        )
    }

    enum CodingKeys: String, CodingKey {
        case id, sourceAssetId, filename, relativePath, folderId, importedAt
        case fileSize, pixelWidth, pixelHeight, creationDate, isHidden, duration
    }

    init(
        id: String,
        sourceAssetId: String,
        filename: String,
        relativePath: String,
        folderId: String? = nil,
        importedAt: Date,
        fileSize: Int64,
        pixelWidth: Int,
        pixelHeight: Int,
        creationDate: Date?,
        isHidden: Bool = false,
        duration: TimeInterval? = nil
    ) {
        self.id = id
        self.sourceAssetId = sourceAssetId
        self.filename = filename
        self.relativePath = relativePath
        self.folderId = folderId
        self.importedAt = importedAt
        self.fileSize = fileSize
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.creationDate = creationDate
        self.isHidden = isHidden
        self.duration = duration
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        sourceAssetId = try container.decode(String.self, forKey: .sourceAssetId)
        filename = try container.decode(String.self, forKey: .filename)
        relativePath = try container.decode(String.self, forKey: .relativePath)
        folderId = try container.decodeIfPresent(String.self, forKey: .folderId)
        importedAt = try container.decode(Date.self, forKey: .importedAt)
        fileSize = try container.decode(Int64.self, forKey: .fileSize)
        pixelWidth = try container.decode(Int.self, forKey: .pixelWidth)
        pixelHeight = try container.decode(Int.self, forKey: .pixelHeight)
        creationDate = try container.decodeIfPresent(Date.self, forKey: .creationDate)
        isHidden = try container.decodeIfPresent(Bool.self, forKey: .isHidden) ?? false
        duration = try container.decodeIfPresent(TimeInterval.self, forKey: .duration)
    }
}

enum LocalMediaKind {
    case image
    case video
    case unknown

    static func from(filename: String) -> LocalMediaKind {
        let ext = (filename as NSString).pathExtension.lowercased()
        if ["mp4", "mov", "m4v", "avi", "mkv"].contains(ext) { return .video }
        if ["jpg", "jpeg", "png", "heic", "heif", "gif", "webp", "tif", "tiff"].contains(ext) { return .image }
        return .unknown
    }
}

enum LocalLibraryFilter: String, CaseIterable, Identifiable {
    case visible = "可见"
    case hidden = "已隐藏"
    case all = "全部"

    var id: String { rawValue }

    /// 开启「显示隐藏图片」后，二级筛选栏仅展示「全部 / 已隐藏」
    static let hiddenBrowseFilters: [LocalLibraryFilter] = [.all, .hidden]
}

struct ImportBatchResult {
    let imported: [LocalPhotoRecord]
    let skipped: Int
    let failed: Int
}

struct ImportProgressState {
    let current: Int
    let total: Int
    let filename: String?

    var fraction: Double {
        guard total > 0 else { return 0 }
        return Double(current) / Double(total)
    }
}
