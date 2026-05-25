import Foundation
import AppKit
import SwiftUI

/// 数据中心：管理已扫描的 App、页面布局、收藏、最近使用、并负责持久化
@MainActor
final class LauncherStore: ObservableObject {
    static let shared = LauncherStore()

    // MARK: - Published 状态
    @Published private(set) var apps: [String: AppItem] = [:]   // id -> AppItem
    @Published var pages: [[GridItem]] = []                     // 多页布局
    @Published var favorites: [String] = []                     // App id
    @Published var recents: [String] = []                       // App id（按时间倒序）
    @Published var searchText: String = ""

    /// 拼音搜索索引
    private var pinyinIndex = PinyinIndex()

    // MARK: - 配置（实时跟随 AppSettings）
    var columns: Int { AppSettings.shared.columns }
    var rows: Int    { AppSettings.shared.rows }
    var pageSize: Int { columns * rows }

    // MARK: - 持久化
    private let layoutKey = "LaunchDesk.Layout.v1"
    private let favKey    = "LaunchDesk.Favorites.v1"
    private let recentKey = "LaunchDesk.Recents.v1"

    private init() {
        loadPersisted()
    }

    // MARK: - 扫描
    func reload() async {
        let scanned = await AppScanner.scanAll()
        var dict: [String: AppItem] = [:]
        for a in scanned { dict[a.id] = a }
        self.apps = dict

        // 应用"隐藏列表"过滤
        let hidden = AppSettings.shared.hiddenAppIDs
        let visibleIDs = scanned.map(\.id).filter { !hidden.contains($0) }
        rebuildPagesPreservingLayout(allAppIDs: visibleIDs)
        savePersisted()

        // 重建拼音索引（不含隐藏 App）
        let visibleApps = scanned.filter { !hidden.contains($0.id) }
        pinyinIndex.rebuild(apps: visibleApps)

        // 预热图标缓存（后台进行，不阻塞 UI）
        IconCache.shared.warmup(urls: visibleApps.map(\.url))
    }

    /// 隐藏列表变化后，无需重新扫盘，直接基于 self.apps 重建
    func applyHiddenChange() {
        let hidden = AppSettings.shared.hiddenAppIDs
        let allIDs = apps.values.map(\.id).filter { !hidden.contains($0) }
        rebuildPagesPreservingLayout(allAppIDs: allIDs)
        let visibleApps = apps.values.filter { !hidden.contains($0.id) }
        pinyinIndex.rebuild(apps: Array(visibleApps))
        savePersisted()
    }

    /// 清空网格布局（不动应用本身）
    func clearLayout() {
        let hidden = AppSettings.shared.hiddenAppIDs
        let visibleIDs = apps.values.map(\.id).filter { !hidden.contains($0) }
        pages = []
        rebuildPagesPreservingLayout(allAppIDs: visibleIDs)
        savePersisted()
    }

    /// 清空收藏夹
    func clearFavorites() {
        favorites = []
        savePersisted()
    }

    /// 清空最近使用
    func clearRecents() {
        recents = []
        savePersisted()
    }

    /// 在保留已有布局的前提下，把新 App 加到末尾，把已卸载的 App 移除
    private func rebuildPagesPreservingLayout(allAppIDs: [String]) {
        let validSet = Set(allAppIDs)

        // 1) 从原页面里清掉已不存在的 App / 空文件夹，并收集 “已经摆好的 id”
        var placed = Set<String>()
        var newPages: [[GridItem]] = pages.map { page in
            page.compactMap { item -> GridItem? in
                switch item {
                case .app(let id):
                    guard validSet.contains(id) else { return nil }
                    placed.insert(id)
                    return .app(appID: id)
                case .folder(var f):
                    f.appIDs = f.appIDs.filter { validSet.contains($0) }
                    f.appIDs.forEach { placed.insert($0) }
                    if f.appIDs.isEmpty { return nil }
                    if f.appIDs.count == 1 { // 退化成单 App
                        let only = f.appIDs[0]
                        return .app(appID: only)
                    }
                    return .folder(f)
                }
            }
        }

        // 2) 把新 App 追加到末尾
        let leftover = allAppIDs.filter { !placed.contains($0) }
        var queue = leftover.map { GridItem.app(appID: $0) }

        // 3) 重新切页
        var flat: [GridItem] = newPages.flatMap { $0 }
        flat.append(contentsOf: queue)
        queue.removeAll()

        var paged: [[GridItem]] = []
        var idx = 0
        while idx < flat.count {
            let end = min(idx + pageSize, flat.count)
            paged.append(Array(flat[idx..<end]))
            idx = end
        }
        if paged.isEmpty { paged = [[]] }
        self.pages = paged
    }

    // MARK: - 操作
    func indexPath(of itemID: String) -> (page: Int, index: Int)? {
        for (p, page) in pages.enumerated() {
            if let i = page.firstIndex(where: { $0.id == itemID }) {
                return (p, i)
            }
        }
        return nil
    }

