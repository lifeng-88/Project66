import Combine
import Photos
import AVFoundation
import UIKit

enum PhotoLibraryAuthState {
    case notDetermined
    case authorized
    case limited
    case denied
    case restricted
}

@MainActor
final class PhotoLibraryViewModel: ObservableObject {
    @Published var authState: PhotoLibraryAuthState = .notDetermined
    @Published var photos: [PhotoInfo] = []
    @Published var isLoading = false
    @Published var dateFilter: DateFilter = .all {
        didSet { applyFilter() }
    }
    @Published var categoryFilter: PhotoCategoryFilter = .all {
        didSet { applyFilter() }
    }
    @Published var sortOption: PhotoSortOption = .dateNewest {
        didSet { applyFilter() }
    }
    @Published var searchText = "" {
        didSet { applyFilter() }
    }
    @Published var customStartDate = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date() {
        didSet {
            if dateFilter == .custom { applyFilter() }
        }
    }
    @Published var customEndDate = Date() {
        didSet {
            if dateFilter == .custom { applyFilter() }
        }
    }
    @Published var isSelectionMode = false
    @Published var selectedPhotoIDs: Set<String> = []
    @Published var isImporting = false
    @Published var importProgress: ImportProgressState?
    @Published var importResultMessage: String?
    @Published var lastImportResult: ImportBatchResult?
    @Published private(set) var importedAssetIds: Set<String> = []

    private var allPhotos: [PhotoInfo] = []
    private let imageManager = PHCachingImageManager()
    private var importResultDismissTask: Task<Void, Never>?
    private var activeThumbnailRequests: [String: PHImageRequestID] = [:]
    private var cachingAssets: [PHAsset] = []
    private var cachingTargetSize: CGSize = .zero
    private var libraryChangeObserver: PhotoLibraryChangeObserver?

    static func defaultThumbnailSize(for screenWidth: CGFloat = UIScreen.main.bounds.width) -> CGSize {
        let scale = UIScreen.main.scale
        let columnCount = CGFloat(WaterfallGridMetrics.columnCount(for: screenWidth - WaterfallGridMetrics.horizontalPadding * 2))
        let columnWidth = (screenWidth - WaterfallGridMetrics.horizontalPadding * 2 - WaterfallGridMetrics.defaultSpacing * (columnCount - 1)) / columnCount
        let pixelWidth = max(columnWidth * scale, 180)
        return CGSize(width: pixelWidth, height: pixelWidth * 1.4)
    }

    var totalPhotoCount: Int { allPhotos.count }
    var stats: AlbumStats { AlbumStats.from(photos: allPhotos) }
    var hasActiveFilters: Bool {
        dateFilter != .all
            || categoryFilter != .all
            || !searchText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var selectedCount: Int { selectedPhotoIDs.count }
    var allFilteredSelected: Bool {
        !photos.isEmpty && photos.allSatisfy { selectedPhotoIDs.contains($0.id) }
    }

    func syncImportedAssets() {
        importedAssetIds = LocalPhotoStorage.importedAssetIds()
    }

    func checkAuthorization() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        authState = mapStatus(status)

        if authState == .authorized || authState == .limited {
            startLibraryChangeObserverIfNeeded()
            loadPhotos()
        }
    }

