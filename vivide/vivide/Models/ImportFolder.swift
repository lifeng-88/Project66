import Foundation

struct ImportFolder: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let name: String
    let createdAt: Date

    func withName(_ name: String) -> ImportFolder {
        ImportFolder(id: id, name: name, createdAt: createdAt)
    }
}

enum ImportFolderError: LocalizedError {
    case emptyName
    case duplicateName
    case notFound

    var errorDescription: String? {
        switch self {
        case .emptyName: return "文件夹名称不能为空"
        case .duplicateName: return "文件夹名称已存在"
        case .notFound: return "文件夹不存在"
        }
    }
}
