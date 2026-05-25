import SwiftUI
import UniformTypeIdentifiers

/// 单页网格，支持拖拽排序与拖入合并
struct GridPageView: View {
    let pageIndex: Int
    let items: [GridItem]
    /// 当前焦点的 GridItem.id（来自父视图，跨页共享）
    var focusedID: String? = nil
    var onOpenFolder: (Folder) -> Void

    @EnvironmentObject var store: LauncherStore
    /// 当前 hover 中的潜在合并目标（用于放大吸附动画）
    @State private var dropTargetID: String? = nil
    /// 正在被拖动的 cell（让它半透明）
    @State private var draggingID: String? = nil

    private var columns: [SwiftUI.GridItem] {
        Array(repeating: SwiftUI.GridItem(.flexible(minimum: 100), spacing: 32),
              count: store.columns)
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 36) {
            ForEach(items, id: \.id) { item in
                cell(for: item)
                    .scaleEffect(dropTargetID == item.id ? 1.18 : 1.0)
                    .opacity(draggingID == item.id ? 0.4 : 1.0)
                    .animation(.spring(response: 0.28, dampingFraction: 0.65), value: dropTargetID)
                    .onDrag {
                        draggingID = item.id
                        return NSItemProvider(object: item.id as NSString)
                    }
                    .onDrop(of: [UTType.text],
                            delegate: CellDropDelegate(
                                targetID: item.id,
                                pageIndex: pageIndex,
                                store: store,
                                onEntered: { dropTargetID = item.id },
                                onExited:  { if dropTargetID == item.id { dropTargetID = nil } },
                                onFinish:  {
                                    dropTargetID = nil
                                    draggingID = nil
                                }
                            ))
            }
        }
        .padding(.horizontal, 100)
        .padding(.vertical, 24)
    }

    @ViewBuilder
    private func cell(for item: GridItem) -> some View {
        switch item {
        case .app(let id):
            if let a = store.apps[id] {
                AppCellView(app: a, selected: focusedID == item.id)
            } else {
                Color.clear.frame(width: 96, height: 110)
            }
        case .folder(let f):
            FolderCellView(folder: f, selected: focusedID == item.id) { onOpenFolder(f) }
        }
    }
}

/// 处理：把一个 cell 拖到另一个 cell 上
struct CellDropDelegate: DropDelegate {
    let targetID: String
    let pageIndex: Int
    let store: LauncherStore
    let onEntered: () -> Void
    let onExited: () -> Void
    let onFinish: () -> Void

    func validateDrop(info: DropInfo) -> Bool { true }

    func dropEntered(info: DropInfo) { onEntered() }
    func dropExited(info: DropInfo) { onExited() }

    func performDrop(info: DropInfo) -> Bool {
        guard let provider = info.itemProviders(for: [UTType.text]).first else {
            onFinish(); return false
        }
        provider.loadObject(ofClass: NSString.self) { obj, _ in
            guard let s = obj as? String else { return }
            DispatchQueue.main.async {
                defer { onFinish() }
                if s == targetID { return }
                if let from = store.indexPath(of: s), let to = store.indexPath(of: targetID) {
                    let src = store.pages[from.page][from.index]
                    let dst = store.pages[to.page][to.index]
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.75)) {
                        switch (src, dst) {
                        case (.app, .app), (.app, .folder):
                            store.merge(sourceID: s, into: targetID)
                        default:
                            store.move(itemID: s, toPage: to.page, index: to.index)
                        }
                    }
                }
            }
        }
        return true
    }
}