    func requestAuthorization() {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] status in
            Task { @MainActor in
                guard let self else { return }
                self.authState = self.mapStatus(status)
                if self.authState == .authorized || self.authState == .limited {
                    self.startLibraryChangeObserverIfNeeded()
                    self.loadPhotos()
                }
            }
        }
    }

    func loadPhotos() {
        isLoading = true

        Task {
            let items = await Self.fetchAllPhotos()
            allPhotos = items
            syncImportedAssets()
            applyFilter()
            isLoading = false
            updateThumbnailCaching(for: photos)
        }
    }

    func refresh() async {
        loadPhotos()
    }

    func presentLimitedLibraryPicker() {
        guard authState == .limited, let presenter = TopViewController.find() else { return }
        PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: presenter)
    }

    func stopThumbnailCaching() {
        guard !cachingAssets.isEmpty else { return }
        imageManager.stopCachingImages(
            for: cachingAssets,
            targetSize: cachingTargetSize,
            contentMode: .aspectFill,
            options: nil
        )
        cachingAssets = []
        cachingTargetSize = .zero
    }

    func updateThumbnailCaching(for photos: [PhotoInfo]) {
        stopThumbnailCaching()
        guard !photos.isEmpty else { return }

        let targetSize = Self.defaultThumbnailSize()
        cachingTargetSize = targetSize
        cachingAssets = photos.prefix(72).map(\.asset)
        imageManager.startCachingImages(
            for: cachingAssets,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: nil
        )
    }

    func cancelThumbnail(for photoID: String) {
        guard let requestID = activeThumbnailRequests.removeValue(forKey: photoID) else { return }
        imageManager.cancelImageRequest(requestID)
    }

    private static func fetchAllPhotos() async -> [PhotoInfo] {
        await Task.detached(priority: .userInitiated) {
            let options = PHFetchOptions()
            options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            options.predicate = NSPredicate(
                format: "mediaType == %d || mediaType == %d",
                PHAssetMediaType.image.rawValue,
                PHAssetMediaType.video.rawValue
            )

            let result = PHAsset.fetchAssets(with: options)
            var items: [PhotoInfo] = []
            items.reserveCapacity(result.count)

            result.enumerateObjects { asset, _, _ in
                let resources = PHAssetResource.assetResources(for: asset)
                let primary = Self.primaryResource(for: asset, resources: resources)
                items.append(PhotoInfo(asset: asset, filename: primary?.originalFilename))
            }

            return items
        }.value
    }

    nonisolated private static func primaryResource(for asset: PHAsset, resources: [PHAssetResource]) -> PHAssetResource? {
        switch asset.mediaType {
        case .video:
            return resources.first { $0.type == .video || $0.type == .fullSizeVideo } ?? resources.first
        case .image:
            return resources.first { $0.type == .photo || $0.type == .fullSizePhoto } ?? resources.first
        default:
            return resources.first
        }
    }

    func resetFilters() {
        dateFilter = .all
        categoryFilter = .all
        sortOption = .dateNewest
        searchText = ""
    }

    func enterSelectionMode() {
        isSelectionMode = true
        selectedPhotoIDs.removeAll()
    }

    func exitSelectionMode() {
        isSelectionMode = false
        selectedPhotoIDs.removeAll()
    }

    func toggleSelection(for photo: PhotoInfo) {
        if selectedPhotoIDs.contains(photo.id) {
            selectedPhotoIDs.remove(photo.id)
        } else {
            selectedPhotoIDs.insert(photo.id)
        }
    }

    func selectAllFiltered() {
        selectedPhotoIDs = Set(photos.map(\.id))
    }

    func clearSelection() {
        selectedPhotoIDs.removeAll()
    }

    func importSelected(
        localLibrary: LocalLibraryViewModel,
        folderId: String?,
        settings: AppSettings
    ) async {
        let targets = photos.filter { selectedPhotoIDs.contains($0.id) }
        await importPhotos(targets, folderId: folderId, localLibrary: localLibrary, settings: settings)
    }

    func importFiltered(
        localLibrary: LocalLibraryViewModel,
        folderId: String?,
        settings: AppSettings
    ) async {
        await importPhotos(photos, folderId: folderId, localLibrary: localLibrary, settings: settings)
    }

    private func importPhotos(
        _ targets: [PhotoInfo],
        folderId: String?,
        localLibrary: LocalLibraryViewModel,
        settings: AppSettings
    ) async {
        guard !targets.isEmpty else { return }

        importResultDismissTask?.cancel()
        isImporting = true
        importResultMessage = nil
        lastImportResult = nil
        importProgress = ImportProgressState(current: 0, total: targets.count, filename: targets.first?.filename)

        let result = await LocalImportService.importPhotos(targets, folderId: folderId) { [weak self] progress in
            Task { @MainActor in
                self?.importProgress = progress
            }
        }

        localLibrary.reload()
        syncImportedAssets()
        presentImportResult(result, settings: settings)
    }

    private func presentImportResult(_ result: ImportBatchResult, settings: AppSettings) {
        let message = Self.formatImportResult(result, settings: settings)

        isImporting = false
        importProgress = nil
        lastImportResult = result
        importResultMessage = message
        exitSelectionMode()

        importResultDismissTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_500_000_000)
            guard !Task.isCancelled else { return }
            clearImportResult()
        }
    }

    static func formatImportResult(_ result: ImportBatchResult, settings: AppSettings) -> String {
        var parts: [String] = []
        if !result.imported.isEmpty { parts.append(settings.format(.importSuccess, result.imported.count)) }
        if result.skipped > 0 { parts.append(settings.format(.importSkipped, result.skipped)) }
        if result.failed > 0 { parts.append(settings.format(.importFailed, result.failed)) }
        if parts.isEmpty { return settings.t(.nothingToImport) }
        return parts.joined(separator: settings.language.l10nCode.hasPrefix("zh") ? "，" : ", ")
    }

    func formattedImportResult(using settings: AppSettings) -> String? {
        importResultMessage ?? lastImportResult.map { Self.formatImportResult($0, settings: settings) }
    }

    func clearImportResult() {
        importResultDismissTask?.cancel()
        lastImportResult = nil
        importResultMessage = nil
    }

    func isImported(_ photo: PhotoInfo) -> Bool {
        importedAssetIds.contains(photo.id)
    }

    private func applyFilter() {
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()

        var filtered = allPhotos.filter { photo in
            dateFilter.contains(photo.creationDate, customStart: customStartDate, customEnd: customEndDate)
                && categoryFilter.matches(photo)
        }

        if !query.isEmpty {
            let languageCode = AppSettings.resolvedL10nCode()
            filtered = filtered.filter { photo in
                matchesSearch(photo, query: query, languageCode: languageCode)
            }
        }

        photos = sortOption.sort(filtered)
        if !isLoading {
            updateThumbnailCaching(for: photos)
        }
    }

    private func matchesSearch(_ photo: PhotoInfo, query: String, languageCode: String) -> Bool {
        if photo.filename?.lowercased().contains(query) == true { return true }
        if photo.resolutionText.lowercased().contains(query) { return true }
        if photo.mediaKind.localizedTitle(languageCode: languageCode).lowercased().contains(query) { return true }
        if photo.sourceKind.localizedTitle(languageCode: languageCode).lowercased().contains(query) { return true }
        return photo.subtypeTags.contains { tag in
            tag.localizedTitle(languageCode: languageCode).lowercased().contains(query)
        }
    }

    func loadThumbnail(for photo: PhotoInfo, targetSize: CGSize, completion: @escaping (UIImage?) -> Void) {
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true

        let requestID = imageManager.requestImage(
            for: photo.asset,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: options
        ) { image, info in
            let cancelled = (info?[PHImageCancelledKey] as? Bool) == true
            if cancelled { return }
            DispatchQueue.main.async {
                completion(image)
            }
        }
        activeThumbnailRequests[photo.id] = requestID
    }

    func loadFullImage(for photo: PhotoInfo, completion: @escaping (UIImage?) -> Void) {
        guard !photo.isVideo else {
            completion(nil)
            return
        }

        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false

        imageManager.requestImage(
            for: photo.asset,
            targetSize: PHImageManagerMaximumSize,
            contentMode: .aspectFit,
            options: options
        ) { image, _ in
            DispatchQueue.main.async {
                completion(image)
            }
        }
    }

    func loadVideoPlayer(for photo: PhotoInfo, completion: @escaping (AVPlayer?) -> Void) {
        guard photo.isVideo else {
            completion(nil)
            return
        }

        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .automatic

        imageManager.requestPlayerItem(forVideo: photo.asset, options: options) { item, _ in
            DispatchQueue.main.async {
                guard let item else {
                    completion(nil)
                    return
                }
                completion(AVPlayer(playerItem: item))
            }
        }
    }

    private func mapStatus(_ status: PHAuthorizationStatus) -> PhotoLibraryAuthState {
        switch status {
        case .notDetermined: return .notDetermined
        case .authorized: return .authorized
        case .limited: return .limited
        case .denied: return .denied
        case .restricted: return .restricted
        @unknown default: return .denied
        }
    }

    private func startLibraryChangeObserverIfNeeded() {
        guard libraryChangeObserver == nil else { return }
        libraryChangeObserver = PhotoLibraryChangeObserver { [weak self] in
            self?.loadPhotos()
        }
    }
}

private final class PhotoLibraryChangeObserver: NSObject, PHPhotoLibraryChangeObserver {
    private let handler: () -> Void

    init(handler: @escaping () -> Void) {
        self.handler = handler
        super.init()
        PHPhotoLibrary.shared().register(self)
    }

    deinit {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }

    func photoLibraryDidChange(_ changeInstance: PHChange) {
        DispatchQueue.main.async { [handler] in
            handler()
        }
    }
}
