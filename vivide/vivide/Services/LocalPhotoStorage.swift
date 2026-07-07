import Foundation

enum LocalPhotoStorage {
    private static let folderName = "ImportedPhotos"
    private static let manifestName = "manifest.json"
    private static let foldersManifestName = "folders.json"

    static var rootDirectory: URL {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(folderName, isDirectory: true)
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
        return url
    }

    static var manifestURL: URL {
        rootDirectory.appendingPathComponent(manifestName)
    }

    static var foldersManifestURL: URL {
        rootDirectory.appendingPathComponent(foldersManifestName)
    }

    static func loadRecords() -> [LocalPhotoRecord] {
        guard let data = try? Data(contentsOf: manifestURL),
              let records = try? JSONDecoder().decode([LocalPhotoRecord].self, from: data) else {
            return []
        }
        return records.sorted { $0.importedAt > $1.importedAt }
    }

    static func saveRecords(_ records: [LocalPhotoRecord]) throws {
        let data = try JSONEncoder().encode(records)
        try data.write(to: manifestURL, options: .atomic)
    }

    static func loadFolders() -> [ImportFolder] {
        guard let data = try? Data(contentsOf: foldersManifestURL),
              let folders = try? JSONDecoder().decode([ImportFolder].self, from: data) else {
            return []
        }
        return folders.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    static func saveFolders(_ folders: [ImportFolder]) throws {
        let data = try JSONEncoder().encode(folders)
        try data.write(to: foldersManifestURL, options: .atomic)
    }

    @discardableResult
    static func createFolder(name: String) throws -> ImportFolder {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ImportFolderError.emptyName }

        var folders = loadFolders()
        if folders.contains(where: { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            throw ImportFolderError.duplicateName
        }

        let folder = ImportFolder(id: UUID().uuidString, name: trimmed, createdAt: Date())
        folders.append(folder)
        try saveFolders(folders)
        try FileManager.default.createDirectory(at: directoryURL(for: folder.id), withIntermediateDirectories: true)
        return folder
    }

    static func renameFolder(id: String, name: String) throws -> ImportFolder {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ImportFolderError.emptyName }

        var folders = loadFolders()
        guard let index = folders.firstIndex(where: { $0.id == id }) else {
            throw ImportFolderError.notFound
        }
        if folders.contains(where: { $0.id != id && $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            throw ImportFolderError.duplicateName
        }

        let updated = folders[index].withName(trimmed)
        folders[index] = updated
        try saveFolders(folders)
        return updated
    }

    static func deleteFolder(id: String, deletePhotos: Bool) throws {
        var folders = loadFolders()
        guard folders.contains(where: { $0.id == id }) else {
            throw ImportFolderError.notFound
        }

        var records = loadRecords()
        let folderRecords = records.filter { $0.folderId == id }

        if deletePhotos {
            for record in folderRecords {
                let url = fileURL(for: record)
                if FileManager.default.fileExists(atPath: url.path) {
                    try FileManager.default.removeItem(at: url)
                }
            }
            records.removeAll { $0.folderId == id }
            try saveRecords(records)
        } else if !folderRecords.isEmpty {
            records = try moveRecordsToRoot(folderRecords, in: records)
        }

        let directory = directoryURL(for: id)
        if FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.removeItem(at: directory)
        }

        folders.removeAll { $0.id == id }
        try saveFolders(folders)
    }

    private static func moveRecordsToRoot(
        _ targets: [LocalPhotoRecord],
        in records: [LocalPhotoRecord]
    ) throws -> [LocalPhotoRecord] {
        var updated = records
        for record in targets {
            guard let index = updated.firstIndex(where: { $0.id == record.id }) else { continue }
            let sourceURL = fileURL(for: record)
            let destination = destinationURL(
                folderId: nil,
                filename: record.filename,
                assetId: record.sourceAssetId
            )
            if FileManager.default.fileExists(atPath: sourceURL.path) {
                try FileManager.default.moveItem(at: sourceURL, to: destination)
            }
            updated[index] = record.relocated(toFolderId: nil, filename: destination.lastPathComponent)
        }
        try saveRecords(updated)
        return updated
    }

    static func folderName(for id: String?, in folders: [ImportFolder]) -> String? {
        guard let id else { return nil }
        return folders.first(where: { $0.id == id })?.name
    }

    static func directoryURL(for folderId: String?) -> URL {
        guard let folderId, !folderId.isEmpty else { return rootDirectory }
        return rootDirectory.appendingPathComponent(folderId, isDirectory: true)
    }

    static func fileURL(for record: LocalPhotoRecord) -> URL {
        directoryURL(for: record.folderId).appendingPathComponent(record.filename)
    }

    static func destinationURL(folderId: String?, filename: String, assetId: String) -> URL {
        let directory = directoryURL(for: folderId)
        if !FileManager.default.fileExists(atPath: directory.path) {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        let safeName = sanitizedFilename(filename)
        let base = assetId.replacingOccurrences(of: "/", with: "_")
        let candidate = "\(base)_\(safeName)"
        var url = directory.appendingPathComponent(candidate)
        var index = 1
        while FileManager.default.fileExists(atPath: url.path) {
            let stem = (candidate as NSString).deletingPathExtension
            let ext = (candidate as NSString).pathExtension
            let next = ext.isEmpty ? "\(stem)_\(index)" : "\(stem)_\(index).\(ext)"
            url = directory.appendingPathComponent(next)
            index += 1
        }
        return url
    }

    static func importedAssetIds(in folderId: String?) -> Set<String> {
        Set(loadRecords().filter { $0.folderId == folderId }.map(\.sourceAssetId))
    }

    static func importedAssetIds() -> Set<String> {
        Set(loadRecords().map(\.sourceAssetId))
    }

    static func totalSize(of records: [LocalPhotoRecord]) -> Int64 {
        records.reduce(0) { $0 + $1.fileSize }
    }

    static func delete(record: LocalPhotoRecord, from records: inout [LocalPhotoRecord]) throws {
        let fileURL = fileURL(for: record)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
        records.removeAll { $0.id == record.id }
        try saveRecords(records)
    }

    static func updateHidden(for ids: Set<String>, hidden: Bool, in records: inout [LocalPhotoRecord]) throws {
        records = records.map { record in
            ids.contains(record.id) ? record.withHidden(hidden) : record
        }
        try saveRecords(records)
    }

    private static func sanitizedFilename(_ name: String) -> String {
        let invalid = CharacterSet(charactersIn: "/:\\?%*|\"<>")
        let cleaned = name.components(separatedBy: invalid).joined(separator: "_")
        return cleaned.isEmpty ? "photo.jpg" : cleaned
    }
}
