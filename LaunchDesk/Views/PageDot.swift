import SwiftUI

/// 分页圆点：当前页较亮，其它页较暗。极简风。
struct PageDot: View {
    let active: Bool
    let onTap: () -> Void

    @State private var hover = false

    var body: some View {
        Circle()
            .fill(fillColor)
            .frame(width: 8, height: 8)
            .scaleEffect(hover ? 1.25 : 1.0)
            .animation(.easeOut(duration: 0.18), value: active)
            .animation(.easeOut(duration: 0.18), value: hover)
            .padding(4) // 增加可点击范围
            .contentShape(Rectangle())
            .onHover { hover = $0 }
            .onTapGesture(perform: onTap)
    }

    private var fillColor: Color {
        active
            ? Color.white.opacity(0.95)
            : Color.white.opacity(hover ? 0.55 : 0.35)
    }
}
