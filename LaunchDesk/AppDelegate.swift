import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var window: NSWindow?
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?
    private var welcomeWindow: NSWindow?
    private var scrollMonitor: Any?
    private var scrollAccum: CGFloat = 0
    private var lastScrollAt: TimeInterval = 0

    private let kHasOnboarded = "LaunchDesk.hasOnboarded"

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory) // 不在 Dock 出现

        // 1) 状态栏（按设置决定是否显示）
        if AppSettings.shared.showMenuBarIcon {
            setupStatusItem()
        }

        // 2) 加载数据
        Task { @MainActor in
            await LauncherStore.shared.reload()
        }

        // 3) 全局快捷键（按用户设置）
        let s = AppSettings.shared
        HotKeyManager.shared.register { [weak self] in
            self?.toggleWindow()
        }
        if HotKeyManager.isAvailable {
            HotKeyManager.shared.updateBinding(keyCode: s.hotKeyCode, modifiers: s.hotKeyMods)
        }

        // 4) 通知监听
        NotificationCenter.default.addObserver(
            forName: .launchDeskShouldHide, object: nil, queue: .main
        ) { [weak self] _ in self?.hideWindow() }

        NotificationCenter.default.addObserver(
            forName: .launchDeskShouldToggle, object: nil, queue: .main
        ) { [weak self] _ in self?.toggleWindow() }

        // 布局变化时让 Store 触发一次 objectWillChange
        NotificationCenter.default.addObserver(
            forName: .launchDeskLayoutChanged, object: nil, queue: .main
        ) { _ in
            Task { @MainActor in LauncherStore.shared.repaginate() }
        }

        // 隐藏列表变化 → 重建网格（不重新扫盘）
        NotificationCenter.default.addObserver(
            forName: .launchDeskHiddenAppsChanged, object: nil, queue: .main
        ) { _ in
            Task { @MainActor in LauncherStore.shared.applyHiddenChange() }
        }

        // 菜单栏图标显隐切换
        NotificationCenter.default.addObserver(
            forName: .launchDeskMenuBarVisibilityChanged, object: nil, queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            if AppSettings.shared.showMenuBarIcon {
                if self.statusItem == nil { self.setupStatusItem() }
            } else {
                if let item = self.statusItem {
                    NSStatusBar.system.removeStatusItem(item)
                    self.statusItem = nil
                }
            }
        }

        // 不再自动展示窗口；用户通过状态栏图标或全局快捷键唤起

        // 首次启动 → 弹欢迎引导
        if !UserDefaults.standard.bool(forKey: kHasOnboarded) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                self?.showWelcome()
            }
        }
    }

    // MARK: - Status bar
    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let btn = item.button {
            btn.image = NSImage(systemSymbolName: "square.grid.3x3.fill",
                                accessibilityDescription: "LaunchDesk")
            btn.target = self
            btn.action = #selector(statusItemClicked(_:))
            btn.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        let menu = NSMenu()
        let toggleTitle = HotKeyManager.isAvailable ? "显示 / 隐藏" : "显示 / 隐藏"
        menu.addItem(withTitle: toggleTitle, action: #selector(toggleWindow), keyEquivalent: "")
        menu.addItem(withTitle: "重新扫描应用", action: #selector(rescan), keyEquivalent: "r")
        menu.addItem(.separator())
        menu.addItem(withTitle: "偏好设置…", action: #selector(openSettings), keyEquivalent: ",")
        menu.addItem(withTitle: "查看欢迎引导…", action: #selector(showWelcome), keyEquivalent: "")
        menu.addItem(withTitle: "关于 LaunchDesk", action: #selector(showAbout), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "退出 LaunchDesk", action: #selector(quit), keyEquivalent: "q")
        for it in menu.items { it.target = self }

        self.contextMenu = menu
        self.statusItem = item
    }

    private var contextMenu: NSMenu?

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        guard let item = statusItem else { return }
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp, let menu = contextMenu {
            item.menu = menu
            item.button?.performClick(nil)
            item.menu = nil
        } else {
            toggleWindow()
        }
    }

    @objc private func rescan() {
        Task { @MainActor in await LauncherStore.shared.reload() }
    }

    @objc private func openSettings() {
        if let w = settingsWindow {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            w.makeKeyAndOrderFront(nil)
            return
        }
        let host = NSHostingController(rootView: SettingsView())
        let w = NSWindow(contentViewController: host)
        w.title = "LaunchDesk 偏好设置"
        w.styleMask = [.titled, .closable]
        w.isReleasedWhenClosed = false
        w.setContentSize(NSSize(width: 480, height: 520))
        w.center()
        w.delegate = settingsDelegate
        settingsWindow = w
        // 临时切换到 regular 激活状态，让 Settings 窗口可获得焦点
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        w.makeKeyAndOrderFront(nil)
    }

    /// Settings 窗口关闭后切回 accessory，恢复菜单栏-only 模式
    private lazy var settingsDelegate: SettingsWindowDelegate = SettingsWindowDelegate { [weak self] in
        self?.settingsWindow = nil
        self?.maybeBackToAccessory()
    }

    /// 欢迎引导（首次启动 / 状态栏菜单触发）
    @objc func showWelcome() {
        if let w = welcomeWindow {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            w.makeKeyAndOrderFront(nil)
            return
        }
        let host = NSHostingController(rootView: WelcomeView { [weak self] in
            UserDefaults.standard.set(true, forKey: self?.kHasOnboarded ?? "")
            self?.welcomeWindow?.close()
        })
        let w = NSWindow(contentViewController: host)
        w.title = "欢迎使用 LaunchDesk"
        w.styleMask = [.titled, .closable]
        w.isReleasedWhenClosed = false
        w.setContentSize(NSSize(width: 460, height: 460))
        w.center()
        w.delegate = welcomeDelegate
        welcomeWindow = w
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        w.makeKeyAndOrderFront(nil)
    }

    private lazy var welcomeDelegate: SettingsWindowDelegate = SettingsWindowDelegate { [weak self] in
        // 首次关闭也算完成引导
        UserDefaults.standard.set(true, forKey: self?.kHasOnboarded ?? "")
        self?.welcomeWindow = nil
        self?.maybeBackToAccessory()
    }

    /// 当前没有任何普通窗口时切回 accessory
    private func maybeBackToAccessory() {
        if welcomeWindow == nil && settingsWindow == nil {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    @objc private func showAbout() {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        let opts: [NSApplication.AboutPanelOptionKey: Any] = [
            .applicationName: "LaunchDesk",
            .applicationVersion: v,
            .version: b,
            .credits: NSAttributedString(
                string: "一个简洁、原生、好看的 macOS 应用启动器。\n用 SwiftUI 写成。",
                attributes: [.foregroundColor: NSColor.secondaryLabelColor,
                             .font: NSFont.systemFont(ofSize: 11)])
        ]
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: opts)
    }

    // MARK: - Window
    @objc func toggleWindow() {
        if window?.isVisible == true { hideWindow() } else { showWindow() }
    }

    func showWindow() {
        let win = window ?? makeWindow()
        window = win

        // 用整个屏幕（含菜单栏区域）的 frame
        if let screen = NSScreen.main {
            win.setFrame(screen.frame, display: true)
        }

        // 隐藏菜单栏 + Dock，进入"全屏接管"状态
        NSApp.presentationOptions = [.autoHideMenuBar, .autoHideDock]

        // 淡入：先把 alpha=0，再做动画
        win.alphaValue = 0
        NSApp.activate(ignoringOtherApps: true)
        win.orderFrontRegardless()
        win.makeKeyAndOrderFront(nil)
        win.makeFirstResponder(win.contentView)

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.18
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            win.animator().alphaValue = 1
        }

        // 通知前端把搜索框抢焦点 + 重置状态
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            NotificationCenter.default.post(name: .launchDeskWindowDidShow, object: nil)
        }

        installScrollMonitor()
    }

    func hideWindow() {
        guard let win = window, win.isVisible else { return }
        removeScrollMonitor()
        // 恢复菜单栏 + Dock
        NSApp.presentationOptions = []
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.14
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            win.animator().alphaValue = 0
        }, completionHandler: {
            win.orderOut(nil)
            win.alphaValue = 1   // 复位，下次 show 直接可见
        })
    }

    // MARK: - 全局滚动监听（窗口活跃时拦截 scrollWheel 切页）
    private func installScrollMonitor() {
        guard scrollMonitor == nil else { return }
        scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self = self,
                  let win = self.window,
                  win.isVisible,
                  win.isKeyWindow else {
                return event
            }
            NSLog("[LaunchDesk] scrollWheel dx=\(event.scrollingDeltaX) dy=\(event.scrollingDeltaY) precise=\(event.hasPreciseScrollingDeltas)")
            self.handleScroll(event)
            return nil
        }
        NSLog("[LaunchDesk] scroll monitor installed")
    }

    private func removeScrollMonitor() {
        if let m = scrollMonitor { NSEvent.removeMonitor(m); scrollMonitor = nil }
        scrollAccum = 0
    }

    private func handleScroll(_ event: NSEvent) {
        // 鼠标滚轮（粗粒度）：dx 或 dy 任意方向，节流即可
        if !event.hasPreciseScrollingDeltas {
            let delta = abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY)
                ? event.scrollingDeltaX
                : event.scrollingDeltaY
            guard abs(delta) > 0 else { return }
            let now = Date().timeIntervalSince1970
            guard now - lastScrollAt > 0.25 else { return }
            lastScrollAt = now
            if delta < 0 {
                NotificationCenter.default.post(name: .launchDeskPageNext, object: nil)
            } else {
                NotificationCenter.default.post(name: .launchDeskPagePrev, object: nil)
            }
            return
        }

        // 触控板（精细滚动）：取 dx/dy 的主导方向累计
        let dx = event.scrollingDeltaX
        let dy = event.scrollingDeltaY
        // 用绝对值大的那个方向
        let delta = abs(dx) > abs(dy) ? dx : dy
        guard abs(delta) > 1 else { return }

        scrollAccum += delta
        let now = Date().timeIntervalSince1970
        // 阈值 80（触控板单次滚动可能累计上百，需要稍大避免一滚多页）
        let threshold: CGFloat = 80
        guard now - lastScrollAt > 0.35 else { return }
        if scrollAccum < -threshold {
            NotificationCenter.default.post(name: .launchDeskPageNext, object: nil)
            lastScrollAt = now
            scrollAccum = 0
        } else if scrollAccum > threshold {
            NotificationCenter.default.post(name: .launchDeskPagePrev, object: nil)
            lastScrollAt = now
            scrollAccum = 0
        }
        if event.phase == .ended || event.momentumPhase == .ended { scrollAccum = 0 }
    }

    private func makeWindow() -> NSWindow {
        let frame = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let win = LaunchPanel(
            contentRect: frame,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        win.isOpaque = false
        win.backgroundColor = .clear
        win.hasShadow = false
        // 提到主菜单栏之上，与系统 Launchpad 一致（盖住时间/Wi-Fi 等）
        win.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
        win.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        win.isMovable = false
        win.titleVisibility = .hidden
        win.titlebarAppearsTransparent = true
        // 失焦时不要自动隐藏，避免 accessory 模式下启动瞬间被自动收起
        win.hidesOnDeactivate = false
        win.isReleasedWhenClosed = false
        win.acceptsMouseMovedEvents = true

        let root = LauncherView()
            .environmentObject(LauncherStore.shared)
        let host = NSHostingView(rootView: root)
        host.frame = frame
        host.autoresizingMask = [.width, .height]
        win.contentView = host
        return win
    }
}

