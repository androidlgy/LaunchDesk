import Foundation

/// 网格中的单元：可能是一个 App，也可能是一个文件夹
enum GridItem: Identifiable, Hashable, Codable {
    case app(appID: String)
    case folder(Folder)

    var id: String {
        switch self {
        case .app(let appID): return "app:\(appID)"
        case .folder(let f):  return "folder:\(f.id)"
        }
    }

    // MARK: - Codable
    enum CodingKeys: String, CodingKey { case type, appID, folder }
    enum Kind: String, Codable { case app, folder }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try c.decode(Kind.self, forKey: .type)
        switch kind {
        case .app:    self = .app(appID: try c.decode(String.self, forKey: .appID))
        case .folder: self = .folder(try c.decode(Folder.self, forKey: .folder))
        }
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .app(let id):
            try c.encode(Kind.app, forKey: .type)
            try c.encode(id, forKey: .appID)
        case .folder(let f):
            try c.encode(Kind.folder, forKey: .type)
            try c.encode(f, forKey: .folder)
        }
    }
}

/// 文件夹
struct Folder: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    /// 文件夹内的 App id（按顺序）
    var appIDs: [String]

    init(id: UUID = UUID(), name: String = "未命名", appIDs: [String]) {
        self.id = id
        self.name = name
        self.appIDs = appIDs
    }
}
