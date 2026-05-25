import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// 单个应用图标格
struct AppCellView: View {
    let app: AppItem
    var compact: Bool = false           // 文件夹缩略图模式
    var selected: Bool = false          // 键盘焦点
    @EnvironmentObject var store: LauncherStore
    @State private var hover = false
    @State private var bounce = false

    var body: some View {
        VStack(spacing: compact ? 2 : 6) {
            ZStack {
                // 焦点高亮
                if selected {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.18))
                        .frame(width: (compact ? 32 : 86), height: (compact ? 32 : 86))
                }
                Image(nsImage: app.icon(size: compact ? 32 : 72))
                    .resizable()
                    .interpolation(.medium)
                    .frame(width: compact ? 32 : 72, height: compact ? 32 : 72)
                    .scaleEffect(bounce ? 0.84 : (hover || selected ? 1.08 : 1.0))
                    .animation(.spring(response: 0.32, dampingFraction: 0.55), value: hover)
                    .animation(.spring(response: 0.22, dampingFraction: 0.5), value: bounce)
                    .animation(.spring(response: 0.28, dampingFraction: 0.6), value: selected)
            }

            if !compact {
                Text(app.name)
                    .font(.system(size: 12))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: 96)
            }
        }
        .contentShape(Rectangle())
        .onHover { hover = $0 }
        .onTapGesture {
            bounce = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                bounce = false
                LaunchService.launch(app)
            }
        }
        .contextMenu {
            Button("打开") { LaunchService.launch(app) }
            Button(store.isFavorite(app.id) ? "取消收藏" : "收藏") {
                store.toggleFavorite(app.id)
            }
            Divider()
            Button("在 Finder 中显示") {
                NSWorkspace.shared.activateFileViewerSelecting([app.url])
            }
            Button("在 LaunchDesk 中隐藏") {
                AppSettings.shared.hiddenAppIDs.insert(app.id)
            }
            if LaunchService.supportsUninstall {
                Divider()
                Button("卸载…", role: .destructive) {
                    LaunchService.uninstall(app) { ok in
                        if ok { Task { await store.reload() } }
                    }
                }
            }
        }
    }
}

/// 文件夹格子（小宫格预览）
struct FolderCellView: View {
    let folder: Folder
    var selected: Bool = false
    let onOpen: () -> Void
    @EnvironmentObject var store: LauncherStore
    @State private var hover = false

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                if selected {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.18))
                        .frame(width: 86, height: 86)
                }
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.18))
                    .frame(width: 76, height: 76)

                LazyVGrid(columns: Array(repeating: SwiftUI.GridItem(.fixed(20), spacing: 4), count: 3), spacing: 4) {
                    ForEach(folder.appIDs.prefix(9), id: \.self) { id in
                        if let a = store.apps[id] {
                            Image(nsImage: a.icon(size: 18))
                                .resizable()
                                .frame(width: 18, height: 18)
                        } else {
                            Color.clear.frame(width: 18, height: 18)
                        }
                    }
                }
                .frame(width: 64, height: 64)
            }
            .scaleEffect(hover || selected ? 1.06 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: hover)
            .animation(.spring(response: 0.28, dampingFraction: 0.6), value: selected)

            Text(folder.name)
                .font(.system(size: 12))
                .foregroundStyle(.white)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: 96)
        }
        .contentShape(Rectangle())
        .onHover { hover = $0 }
        .onTapGesture(perform: onOpen)
    }
}
