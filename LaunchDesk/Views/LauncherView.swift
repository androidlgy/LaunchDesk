import SwiftUI
import AppKit

struct LauncherView: View {
    @EnvironmentObject var store: LauncherStore
    @ObservedObject private var settings = AppSettings.shared
    @State private var currentPage: Int = 0
    @State private var dragOffset: CGFloat = 0
    @State private var openedFolder: Folder?
    @State private var focusedID: String? = nil
    @FocusState private var searchFocused: Bool

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // 1. 背景层
                ThemedBackground()
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if settings.hideOnClickOutside { hide() }
                    }

                // 2. 主内容
                VStack(spacing: 0) {
                    SearchBar(
                        text: $store.searchText,
                        focused: $searchFocused,
                        onSubmit: openFirstSearchResult
                    )
                    .padding(.top, 28)
                    .padding(.bottom, 8)

                    if store.searchText.isEmpty,
                       (settings.showFavorite && !store.favorites.isEmpty) ||
                       (settings.showRecent   && !store.recents.isEmpty) {
                        QuickAccessBar()
                            .padding(.top, 4)
                    }

                    Spacer(minLength: 0)

                    if store.searchText.isEmpty {
                        if store.apps.isEmpty {
                            loadingView
                        } else {
                            pages(in: geo.size)
                        }
                    } else {
                        searchResultView
                    }

                    Spacer(minLength: 0)

                    // 底部圆点
                    if store.searchText.isEmpty, store.pages.count > 1 {
                        HStack(spacing: 10) {
                            ForEach(store.pages.indices, id: \.self) { idx in
                                PageDot(active: idx == currentPage) {
                                    changePage(to: idx)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 32)
                    } else {
                        Color.clear.frame(height: 32)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 24)
                    .onChanged { v in
                        if store.searchText.isEmpty,
                           abs(v.translation.width) > abs(v.translation.height) {
                            dragOffset = v.translation.width
                        }
                    }
                    .onEnded { v in
                        guard store.searchText.isEmpty else { return }
                        let threshold = geo.size.width / 5
                        var target = currentPage
                        if v.translation.width < -threshold { target = min(currentPage + 1, store.pages.count - 1) }
                        if v.translation.width >  threshold { target = max(currentPage - 1, 0) }
                        withAnimation(.interactiveSpring(response: 0.34, dampingFraction: 0.84, blendDuration: 0)) {
                            currentPage = target
                            dragOffset = 0
                        }
                    }
            )
            .onChange(of: store.searchText) { _ in
                if !store.searchText.isEmpty { dragOffset = 0 }
                focusedID = nil // 进入搜索时不显式高亮
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { searchFocused = true }
            }
            .onReceive(NotificationCenter.default.publisher(for: .launchDeskWindowDidShow)) { _ in
                searchFocused = true
                store.searchText = ""
                currentPage = 0
                focusedID = nil
            }
            .onReceive(NotificationCenter.default.publisher(for: .launchDeskPageNext)) { _ in
                guard store.searchText.isEmpty else { return }
                changePage(to: min(currentPage + 1, store.pages.count - 1))
            }
            .onReceive(NotificationCenter.default.publisher(for: .launchDeskPagePrev)) { _ in
                guard store.searchText.isEmpty else { return }
                changePage(to: max(currentPage - 1, 0))
            }
            .onReceive(NotificationCenter.default.publisher(for: .launchDeskJumpToPage)) { note in
                if let idx = note.userInfo?["index"] as? Int,
                   idx < store.pages.count, store.searchText.isEmpty {
                    changePage(to: idx)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .launchDeskKeyArrow)) { note in
                guard store.searchText.isEmpty,
                      let dir = note.userInfo?["dir"] as? String else { return }
                moveFocus(direction: dir)
            }
            .onReceive(NotificationCenter.default.publisher(for: .launchDeskKeyActivate)) { _ in
                activateFocused()
            }
        }
        .overlay {
            if let f = openedFolder {
                ZStack {
                    Color.black.opacity(0.55).ignoresSafeArea()
                        .onTapGesture { openedFolder = nil }
                    FolderView(folder: bindingForFolder(f),
                               onClose: { openedFolder = nil })
                }
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.16), value: openedFolder)
        .onExitCommand { hide() }
    }

    // MARK: - 加载占位
    private var loadingView: some View {
        VStack(spacing: 14) {
            ProgressView()
                .progressViewStyle(.circular)
                .controlSize(.large)
                .tint(.white)
            Text("正在扫描应用…")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 分页（横向偏移）
    private func pages(in size: CGSize) -> some View {
        let pageWidth = size.width
        let lastIdx = max(0, store.pages.count - 1)
        let rawOffset = -CGFloat(currentPage) * pageWidth + dragOffset
        let minOffset = -CGFloat(lastIdx) * pageWidth
        let maxOffset: CGFloat = 0
        let clamped: CGFloat
        if rawOffset > maxOffset {
            clamped = maxOffset + (rawOffset - maxOffset) * 0.35
        } else if rawOffset < minOffset {
            clamped = minOffset + (rawOffset - minOffset) * 0.35
        } else {
            clamped = rawOffset
        }

        return ZStack(alignment: .topLeading) {
            HStack(spacing: 0) {
                ForEach(store.pages.indices, id: \.self) { idx in
                    GridPageView(pageIndex: idx,
                                 items: store.pages[idx],
                                 focusedID: focusedID) { folder in
                        openedFolder = folder
                    }
                    .frame(width: pageWidth)
                }
            }
            .offset(x: clamped)
            .animation(.interactiveSpring(response: 0.34, dampingFraction: 0.84), value: currentPage)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    // MARK: - 搜索结果（分组）
    private var searchResultView: some View {
        let all = store.searchResults()
        let recentSet = Set(store.recents)
        let favSet = Set(store.favorites)
        let recents = all.filter { recentSet.contains($0.id) }
        let favorites = all.filter { favSet.contains($0.id) && !recentSet.contains($0.id) }
        let others = all.filter { !recentSet.contains($0.id) && !favSet.contains($0.id) }

        return Group {
            if all.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 36, weight: .light))
                        .foregroundStyle(.white.opacity(0.5))
                    Text("没有找到 \"\(store.searchText)\"")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        if !recents.isEmpty {
                            searchSection(title: "最近使用", apps: recents)
                        }
                        if !favorites.isEmpty {
                            searchSection(title: "收藏", apps: favorites)
                        }
                        if !others.isEmpty {
                            searchSection(title: recents.isEmpty && favorites.isEmpty ? "所有应用" : "更多结果", apps: others)
                        }
                    }
                    .padding(.horizontal, 80)
                    .padding(.top, 12)
                    .padding(.bottom, 30)
                }
            }
        }
    }

    private func searchSection(title: String, apps: [AppItem]) -> some View {
        // 搜索状态下第一个结果默认高亮
        let firstID = store.searchResults().first?.id
        return VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.65))
            LazyVGrid(columns: Array(repeating: SwiftUI.GridItem(.flexible(minimum: 100), spacing: 28),
                                     count: store.columns),
                      spacing: 24) {
                ForEach(apps) { app in
                    AppCellView(app: app, selected: app.id == firstID)
                }
            }
        }
    }

    // MARK: - 分页指示
    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(store.pages.indices, id: \.self) { idx in
                PageDot(active: idx == currentPage) {
                    changePage(to: idx)
                }
            }
        }
    }

    // MARK: - 焦点导航
    private func ensureFocus() {
        if focusedID == nil {
            if let first = store.pages[safe: currentPage]?.first {
                focusedID = first.id
            }
        }
    }

    private func moveFocus(direction: String) {
        ensureFocus()
        guard let id = focusedID,
              let pos = store.indexPath(of: id) else { return }
        let cols = store.columns
        var newPage = pos.page
        var newIdx = pos.index

        switch direction {
        case "left":
            if pos.index % cols > 0 { newIdx = pos.index - 1 }
            else if pos.page > 0 {
                newPage = pos.page - 1
                let len = store.pages[newPage].count
                let row = pos.index / cols
                let candidate = row * cols + (cols - 1)
                newIdx = min(candidate, len - 1)
            }
        case "right":
            if pos.index % cols < cols - 1, pos.index + 1 < store.pages[pos.page].count {
                newIdx = pos.index + 1
            } else if pos.page < store.pages.count - 1 {
                newPage = pos.page + 1
                let row = pos.index / cols
                let candidate = row * cols
                newIdx = min(candidate, store.pages[newPage].count - 1)
            }
        case "up":
            if pos.index >= cols { newIdx = pos.index - cols }
        case "down":
            if pos.index + cols < store.pages[pos.page].count { newIdx = pos.index + cols }
        default: break
        }

        if newPage != pos.page {
            changePage(to: newPage)
        }
        if let target = store.pages[safe: newPage]?[safe: newIdx] {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) {
                focusedID = target.id
            }
        }
    }

    private func activateFocused() {
        guard let id = focusedID else {
            // 没有焦点：直接启动搜索结果第一项
            openFirstSearchResult()
            return
        }
        if let pos = store.indexPath(of: id) {
            let item = store.pages[pos.page][pos.index]
            switch item {
            case .app(let appID):
                if let app = store.apps[appID] { LaunchService.launch(app); hide() }
            case .folder(let f):
                openedFolder = f
            }
        }
    }

    private func changePage(to idx: Int) {
        withAnimation(.interactiveSpring(response: 0.34, dampingFraction: 0.84)) {
            currentPage = idx
        }
    }

    // MARK: - 操作
    private func openFirstSearchResult() {
        if let first = store.searchResults().first {
            LaunchService.launch(first)
            store.searchText = ""
            hide()
        }
    }

    private func bindingForFolder(_ folder: Folder) -> Binding<Folder> {
        Binding<Folder>(
            get: {
                for page in store.pages {
                    for item in page {
                        if case .folder(let f) = item, f.id == folder.id { return f }
                    }
                }
                return folder
            },
            set: { newVal in
                for (p, page) in store.pages.enumerated() {
                    for (i, item) in page.enumerated() {
                        if case .folder(let f) = item, f.id == newVal.id {
                            store.pages[p][i] = .folder(newVal)
                            return
                        }
                    }
                }
            }
        )
    }

    private func hide() {
        NotificationCenter.default.post(name: .launchDeskShouldHide, object: nil)
    }
}

// MARK: - 安全下标
extension Array {
    subscript(safe i: Int) -> Element? {
        return (indices.contains(i)) ? self[i] : nil
    }
}

// MARK: - 通知名
extension Notification.Name {
    static let launchDeskShouldHide        = Notification.Name("LaunchDesk.ShouldHide")
    static let launchDeskShouldToggle      = Notification.Name("LaunchDesk.ShouldToggle")
    static let launchDeskWindowDidShow     = Notification.Name("LaunchDesk.WindowDidShow")
    static let launchDeskPageNext          = Notification.Name("LaunchDesk.PageNext")
    static let launchDeskPagePrev          = Notification.Name("LaunchDesk.PagePrev")
    static let launchDeskJumpToPage        = Notification.Name("LaunchDesk.JumpToPage")
    static let launchDeskKeyArrow          = Notification.Name("LaunchDesk.KeyArrow")
    static let launchDeskKeyActivate       = Notification.Name("LaunchDesk.KeyActivate")
}
