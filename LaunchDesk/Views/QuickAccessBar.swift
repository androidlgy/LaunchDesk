import SwiftUI

/// 顶部快捷访问条：收藏夹 + 最近使用
struct QuickAccessBar: View {
    @EnvironmentObject var store: LauncherStore
    @ObservedObject var settings = AppSettings.shared

    var body: some View {
        HStack(alignment: .top, spacing: 28) {
            if settings.showFavorite, !store.favorites.isEmpty {
                section(title: "收藏夹", systemImage: "star.fill", appIDs: store.favorites)
            }
            if settings.showRecent, !store.recents.isEmpty {
                section(title: "最近使用", systemImage: "clock.fill",
                        appIDs: Array(store.recents.prefix(8)))
            }
        }
        .padding(.horizontal, 80)
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private func section(title: String, systemImage: String, appIDs: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 10, weight: .semibold))
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(.white.opacity(0.7))

            HStack(spacing: 14) {
                ForEach(appIDs, id: \.self) { id in
                    if let app = store.apps[id] {
                        MiniAppCell(app: app)
                    }
                }
            }
        }
    }
}

/// 收藏栏里的小图标
private struct MiniAppCell: View {
    let app: AppItem
    @State private var hover = false

    var body: some View {
        VStack(spacing: 2) {
            Image(nsImage: app.icon(size: 36))
                .resizable()
                .frame(width: 36, height: 36)
                .scaleEffect(hover ? 1.12 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: hover)
        }
        .help(app.name)
        .contentShape(Rectangle())
        .onHover { hover = $0 }
        .onTapGesture { LaunchService.launch(app) }
    }
}
