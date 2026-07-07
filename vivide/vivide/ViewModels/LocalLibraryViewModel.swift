import Foundation
import UIKit

@MainActor
final class LocalLibraryViewModel: ObservableObject {
    @Published var records: [LocalPhotoRecord] = []
    @Published var isSelectionMode = false
    @Published var selectedRecordIDs: Set<String> = []
    @Published var displayFilter: LocalLibraryFilter = .visible
    @Published var actionMessageKey: L10nKey?
    @Published var actionMessageCount: Int = 0
    @Published var folders: [ImportFolder] = []
    @Published var folderFilterId: String?
    @Published private(set) var contentRevision = 0

    var totalCount: Int { records.count }
    var visibleCount: Int { records.filter { !$0.isHidden }.count }
    var hiddenCount: Int { records.filter(\.isHidden).count }

    var displayedRecords: [LocalPhotoRecord] {
        displayedRecords(showHiddenPhotos: false)
    }

    func displayedRecords(showHiddenPhotos: Bool, folderFilterId: String? = nil) -> [LocalPhotoRecord] {
        let items: [LocalPhotoRecord]
        if showHiddenPhotos {
            switch displayFilter {
            case .all, .visible:
                items = records
            case .hidden:
                items = records.filter(\.isHidden)
            }
        } else {
            items = records.filter { !$0.isHidden }
        }

        return items.filter { $0.folderId == folderFilterId }
    }

    func count(in folderId: String?) -> Int {
        records.filter { $0.folderId == folderId }.count
    }

    var totalSizeText: String {
        ByteCountFormatter.string(fromByteCount: LocalPhotoStorage.totalSize(of: records), countStyle: .file)
    }

    var selectedCount: Int { selectedRecordIDs.count }

    func allDisplayedSelected(showHiddenPhotos: Bool, folderFilterId: String? = nil) -> Bool {
        let items = displayedRecords(showHiddenPhotos: showHiddenPhotos, folderFilterId: folderFilterId)
        return !items.isEmpty && items.allSatisfy { selectedRecordIDs.contains($0.id) }
    }

    func reload() {
        records = LocalPhotoStorage.loadRecords()
        folders = LocalPhotoStorage.loadFolders()
        if let folderFilterId, !folders.contains(where: { $0.id == folderFilterId }) {
            self.folderFilterId = nil
        }
        LocalPhotoThumbnailCache.clear()
        contentRevision += 1
    }

    private func notifyRecordsChanged() {
        contentRevision += 1
    }

    func image(for record: LocalPhotoRecord, targetWidth: CGFloat) -> UIImage? {
        LocalPhotoThumbnailCache.image(for: record, targetWidth: targetWidth)
    }

    func fullImage(for record: LocalPhotoRecord) -> UIImage? {
        guard !record.isVideo else { return nil }
        let url = LocalPhotoStorage.fileURL(for: record)
        return UIImage(contentsOfFile: url.path)
    }

    func fileURL(for record: LocalPhotoRecord) -> URL {
        LocalPhotoStorage.fileURL(for: record)
    }

    func toggleSelection(for record: LocalPhotoRecord) {
        if selectedRecordIDs.contains(record.id) {
            selectedRecordIDs.remove(record.id)
        } else {
            selectedRecordIDs.insert(record.id)
        }
    }

    func selectAllDisplayed(showHiddenPhotos: Bool, folderFilterId: String? = nil) {
        selectedRecordIDs = Set(
            displayedRecords(showHiddenPhotos: showHiddenPhotos, folderFilterId: folderFilterId).map(\.id)
        )
    }

    func clearSelection() {
        selectedRecordIDs.removeAll()
    }

    func exitSelectionMode() {
        isSelectionMode = false
        clearSelection()
    }

    func setSelectedHidden(_ hidden: Bool) {
        guard !selectedRecordIDs.isEmpty else { return }
        var all = records
        try? LocalPhotoStorage.updateHidden(for: selectedRecordIDs, hidden: hidden, in: &all)
        records = all
        let count = selectedRecordIDs.count
        exitSelectionMode()
        actionMessageKey = hidden ? .hiddenCount : .unhiddenCount
        actionMessageCount = count
    }

    func setHidden(_ hidden: Bool, for record: LocalPhotoRecord) {
        var all = records
        try? LocalPhotoStorage.updateHidden(for: [record.id], hidden: hidden, in: &all)
        records = all
        actionMessageKey = hidden ? .setHiddenOne : .unsetHiddenOne
        actionMessageCount = 0
    }

    func deleteSelected() {
        var all = records
        let targets = records.filter { selectedRecordIDs.contains($0.id) }
        for record in targets {
            try? LocalPhotoStorage.delete(record: record, from: &all)
        }
        records = all
        exitSelectionMode()
        actionMessageKey = .deletedCount
        actionMessageCount = targets.count
        notifyRecordsChanged()
    }

    func delete(record: LocalPhotoRecord) {
        var all = records
        try? LocalPhotoStorage.delete(record: record, from: &all)
        records = all
        selectedRecordIDs.remove(record.id)
        notifyRecordsChanged()
    }

    func formattedActionMessage(using settings: AppSettings) -> String? {
        guard let key = actionMessageKey else { return nil }
        if actionMessageCount > 0 {
            return settings.format(key, actionMessageCount)
        }
        return settings.t(key)
    }

    func clearActionMessage() {
        actionMessageKey = nil
        actionMessageCount = 0
    }

    @discardableResult
    func renameFolder(id: String, name: String) throws -> ImportFolder {
        let folder = try LocalPhotoStorage.renameFolder(id: id, name: name)
        reload()
        actionMessageKey = .folderRenamed
        actionMessageCount = 0
        return folder
    }

    func deleteFolder(id: String, deletePhotos: Bool, settings: AppSettings) throws {
        try LocalPhotoStorage.deleteFolder(id: id, deletePhotos: deletePhotos)
        if settings.importFolderId == id {
            settings.importFolderId = nil
        }
        if folderFilterId == id {
            folderFilterId = nil
        }
        reload()
        actionMessageKey = .folderDeleted
        actionMessageCount = 0
    }
}
