import SwiftUI
import AppKit

/// 主题化背景 — 模仿 macOS Launchpad：桌面壁纸 + 重度毛玻璃 + 暗色叠加
struct ThemedBackground: View {
    @ObservedObject var settings = AppSettings.shared

    var body: some View {
        ZStack {
            // 1. 透出桌面壁纸的毛玻璃（fullScreenUI 是 macOS Launchpad 同款 material）
            VisualEffectView(material: material(),
                             blendingMode: .behindWindow,
                             state: .active)

            // 2. 主题色叠层
            tint()
        }
    }

    /// 根据主题选择 material（fullScreenUI 是最像 Launchpad 的那种"透出底色"的浓重模糊）
    private func material() -> NSVisualEffectView.Material {
        switch settings.theme {
        case "light":  return .hudWindow
        case "blue":   return .fullScreenUI
        case "clear":  return .fullScreenUI
        case "system": return .fullScreenUI
        default:       return .fullScreenUI   // dark — Launchpad 默认即此
        }
    }

    /// 根据主题与 blurStrength 叠加颜色层
    @ViewBuilder
    private func tint() -> some View {
        switch settings.theme {
        case "light":
            Color.white.opacity(0.30 * settings.blurStrength + 0.10)
        case "blue":
            LinearGradient(colors: [
                Color(red: 0.10, green: 0.18, blue: 0.42).opacity(0.45 * settings.blurStrength + 0.15),
                Color(red: 0.32, green: 0.10, blue: 0.46).opacity(0.45 * settings.blurStrength + 0.15)
            ], startPoint: .topLeading, endPoint: .bottomTrailing)
        case "clear":
            Color.black.opacity(0.10 * settings.blurStrength)
        case "system":
            Color.black.opacity(0.20 * settings.blurStrength + 0.05)
        default: // dark
            Color.black.opacity(0.30 * settings.blurStrength + 0.10)
        }
    }
}
