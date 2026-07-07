import Foundation

enum PhotoCategoryFilter: String, CaseIterable, Identifiable {
    case all = "全部"
    case favorites = "收藏"
    case videos = "视频"
    case screenshots = "截图"
    case livePhoto = "Live Photo"
    case withLocation = "有位置"

    var id: String { rawValue }

    func matches(_ photo: PhotoInfo) -> Bool {
        switch self {
        case .all:
            return true
        case .favorites:
            return photo.isFavorite
        case .videos:
            return photo.isVideo
        case .screenshots:
            return photo.subtypeTags.contains(.screenshot)
        case .livePhoto:
            return photo.subtypeTags.contains(.livePhoto)
        case .withLocation:
            return photo.locationDescription != nil
        }
    }
}

struct AlbumStats {
    let total: Int
    let favorites: Int
    let videos: Int
    let screenshots: Int
    let livePhotos: Int
    let withLocation: Int

    static let empty = AlbumStats(total: 0, favorites: 0, videos: 0, screenshots: 0, livePhotos: 0, withLocation: 0)

    static func from(photos: [PhotoInfo]) -> AlbumStats {
        AlbumStats(
            total: photos.count,
            favorites: photos.filter(\.isFavorite).count,
            videos: photos.filter(\.isVideo).count,
            screenshots: photos.filter { $0.subtypeTags.contains(.screenshot) }.count,
            livePhotos: photos.filter { $0.subtypeTags.contains(.livePhoto) }.count,
            withLocation: photos.filter { $0.locationDescription != nil }.count
        )
    }
}
