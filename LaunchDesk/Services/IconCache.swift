import Foundation
import AppKit

/// 图标缓存 — 大量 App 时图标读取是性能瓶颈，所有读操作都走缓存。
/// 同时把 NSImage 渲染好的位图存起来，渲染时不再走 NSWorkspace。
final class IconCache {
    static let shared = IconCache()

    /// key = "<path>@<size>"
    private var cache: [String: NSImage] = [:]
    private let lock = NSLock()

    /// 主图标（96px，用于网格主图）
    func icon(for url: URL, size: CGFloat = 96) -> NSImage {
        let key = "\(url.path)@\(Int(size))"

        lock.lock()
        if let cached = cache[key] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        let raw = NSWorkspace.shared.icon(forFile: url.path)
        // 重绘成位图，避免 SwiftUI 每次重渲染都解码原始图标
        let image = Self.flatten(raw, to: NSSize(width: size, height: size))

        lock.lock()
        cache[key] = image
        lock.unlock()
        return image
    }

    /// 把矢量/多分辨率图标拍平到固定尺寸的位图，渲染最快
    private static func flatten(_ src: NSImage, to size: NSSize) -> NSImage {
        let img = NSImage(size: size)
        img.lockFocus()
        defer { img.unlockFocus() }
        NSGraphicsContext.current?.imageInterpolation = .high
        src.draw(in: NSRect(origin: .zero, size: size),
                 from: .zero,
                 operation: .sourceOver,
                 fraction: 1.0)
        return img
    }

    /// 在 reload 完成后异步预热缓存（不阻塞 UI）
    func warmup(urls: [URL], sizes: [CGFloat] = [96, 32, 18]) {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            for url in urls {
                for s in sizes {
                    _ = self.icon(for: url, size: s)
                }
            }
        }
    }

    /// 卸载/重新扫描时清理掉不存在的项
    func purge(keepingPaths: Set<String>) {
        lock.lock()
        defer { lock.unlock() }
        cache = cache.filter { entry in
            let path = entry.key.split(separator: "@").dropLast().joined(separator: "@")
            return keepingPaths.contains(path)
        }
    }
}
