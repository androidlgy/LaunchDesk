import SwiftUI
import AppKit

/// 首次启动引导
struct WelcomeView: View {
    var onDone: () -> Void
    @State private var step = 0

    var body: some View {
        VStack(spacing: 24) {
            // 顶部图标
            Image(systemName: "square.grid.3x3.fill")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(LinearGradient(
                    colors: [.blue, .purple],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
                .padding(.top, 24)

            VStack(spacing: 10) {
                Text(steps[step].title)
                    .font(.system(size: 22, weight: .semibold))
                Text(steps[step].body)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
            }

            // 步骤特定的视图
            stepDetail(for: step)
                .frame(height: 96)

            Spacer()

            // 底部进度 + 按钮
            VStack(spacing: 12) {
                HStack(spacing: 6) {
                    ForEach(0..<steps.count, id: \.self) { i in
                        Circle()
                            .fill(i == step ? Color.accentColor : Color.gray.opacity(0.3))
                            .frame(width: 6, height: 6)
                    }
                }

                HStack {
                    if step > 0 {
                        Button("上一步") { withAnimation { step -= 1 } }
                            .buttonStyle(.bordered)
                    }
                    Spacer()
                    if step < steps.count - 1 {
                        Button("下一步") { withAnimation { step += 1 } }
                            .buttonStyle(.borderedProminent)
                    } else {
                        Button("开始使用") { onDone() }
                            .buttonStyle(.borderedProminent)
                    }
                }
                .padding(.horizontal, 24)
            }
            .padding(.bottom, 24)
        }
        .frame(width: 460, height: 460)
        .background(VisualEffectView(material: .windowBackground,
                                     blendingMode: .behindWindow,
                                     state: .active))
    }

    @ViewBuilder
    private func stepDetail(for step: Int) -> some View {
        switch step {
        case 0:
            VStack(spacing: 6) {
                Image(systemName: "command")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(.blue)
                Text("默认快捷键：⌥ Space").font(.system(size: 13, weight: .medium))
                Text("可以在偏好设置里改成你喜欢的组合")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
        case 1:
            VStack(spacing: 6) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(.orange)
                Text("授权才能注册全局快捷键").font(.system(size: 13, weight: .medium))
                Button("打开「输入监控」设置") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.link)
            }
        case 2:
            VStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(.purple)
                Text("使用提示").font(.system(size: 13, weight: .medium))
                Text("• 拖动图标到另一个图标上自动建文件夹\n• 输 wx 也能搜到「微信」\n• ⌘1-9 直达对应页")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
            }
        default: EmptyView()
        }
    }

    private struct Step {
        let title: String
        let body: String
    }

    private let steps: [Step] = [
        .init(title: "欢迎使用 LaunchDesk",
              body: "你的 macOS 应用启动器。一个键唤起所有应用，输入即搜索，拖拽即分组。"),
        .init(title: "授予权限",
              body: "为了在全局任意位置都能用快捷键唤起，需要在系统设置中允许「输入监控」。"),
        .init(title: "你已经准备好了",
              body: "通过菜单栏图标或设置好的快捷键，随时唤起 LaunchDesk。")
    ]
}
