import Foundation
import AppKit

/// 一个已安装的应用
struct AppItem: Identifiable, Hashable, Codable {
    /// 用 bundle path 作为稳定 id
    var id: String { url.path }
    let url: URL
    let name: String
    let bundleIdentifier: String?

    /// 图标不参与编码；运行时按需加载（走 IconCache 缓存）
    func icon(size: CGFloat = 96) -> NSImage {
        IconCache.shared.icon(for: url, size: size)
    }

    static func == (lhs: AppItem, rhs: AppItem) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
