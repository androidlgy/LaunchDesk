import Foundation
import AppKit

/// 扫描系统中的 .app
///
/// - 非 AppStore 模式：直接遍历 `/Applications` 等目录（需关闭沙盒）
/// - AppStore 模式：用 Spotlight (`NSMetadataQuery`) 查询，沙盒友好
enum AppScanner {

    /// 异步扫描所有 .app
    static func scanAll() async -> [AppItem] {
        #if APPSTORE
        return await scanViaSpotlight()
        #else
        return await withCheckedContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                let result = scanSyncViaFS()
                cont.resume(returning: result)
            }
        }
        #endif
    }

    // MARK: - 沙盒模式：Spotlight
    #if APPSTORE
    private static func scanViaSpotlight() async -> [AppItem] {
        await withCheckedContinuation { (cont: CheckedContinuation<[AppItem], Never>) in
            DispatchQueue.main.async {
                let q = NSMetadataQuery()
                q.searchScopes = [
                    NSMetadataQueryLocalComputerScope
                ]
                q.predicate = NSPredicate(format: "kMDItemContentType == 'com.apple.application-bundle'")

                var observer: NSObjectProtocol?
                observer = NotificationCenter.default.addObserver(
                    forName: .NSMetadataQueryDidFinishGathering,
                    object: q, queue: .main
                ) { _ in
                    q.disableUpdates()
                    var seen = Set<String>()
                    var items: [AppItem] = []
                    for i in 0..<q.resultCount {
                        guard let it = q.result(at: i) as? NSMetadataItem,
                              let path = it.value(forAttribute: NSMetadataItemPathKey) as? String
                        else { continue }
                        if seen.contains(path) { continue }
                        seen.insert(path)
                        if let app = makeItem(at: URL(fileURLWithPath: path)) {
                            items.append(app)
                        }
                    }
                    items.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
                    q.stop()
                    if let observer { NotificationCenter.default.removeObserver(observer) }
                    cont.resume(returning: items)
                }
                q.start()
            }
        }
    }
    #endif

    // MARK: - 非沙盒模式：直接遍历目录
    #if !APPSTORE
    /// 默认扫描的根目录
    static let roots: [URL] = {
        let fm = FileManager.default
        var urls: [URL] = [
            URL(fileURLWithPath: "/Applications"),
            URL(fileURLWithPath: "/Applications/Utilities"),
            URL(fileURLWithPath: "/System/Applications"),
            URL(fileURLWithPath: "/System/Applications/Utilities"),
        ]
        if let home = fm.urls(for: .applicationDirectory, in: .userDomainMask).first {
            urls.append(home) // ~/Applications
        }
        return urls.filter { fm.fileExists(atPath: $0.path) }
    }()

    private static func scanSyncViaFS() -> [AppItem] {
        var seen = Set<String>()
        var result: [AppItem] = []
        let fm = FileManager.default

        func visit(_ url: URL, depth: Int) {
            if depth > 3 { return }
            if url.pathExtension == "app" {
                guard !seen.contains(url.path) else { return }
                seen.insert(url.path)
                if let item = makeItem(at: url) {
                    result.append(item)
                }
                return
            }
            guard let kids = try? fm.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { return }
            for kid in kids {
                if kid.pathExtension == "app" {
                    if !seen.contains(kid.path) {
                        seen.insert(kid.path)
                        if let item = makeItem(at: kid) {
                            result.append(item)
                        }
                    }
                } else {
                    var isDir: ObjCBool = false
                    if fm.fileExists(atPath: kid.path, isDirectory: &isDir), isDir.boolValue {
                        visit(kid, depth: depth + 1)
                    }
                }
            }
        }

        for root in roots { visit(root, depth: 0) }
        result.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        return result
    }
    #endif

    // MARK: - 共用
    private static func makeItem(at url: URL) -> AppItem? {
        let bundle = Bundle(url: url)
        let displayName: String = {
            if let n = bundle?.localizedInfoDictionary?["CFBundleDisplayName"] as? String, !n.isEmpty { return n }
            if let n = bundle?.infoDictionary?["CFBundleDisplayName"] as? String, !n.isEmpty { return n }
            if let n = bundle?.infoDictionary?["CFBundleName"] as? String, !n.isEmpty { return n }
            return url.deletingPathExtension().lastPathComponent
        }()
        return AppItem(
            url: url,
            name: displayName,
            bundleIdentifier: bundle?.bundleIdentifier
        )
    }
}
