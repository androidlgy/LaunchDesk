import Foundation
import AppKit
#if !APPSTORE
import Carbon.HIToolbox
#endif

/// 注册全局快捷键。
///
/// - 非 AppStore：使用 Carbon 注册系统级全局快捷键（默认 ⌥Space）
/// - AppStore：沙盒下无法注册全局快捷键，改为 no-op；用户可通过状态栏菜单或本地快捷键唤起
final class HotKeyManager {
    static let shared = HotKeyManager()

    /// 是否支持全局快捷键
    static var isAvailable: Bool {
        #if APPSTORE
        return false
        #else
        return true
        #endif
    }

    func register(onTrigger: @escaping () -> Void) {
        #if APPSTORE
        // App Store 沙盒版本不注册全局快捷键
        _ = onTrigger
        #else
        self.onTrigger = onTrigger
        installHandlerIfNeeded()
        installHotKey()
        #endif
    }

    func updateBinding(keyCode: UInt32, modifiers: UInt32) {
        #if !APPSTORE
        self.keyCode = keyCode
        self.modifiers = modifiers
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        installHotKey()
        #endif
    }

    // MARK: - 仅非 AppStore 实现
    #if !APPSTORE
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private var onTrigger: (() -> Void)?

    private let signature: OSType = {
        // 'LDsk'
        let bytes: [UInt8] = [0x4C, 0x44, 0x73, 0x6B]
        return bytes.reduce(0) { ($0 << 8) | OSType($1) }
    }()
    private let id: UInt32 = 1

    /// 默认 Option + Space
    private(set) var keyCode: UInt32 = UInt32(kVK_Space)
    private(set) var modifiers: UInt32 = UInt32(optionKey)

    private func installHandlerIfNeeded() {
        guard handlerRef == nil else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: OSType(kEventHotKeyPressed))
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { (_, evt, ud) -> OSStatus in
            guard let ud = ud, let evt = evt else { return noErr }
            var hk = EventHotKeyID()
            GetEventParameter(evt, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &hk)
            let mgr = Unmanaged<HotKeyManager>.fromOpaque(ud).takeUnretainedValue()
            if hk.id == mgr.id { mgr.onTrigger?() }
            return noErr
        }, 1, &spec, selfPtr, &handlerRef)
    }

    private func installHotKey() {
        // 安全保护：modifiers 必须包含至少一个修饰键，否则拒绝注册
        // （否则会出现"按一个 Space 就唤起"这种危险情况）
        let needsModifier: UInt32 = UInt32(cmdKey) | UInt32(optionKey) | UInt32(controlKey) | UInt32(shiftKey)
        if modifiers & needsModifier == 0 {
            NSLog("[LaunchDesk] refuse to register hotkey without modifier (keyCode=\(keyCode))")
            return
        }
        let hkID = EventHotKeyID(signature: signature, id: id)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(keyCode, modifiers, hkID, GetApplicationEventTarget(), 0, &ref)
        if status == noErr { hotKeyRef = ref } else {
            NSLog("[LaunchDesk] RegisterEventHotKey failed: \(status)")
        }
    }
    #endif
}
