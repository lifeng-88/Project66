import Foundation

enum PhotoSortOption: String, CaseIterable, Identifiable {
    case dateNewest = "最新优先"
    case dateOldest = "最早优先"
    case resolutionLargest = "分辨率从高到低"
    case resolutionSmallest = "分辨率从低到高"
    case nameAZ = "文件名 A-Z"

    var id: String { rawValue }

    func sort(_ photos: [PhotoInfo]) -> [PhotoInfo] {
        switch self {
        case .dateNewest:
            return photos.sorted {
                ($0.creationDate ?? .distantPast) > ($1.creationDate ?? .distantPast)
            }
        case .dateOldest:
            return photos.sorted {
                ($0.creationDate ?? .distantFuture) < ($1.creationDate ?? .distantFuture)
            }
        case .resolutionLargest:
            return photos.sorted { $0.pixelArea > $1.pixelArea }
        case .resolutionSmallest:
            return photos.sorted { $0.pixelArea < $1.pixelArea }
        case .nameAZ:
            return photos.sorted {
                ($0.filename ?? "").localizedCaseInsensitiveCompare($1.filename ?? "") == .orderedAscending
            }
        }
    }
}

private extension PhotoInfo {
    var pixelArea: Int { pixelWidth * pixelHeight }
}
