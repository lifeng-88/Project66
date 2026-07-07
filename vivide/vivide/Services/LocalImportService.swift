import Foundation
import Photos

enum LocalImportService {
    static func importPhotos(
        _ photos: [PhotoInfo],
        folderId: String? = nil,
        skipExisting: Bool = true,
        progress: @escaping (ImportProgressState) -> Void
    ) async -> ImportBatchResult {
        var imported: [LocalPhotoRecord] = []
        var skipped = 0
        var failed = 0

        var records = LocalPhotoStorage.loadRecords()
        let existingIds = LocalPhotoStorage.importedAssetIds(in: folderId)
        let candidates = photos.filter { !skipExisting || !existingIds.contains($0.id) }
        skipped = photos.count - candidates.count
        let total = candidates.count

        for (index, photo) in candidates.enumerated() {
            progress(ImportProgressState(
                current: index,
                total: total,
                filename: photo.filename
            ))

            do {
                let record = try await importSingle(photo: photo, folderId: folderId)
                records.insert(record, at: 0)
                try LocalPhotoStorage.saveRecords(records)
                imported.append(record)
            } catch {
                failed += 1
            }
        }

        progress(ImportProgressState(current: total, total: total, filename: nil))
        return ImportBatchResult(imported: imported, skipped: skipped, failed: failed)
    }

    private static func importSingle(photo: PhotoInfo, folderId: String?) async throws -> LocalPhotoRecord {
        let resources = PHAssetResource.assetResources(for: photo.asset)
        guard let resource = primaryResource(for: photo.asset, resources: resources) else {
            throw LocalImportError.noResource
        }

        let filename = resource.originalFilename
        let destination = LocalPhotoStorage.destinationURL(folderId: folderId, filename: filename, assetId: photo.id)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let options = PHAssetResourceRequestOptions()
            options.isNetworkAccessAllowed = true

            PHAssetResourceManager.default().writeData(for: resource, toFile: destination, options: options) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }

        let attributes = try FileManager.default.attributesOfItem(atPath: destination.path)
        let fileSize = (attributes[.size] as? NSNumber)?.int64Value ?? 0

        return LocalPhotoRecord(
            id: UUID().uuidString,
            sourceAssetId: photo.id,
            filename: destination.lastPathComponent,
            relativePath: destination.lastPathComponent,
            folderId: folderId,
            importedAt: Date(),
            fileSize: fileSize,
            pixelWidth: photo.pixelWidth,
            pixelHeight: photo.pixelHeight,
            creationDate: photo.creationDate,
            duration: photo.isVideo ? photo.duration : nil
        )
    }

    private static func primaryResource(for asset: PHAsset, resources: [PHAssetResource]) -> PHAssetResource? {
        switch asset.mediaType {
        case .video:
            return resources.first { $0.type == .video || $0.type == .fullSizeVideo } ?? resources.first
        case .image:
            return resources.first { $0.type == .photo || $0.type == .fullSizePhoto } ?? resources.first
        default:
            return resources.first
        }
    }
}

enum LocalImportError: LocalizedError {
    case noResource
    case writeFailed

    var errorDescription: String? {
        switch self {
        case .noResource: return "无法读取媒体资源"
        case .writeFailed: return "保存到本地失败"
        }
    }
}
