import Foundation
import AppKit

enum LaunchService {

    static func launch(_ app: AppItem) {
        // 1. 立刻发"收起"通知（按设置）
        Task { @MainActor in
            if AppSettings.shared.hideOnLaunch {
                NotificationCenter.default.post(name: .launchDeskShouldHide, object: nil)
            }
            LauncherStore.shared.recordRecent(app.id)
        }

        // 2. 启动应用
        let cfg = NSWorkspace.OpenConfiguration()
        cfg.activates = true
        NSWorkspace.shared.openApplication(at: app.url, configuration: cfg) { _, err in
            if let err = err {
                NSLog("[LaunchDesk] launch error: \(err)")
                DispatchQueue.main.async {
                    let alert = NSAlert()
                    alert.messageText = "无法启动 \(app.name)"
                    alert.informativeText = err.localizedDescription
                    alert.alertStyle = .warning
                    alert.addButton(withTitle: "好")
                    alert.runModal()
                }
            }
        }
    }

    /// 是否支持卸载（沙盒下不允许）
    static var supportsUninstall: Bool {
        #if APPSTORE
        return false
        #else
        return true
        #endif
    }

    /// 移到废纸篓（系统级 App 通常会失败，保护机制）
    static func uninstall(_ app: AppItem, completion: @escaping (Bool) -> Void) {
        #if APPSTORE
        // 沙盒：不支持卸载，改为在 Finder 中显示
        NSWorkspace.shared.activateFileViewerSelecting([app.url])
        completion(false)
        #else
        let alert = NSAlert()
        alert.messageText = "卸载 \(app.name)？"
        alert.informativeText = "将把 \(app.url.path) 移动到废纸篓，可在废纸篓中恢复。"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "卸载")
        alert.addButton(withTitle: "取消")
        let resp = alert.runModal()
        guard resp == .alertFirstButtonReturn else {
            completion(false); return
        }

        var resulting: NSURL?
        do {
            try FileManager.default.trashItem(at: app.url, resultingItemURL: &resulting)
            completion(true)
        } catch {
            let e = NSAlert()
            e.messageText = "卸载失败"
            e.informativeText = error.localizedDescription
            e.runModal()
            completion(false)
        }
        #endif
    }
}