    /// 将一个 GridItem 移动到指定位置（page,index）。如果目标格子已被占用，会向后挤。
    func move(itemID: String, toPage page: Int, index: Int) {
        guard let from = indexPath(of: itemID) else { return }
        guard page >= 0, page < pages.count else { return }
        let item = pages[from.page].remove(at: from.index)
        var insertIdx = max(0, min(index, pages[page].count))
        if from.page == page, from.index < insertIdx { insertIdx -= 1 }
        pages[page].insert(item, at: insertIdx)
        normalizePages()
        savePersisted()
    }

    /// 把 sourceID 拖到 targetID 上：合并成一个文件夹（或加进已有文件夹）
    func merge(sourceID: String, into targetID: String) {
        guard sourceID != targetID else { return }
        guard let src = indexPath(of: sourceID), let dst = indexPath(of: targetID) else { return }
        let srcItem = pages[src.page][src.index]
        let dstItem = pages[dst.page][dst.index]

        switch (srcItem, dstItem) {
        case (.app(let s), .app(let t)):
            let folder = Folder(name: "新建文件夹", appIDs: [t, s])
            pages[dst.page][dst.index] = .folder(folder)
            // 删源
            removeItem(at: src)
        case (.app(let s), .folder(var f)):
            if !f.appIDs.contains(s) { f.appIDs.append(s) }
            pages[dst.page][dst.index] = .folder(f)
            removeItem(at: src)
        case (.folder, _):
            // 不支持把一个文件夹整体丢进另一个里
            return
        }
        normalizePages()
        savePersisted()
    }

    /// 把一个 App 从文件夹里取出，放到当前页末尾
    func popOutOfFolder(folderID: UUID, appID: String, toPage page: Int) {
        for (p, var pageItems) in pages.enumerated() {
            for (i, item) in pageItems.enumerated() {
                if case .folder(var f) = item, f.id == folderID {
                    f.appIDs.removeAll { $0 == appID }
                    if f.appIDs.count <= 1 {
                        // 文件夹解散
                        let remain = f.appIDs.first
                        pageItems.remove(at: i)
                        if let r = remain { pageItems.append(.app(appID: r)) }
                        pages[p] = pageItems
                    } else {
                        pageItems[i] = .folder(f)
                        pages[p] = pageItems
                    }
                    let target = max(0, min(page, pages.count - 1))
                    pages[target].append(.app(appID: appID))
                    normalizePages()
                    savePersisted()
                    return
                }
            }
        }
    }

    /// 重命名文件夹
    func renameFolder(_ folderID: UUID, to newName: String) {
        for (p, page) in pages.enumerated() {
            for (i, item) in page.enumerated() {
                if case .folder(var f) = item, f.id == folderID {
                    f.name = newName
                    pages[p][i] = .folder(f)
                    savePersisted()
                    return
                }
            }
        }
    }

    private func removeItem(at ip: (page: Int, index: Int)) {
        guard ip.page < pages.count, ip.index < pages[ip.page].count else { return }
        pages[ip.page].remove(at: ip.index)
    }

    /// 让每页都不超过 pageSize；不足的从下一页前置补齐；多余的溢出到下一页
    private func normalizePages() {
        let flat: [GridItem] = pages.flatMap { $0 }
        var paged: [[GridItem]] = []
        var idx = 0
        while idx < flat.count {
            let end = min(idx + pageSize, flat.count)
            paged.append(Array(flat[idx..<end]))
            idx = end
        }
        if paged.isEmpty { paged = [[]] }
        pages = paged
    }

    /// 当列数/行数发生变化后调用，按新 pageSize 重排
    func repaginate() {
        normalizePages()
        savePersisted()
    }

    // MARK: - 搜索
    func searchResults() -> [AppItem] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return [] }
        let ids = pinyinIndex.search(q)
        return ids.compactMap { apps[$0] }
    }

    // MARK: - 收藏 / 最近使用
    func toggleFavorite(_ appID: String) {
        if let i = favorites.firstIndex(of: appID) { favorites.remove(at: i) }
        else { favorites.insert(appID, at: 0) }
        savePersisted()
    }

    func isFavorite(_ appID: String) -> Bool { favorites.contains(appID) }

    func recordRecent(_ appID: String) {
        recents.removeAll { $0 == appID }
        recents.insert(appID, at: 0)
        let limit = max(1, AppSettings.shared.recentLimit)
        if recents.count > limit { recents = Array(recents.prefix(limit)) }
        savePersisted()
    }

    // MARK: - 持久化
    private func savePersisted() {
        let enc = JSONEncoder()
        if let d = try? enc.encode(pages) {
            UserDefaults.standard.set(d, forKey: layoutKey)
        }
        UserDefaults.standard.set(favorites, forKey: favKey)
        UserDefaults.standard.set(recents, forKey: recentKey)
    }

    private func loadPersisted() {
        let dec = JSONDecoder()
        if let d = UserDefaults.standard.data(forKey: layoutKey),
           let p = try? dec.decode([[GridItem]].self, from: d) {
            self.pages = p
        }
        if let f = UserDefaults.standard.array(forKey: favKey) as? [String] { self.favorites = f }
        if let r = UserDefaults.standard.array(forKey: recentKey) as? [String] { self.recents = r }
    }
}
