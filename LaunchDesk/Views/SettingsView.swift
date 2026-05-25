import SwiftUI
import AppKit
import Carbon.HIToolbox

/// 设置面板（独立窗口） — 分页 Tab
struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralTab()
                .tabItem { Label("通用", systemImage: "gear") }
            HotKeyTab()
                .tabItem { Label("快捷键", systemImage: "command") }
            AppearanceTab()
                .tabItem { Label("外观", systemImage: "paintbrush") }
            HomeTab()
                .tabItem { Label("首页", systemImage: "house") }
            HiddenAppsTab()
                .tabItem { Label("隐藏", systemImage: "eye.slash") }
            AboutTab()
                .tabItem { Label("关于", systemImage: "info.circle") }
        }
        .frame(width: 540, height: 480)
    }
}

// MARK: - 通用
private struct GeneralTab: View {
    @ObservedObject var settings = AppSettings.shared
    @State private var showResetAlert = false

    var body: some View {
        Form {
            Section("启动") {
                Toggle("登录时启动 LaunchDesk", isOn: $settings.launchAtLogin)
                Toggle("显示菜单栏图标", isOn: $settings.showMenuBarIcon)
                    .help("如果关闭，需要靠快捷键唤起；以防万一不要同时关掉快捷键")
            }

            Section("行为") {
                Toggle("启动应用后自动收起", isOn: $settings.hideOnLaunch)
                Toggle("点击空白处收起", isOn: $settings.hideOnClickOutside)
            }

            Section("布局") {
                Stepper(value: $settings.columns, in: 5...10) {
                    HStack { Text("每行图标"); Spacer(); Text("\(settings.columns)") }
                }
                Stepper(value: $settings.rows, in: 4...8) {
                    HStack { Text("每页行数"); Spacer(); Text("\(settings.rows)") }
                }
            }

            Section("重置") {
                Button("恢复默认设置…") { showResetAlert = true }
                Button("重新扫描应用") {
                    Task { @MainActor in await LauncherStore.shared.reload() }
                }
            }
        }
        .formStyle(.grouped)
        .alert("恢复默认设置？", isPresented: $showResetAlert) {
            Button("取消", role: .cancel) {}
            Button("恢复", role: .destructive) {
                settings.resetAll()
                NotificationCenter.default.post(name: .launchDeskLayoutChanged, object: nil)
            }
        } message: {
            Text("将清除所有偏好设置，但不会删除应用、收藏或最近使用记录。")
        }
        .onChange(of: settings.columns) { _ in NotificationCenter.default.post(name: .launchDeskLayoutChanged, object: nil) }
        .onChange(of: settings.rows)    { _ in NotificationCenter.default.post(name: .launchDeskLayoutChanged, object: nil) }
    }
}

// MARK: - 快捷键
private struct HotKeyTab: View {
    @ObservedObject var settings = AppSettings.shared
    @State private var recording = false

