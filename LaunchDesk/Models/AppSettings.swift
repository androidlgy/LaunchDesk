import Foundation
import SwiftUI
import AppKit
import ServiceManagement

/// 用户偏好设置
@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    // MARK: - 持久化键
    private let kColumns      = "LaunchDesk.Settings.columns"
    private let kRows         = "LaunchDesk.Settings.rows"
    private let kShowFavorite = "LaunchDesk.Settings.showFavorite"
    private let kShowRecent   = "LaunchDesk.Settings.showRecent"
    private let kRecentLimit  = "LaunchDesk.Settings.recentLimit"
    // 单快捷键（旧）— 兼容；新版用 hotkeys: dictionary
    private let kHotKeyKeyCode   = "LaunchDesk.Settings.hotkey.keyCode"
    private let kHotKeyModifiers = "LaunchDesk.Settings.hotkey.modifiers"
    private let kLaunchAtLogin   = "LaunchDesk.Settings.launchAtLogin"
    private let kTheme           = "LaunchDesk.Settings.theme"
    private let kBlurStrength    = "LaunchDesk.Settings.blurStrength"
    private let kHideOnLaunch    = "LaunchDesk.Settings.hideOnLaunch"
    private let kHideOnClickOutside = "LaunchDesk.Settings.hideOnClickOutside"
    private let kShowMenuBarIcon    = "LaunchDesk.Settings.showMenuBarIcon"
    private let kHiddenAppIDs       = "LaunchDesk.Settings.hiddenAppIDs"

    // MARK: - 状态
    @Published var columns: Int { didSet { UserDefaults.standard.set(columns, forKey: kColumns) } }
    @Published var rows: Int    { didSet { UserDefaults.standard.set(rows, forKey: kRows) } }
    @Published var showFavorite: Bool { didSet { UserDefaults.standard.set(showFavorite, forKey: kShowFavorite) } }
    @Published var showRecent:   Bool { didSet { UserDefaults.standard.set(showRecent, forKey: kShowRecent) } }
    @Published var recentLimit: Int   { didSet { UserDefaults.standard.set(recentLimit, forKey: kRecentLimit) } }
    @Published var hotKeyCode: UInt32 { didSet { UserDefaults.standard.set(Int(hotKeyCode), forKey: kHotKeyKeyCode) } }
    @Published var hotKeyMods: UInt32 { didSet { UserDefaults.standard.set(Int(hotKeyMods), forKey: kHotKeyModifiers) } }
    @Published var launchAtLogin: Bool {
        didSet {
            UserDefaults.standard.set(launchAtLogin, forKey: kLaunchAtLogin)
            applyLaunchAtLogin()
        }
    }
    @Published var theme: String { didSet { UserDefaults.standard.set(theme, forKey: kTheme) } }
    @Published var blurStrength: Double { didSet { UserDefaults.standard.set(blurStrength, forKey: kBlurStrength) } }
    @Published var hideOnLaunch: Bool { didSet { UserDefaults.standard.set(hideOnLaunch, forKey: kHideOnLaunch) } }
    @Published var hideOnClickOutside: Bool { didSet { UserDefaults.standard.set(hideOnClickOutside, forKey: kHideOnClickOutside) } }
    @Published var showMenuBarIcon: Bool {
        didSet {
            UserDefaults.standard.set(showMenuBarIcon, forKey: kShowMenuBarIcon)
            NotificationCenter.default.post(name: .launchDeskMenuBarVisibilityChanged, object: nil)
        }
    }
    @Published var hiddenAppIDs: Set<String> {
        didSet {
            UserDefaults.standard.set(Array(hiddenAppIDs), forKey: kHiddenAppIDs)
            NotificationCenter.default.post(name: .launchDeskHiddenAppsChanged, object: nil)
        }
    }

    private init() {
        let d = UserDefaults.standard
        self.columns = (d.object(forKey: kColumns) as? Int) ?? 8
        self.rows    = (d.object(forKey: kRows)    as? Int) ?? 5
        self.showFavorite = (d.object(forKey: kShowFavorite) as? Bool) ?? false
        self.showRecent   = (d.object(forKey: kShowRecent)   as? Bool) ?? false
        self.recentLimit  = (d.object(forKey: kRecentLimit)  as? Int)  ?? 8
        // 默认 ⌃⌥L（kVK_ANSI_L=37, controlKey|optionKey=528384）
        self.hotKeyCode = UInt32((d.object(forKey: kHotKeyKeyCode)   as? Int) ?? 37)
        self.hotKeyMods = UInt32((d.object(forKey: kHotKeyModifiers) as? Int) ?? 528384)
        self.launchAtLogin = (d.object(forKey: kLaunchAtLogin) as? Bool) ?? false
        self.theme = (d.object(forKey: kTheme) as? String) ?? "dark"
        self.blurStrength = (d.object(forKey: kBlurStrength) as? Double) ?? 0.4
        self.hideOnLaunch = (d.object(forKey: kHideOnLaunch) as? Bool) ?? true
        self.hideOnClickOutside = (d.object(forKey: kHideOnClickOutside) as? Bool) ?? true
        self.showMenuBarIcon = (d.object(forKey: kShowMenuBarIcon) as? Bool) ?? true
        let arr = (d.object(forKey: kHiddenAppIDs) as? [String]) ?? []
        self.hiddenAppIDs = Set(arr)
    }

    // MARK: - 行为
    func applyLaunchAtLogin() {
        if #available(macOS 13.0, *) {
            do {
                if launchAtLogin {
                    if SMAppService.mainApp.status != .enabled {
                        try SMAppService.mainApp.register()
                    }
                } else {
                    if SMAppService.mainApp.status == .enabled {
                        try SMAppService.mainApp.unregister()
                    }
                }
            } catch {
                NSLog("[LaunchDesk] launchAtLogin error: \(error)")
            }
        }
    }

    /// 重置为默认值
    func resetAll() {
        let keys = [kColumns, kRows, kShowFavorite, kShowRecent, kRecentLimit,
                    kHotKeyKeyCode, kHotKeyModifiers, kLaunchAtLogin,
                    kTheme, kBlurStrength, kHideOnLaunch, kHideOnClickOutside,
                    kShowMenuBarIcon, kHiddenAppIDs]
        for k in keys { UserDefaults.standard.removeObject(forKey: k) }
        // 重新初始化字段
        columns = 8; rows = 5
        showFavorite = false; showRecent = false; recentLimit = 8
        hotKeyCode = 37; hotKeyMods = 528384
        launchAtLogin = false
        theme = "dark"; blurStrength = 0.4
        hideOnLaunch = true; hideOnClickOutside = true; showMenuBarIcon = true
        hiddenAppIDs = []
    }
}

extension Notification.Name {
    static let launchDeskMenuBarVisibilityChanged = Notification.Name("LaunchDesk.MenuBarVisibilityChanged")
    static let launchDeskHiddenAppsChanged = Notification.Name("LaunchDesk.HiddenAppsChanged")
}