/// 自定义 NSWindow：允许成为 key window（borderless 默认不行），并支持任意键入触发搜索
final class LaunchPanel: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    private var scrollAccum: CGFloat = 0
    private var lastScrollTrigger: TimeInterval = 0

    // scrollWheel 已由 AppDelegate 的 NSEvent local monitor 统一处理，这里不再重写

    override func keyDown(with event: NSEvent) {
        // ESC -> 关闭
        if event.keyCode == 53 {
            NotificationCenter.default.post(name: .launchDeskShouldHide, object: nil)
            return
        }

        // ⌘1 ~ ⌘9 -> 直达对应页
        if event.modifierFlags.contains(.command),
           let chars = event.charactersIgnoringModifiers,
           let n = Int(chars), n >= 1, n <= 9 {
            NotificationCenter.default.post(name: .launchDeskJumpToPage,
                                            object: nil,
                                            userInfo: ["index": n - 1])
            return
        }

        // 方向键导航 / Enter 启动 — 但要让搜索框正常输入
        let isSearchFocused = (firstResponder is NSTextView) || (firstResponder?.className.contains("TextField") ?? false)

        switch Int(event.keyCode) {
        case 123: // ←
            NotificationCenter.default.post(name: .launchDeskKeyArrow, object: nil, userInfo: ["dir": "left"])
            if !isSearchFocused { return }
        case 124: // →
            NotificationCenter.default.post(name: .launchDeskKeyArrow, object: nil, userInfo: ["dir": "right"])
            if !isSearchFocused { return }
        case 125: // ↓
            NotificationCenter.default.post(name: .launchDeskKeyArrow, object: nil, userInfo: ["dir": "down"])
            return
        case 126: // ↑
            NotificationCenter.default.post(name: .launchDeskKeyArrow, object: nil, userInfo: ["dir": "up"])
            return
        case 36, 76: // Return / Numpad Enter
            NotificationCenter.default.post(name: .launchDeskKeyActivate, object: nil)
            // 注意：搜索框自身的 onSubmit 会处理"启动第一项"的场景
            if !isSearchFocused { return }
        default: break
        }

        super.keyDown(with: event)
    }

    /// 滚轮 / 触控板滚动 -> 翻页
    /// - 鼠标滚轮（hasPreciseScrollingDeltas=false）：dx 或 dy 任一方向都能切，节流 250ms
    /// - 触控板二指（hasPreciseScrollingDeltas=true）：只识别水平滚动并累计像素阈值
    override func scrollWheel(with event: NSEvent) {
        // 由 AppDelegate 的 NSEvent local monitor 统一处理，这里不做任何事
        // （LaunchPanel.scrollWheel 在 SwiftUI hosting view 里通常收不到事件）
    }
}

final class SettingsWindowDelegate: NSObject, NSWindowDelegate {
    let onClose: () -> Void
    init(onClose: @escaping () -> Void) { self.onClose = onClose }
    func windowWillClose(_ notification: Notification) { onClose() }
}