    var body: some View {
        Form {
            Section("唤起 / 收起 LaunchDesk") {
                HStack {
                    HotKeyRecorder(
                        keyCode: $settings.hotKeyCode,
                        modifiers: $settings.hotKeyMods,
                        isRecording: $recording
                    )
                    .frame(width: 220)

                    Spacer()
                    Button("还原默认") {
                        settings.hotKeyCode = 37     // L
                        settings.hotKeyMods = 528384 // ⌃⌥
                    }
                }
                .help("点击录制框 → 按下你想用的组合（必须包含至少一个修饰键）")

                if !HotKeyManager.isAvailable {
                    Text("App Store 沙盒版本不支持全局快捷键，请用菜单栏图标")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                } else {
                    Text("提示：如果按了没反应，请到「系统设置 → 隐私与安全 → 输入监控」中允许 LaunchDesk")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }

            Section("窗口内快捷键（不可改）") {
                row("唤起后立即键入", "进入搜索")
                row("Esc", "收起窗口")
                row("←  → ↑ ↓", "在网格中移动焦点")
                row("Return", "启动选中项 / 启动搜索结果第一项")
                row("⌘ 1 - 9", "直达对应页")
                row("拖一个图标到另一个", "建文件夹")
            }
        }
        .formStyle(.grouped)
        .onChange(of: settings.hotKeyCode) { _ in applyHotKey() }
        .onChange(of: settings.hotKeyMods) { _ in applyHotKey() }
    }

    private func row(_ key: String, _ desc: String) -> some View {
        HStack {
            Text(key).font(.system(.body, design: .monospaced)).foregroundStyle(.primary)
            Spacer()
            Text(desc).foregroundStyle(.secondary).font(.system(size: 12))
        }
    }

    private func applyHotKey() {
        HotKeyManager.shared.updateBinding(keyCode: settings.hotKeyCode,
                                           modifiers: settings.hotKeyMods)
    }
}

// MARK: - 外观
private struct AppearanceTab: View {
    @ObservedObject var settings = AppSettings.shared
    var body: some View {
        Form {
            Section("主题") {
                Picker("主题", selection: $settings.theme) {
                    Text("深色").tag("dark")
                    Text("浅色").tag("light")
                    Text("蓝紫渐变").tag("blue")
                    Text("通透").tag("clear")
                    Text("跟随系统").tag("system")
                }
                .pickerStyle(.menu)
            }

            Section("毛玻璃") {
                HStack {
                    Text("强度")
                    Slider(value: $settings.blurStrength, in: 0.0...1.0)
                    Text(String(format: "%.0f%%", settings.blurStrength * 100))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .frame(width: 44, alignment: .trailing)
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - 首页
private struct HomeTab: View {
    @ObservedObject var settings = AppSettings.shared
    @State private var showFavAlert = false
    @State private var showRecentAlert = false
    @State private var showLayoutAlert = false

    var body: some View {
        Form {
            Section("收藏夹") {
                Toggle("在顶部显示收藏夹", isOn: $settings.showFavorite)
                Button("清空收藏夹…") { showFavAlert = true }
            }

            Section("最近使用") {
                Toggle("在顶部显示最近使用", isOn: $settings.showRecent)
                Stepper(value: $settings.recentLimit, in: 4...20) {
                    HStack { Text("显示数量"); Spacer(); Text("\(settings.recentLimit)") }
                }
                Button("清空最近使用记录…") { showRecentAlert = true }
            }

            Section("布局") {
                Button("重新整理网格…") { showLayoutAlert = true }
                Text("会根据当前列×行重新分页，并按字母顺序排列。")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .alert("清空收藏夹？", isPresented: $showFavAlert) {
            Button("取消", role: .cancel) {}
            Button("清空", role: .destructive) {
                Task { @MainActor in LauncherStore.shared.clearFavorites() }
            }
        }
        .alert("清空最近使用记录？", isPresented: $showRecentAlert) {
            Button("取消", role: .cancel) {}
            Button("清空", role: .destructive) {
                Task { @MainActor in LauncherStore.shared.clearRecents() }
            }
        }
        .alert("重新整理网格？", isPresented: $showLayoutAlert) {
            Button("取消", role: .cancel) {}
            Button("整理", role: .destructive) {
                Task { @MainActor in LauncherStore.shared.clearLayout() }
            }
        } message: {
            Text("文件夹分组会被打散，回到按字母排序的网格。")
        }
    }
}

// MARK: - 隐藏的 App
private struct HiddenAppsTab: View {
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var store = LauncherStore.shared
    @State private var query = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("已扫描 \(store.apps.count) 个应用，已隐藏 \(settings.hiddenAppIDs.count) 个")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Spacer()
                if !settings.hiddenAppIDs.isEmpty {
                    Button("全部恢复") {
                        settings.hiddenAppIDs = []
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 6)

            TextField("搜索", text: $query)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

            List {
                ForEach(filteredApps, id: \.id) { app in
                    HStack {
                        Image(nsImage: app.icon(size: 18))
                            .resizable()
                            .frame(width: 18, height: 18)
                        Text(app.name)
                        Spacer()
                        Toggle("", isOn: bindingForHidden(app.id))
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .help("打开后此 App 不会出现在网格里")
                    }
                }
            }
            .listStyle(.inset)
        }
    }

    private var filteredApps: [AppItem] {
        let q = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let all = store.apps.values.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        guard !q.isEmpty else { return all }
        return all.filter { $0.name.lowercased().contains(q) }
    }

    private func bindingForHidden(_ id: String) -> Binding<Bool> {
        Binding(
            get: { settings.hiddenAppIDs.contains(id) },
            set: { hidden in
                if hidden { settings.hiddenAppIDs.insert(id) }
                else      { settings.hiddenAppIDs.remove(id) }
            }
        )
    }
}

// MARK: - 关于
private struct AboutTab: View {
    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
    private var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "square.grid.3x3.fill")
                .font(.system(size: 64, weight: .light))
                .foregroundStyle(LinearGradient(
                    colors: [.blue, .purple],
                    startPoint: .topLeading, endPoint: .bottomTrailing))

            VStack(spacing: 6) {
                Text("LaunchDesk").font(.system(size: 22, weight: .semibold))
                Text("版本 \(version) (\(build))")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            }

            Text("一个简洁、原生、好看的 macOS 应用启动器。")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)

            HStack(spacing: 16) {
                Link("反馈", destination: URL(string: "https://github.com/")!)
                Link("项目主页", destination: URL(string: "https://github.com/")!)
                Button("查看欢迎引导") {
                    if let app = NSApp.delegate as? AppDelegate {
                        app.showWelcome()
                    }
                }
                .buttonStyle(.link)
            }

            Spacer()
            Text("© 2026 LaunchDesk")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .padding(.bottom, 12)
        }
        .padding()
    }
}

// MARK: - 快捷键录制器
struct HotKeyRecorder: NSViewRepresentable {
    @Binding var keyCode: UInt32
    @Binding var modifiers: UInt32
    @Binding var isRecording: Bool

    func makeNSView(context: Context) -> RecorderView {
        let v = RecorderView()
        v.onCapture = { kc, mods in
            self.keyCode = kc
            self.modifiers = mods
            self.isRecording = false
        }
        v.onRecordingChange = { self.isRecording = $0 }
        v.refresh(keyCode: keyCode, modifiers: modifiers)
        return v
    }

    func updateNSView(_ nsView: RecorderView, context: Context) {
        nsView.refresh(keyCode: keyCode, modifiers: modifiers)
    }

    final class RecorderView: NSView {
        var onCapture: ((UInt32, UInt32) -> Void)?
        var onRecordingChange: ((Bool) -> Void)?
        private let label = NSTextField(labelWithString: "")
        private var localMonitor: Any?
        private var recording = false {
            didSet { needsDisplay = true; onRecordingChange?(recording) }
        }

        override init(frame: NSRect) {
            super.init(frame: frame)
            wantsLayer = true
            layer?.cornerRadius = 6
            layer?.borderWidth = 1
            layer?.borderColor = NSColor.separatorColor.cgColor
            label.alignment = .center
            label.translatesAutoresizingMaskIntoConstraints = false
            label.font = .systemFont(ofSize: 13, weight: .medium)
            addSubview(label)
            NSLayoutConstraint.activate([
                label.centerXAnchor.constraint(equalTo: centerXAnchor),
                label.centerYAnchor.constraint(equalTo: centerYAnchor),
                heightAnchor.constraint(equalToConstant: 28)
            ])
        }
        required init?(coder: NSCoder) { fatalError() }

        override var acceptsFirstResponder: Bool { true }
        override func mouseDown(with event: NSEvent) { startRecording() }

        func refresh(keyCode: UInt32, modifiers: UInt32) {
            label.stringValue = recording ? "请按下组合键…" : Self.describe(keyCode: keyCode, modifiers: modifiers)
            layer?.backgroundColor = (recording ? NSColor.controlAccentColor.withAlphaComponent(0.18) : .clear).cgColor
        }

        private func startRecording() {
            guard !recording else { return }
            recording = true
            refresh(keyCode: 0, modifiers: 0)
            localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] e in
                guard let self = self, self.recording else { return e }
                if e.type == .keyDown {
                    let mods = Self.carbonMods(from: e.modifierFlags)
                    let kc = UInt32(e.keyCode)
                    if mods != 0 {
                        self.onCapture?(kc, mods)
                        self.stopRecording()
                    } else if kc == UInt32(kVK_Escape) {
                        self.stopRecording()
                    }
                    return nil
                }
                return e
            }
        }

        private func stopRecording() {
            recording = false
            if let m = localMonitor { NSEvent.removeMonitor(m) }
            localMonitor = nil
        }

        static func carbonMods(from flags: NSEvent.ModifierFlags) -> UInt32 {
            var m: UInt32 = 0
            if flags.contains(.command)  { m |= UInt32(cmdKey) }
            if flags.contains(.option)   { m |= UInt32(optionKey) }
            if flags.contains(.control)  { m |= UInt32(controlKey) }
            if flags.contains(.shift)    { m |= UInt32(shiftKey) }
            return m
        }

        static func describe(keyCode: UInt32, modifiers: UInt32) -> String {
            var s = ""
            if modifiers & UInt32(controlKey)  != 0 { s += "⌃" }
            if modifiers & UInt32(optionKey)   != 0 { s += "⌥" }
            if modifiers & UInt32(shiftKey)    != 0 { s += "⇧" }
            if modifiers & UInt32(cmdKey)      != 0 { s += "⌘" }
            s += keyName(for: keyCode)
            return s.isEmpty ? "未设置" : s
        }

        static func keyName(for keyCode: UInt32) -> String {
            switch Int(keyCode) {
            case kVK_Space: return "Space"
            case kVK_Return: return "↩"
            case kVK_Tab: return "⇥"
            case kVK_Escape: return "Esc"
            case kVK_F1: return "F1"; case kVK_F2: return "F2"; case kVK_F3: return "F3"
            case kVK_F4: return "F4"; case kVK_F5: return "F5"; case kVK_F6: return "F6"
            case kVK_F7: return "F7"; case kVK_F8: return "F8"; case kVK_F9: return "F9"
            case kVK_F10: return "F10"; case kVK_F11: return "F11"; case kVK_F12: return "F12"
            default:
                if let s = layoutChar(for: keyCode) { return s.uppercased() }
                return "Key\(keyCode)"
            }
        }

        private static func layoutChar(for keyCode: UInt32) -> String? {
            guard let src = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
                  let layoutData = TISGetInputSourceProperty(src, kTISPropertyUnicodeKeyLayoutData)
            else { return nil }
            let data = Unmanaged<CFData>.fromOpaque(layoutData).takeUnretainedValue() as Data
            return data.withUnsafeBytes { ptr -> String? in
                guard let layoutPtr = ptr.baseAddress?
                        .assumingMemoryBound(to: UCKeyboardLayout.self)
                else { return nil }
                var deadKeyState: UInt32 = 0
                var chars: [UniChar] = Array(repeating: 0, count: 4)
                var actualLength = 0
                let err = UCKeyTranslate(layoutPtr,
                                         UInt16(keyCode),
                                         UInt16(kUCKeyActionDisplay),
                                         0,
                                         UInt32(LMGetKbdType()),
                                         UInt32(kUCKeyTranslateNoDeadKeysBit),
                                         &deadKeyState,
                                         chars.count,
                                         &actualLength,
                                         &chars)
                if err == noErr, actualLength > 0 {
                    return String(utf16CodeUnits: chars, count: actualLength)
                }
                return nil
            }
        }
    }
}

extension Notification.Name {
    static let launchDeskLayoutChanged = Notification.Name("LaunchDesk.LayoutChanged")
}
