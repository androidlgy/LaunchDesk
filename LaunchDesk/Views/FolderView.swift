import SwiftUI

/// 文件夹打开后的内部视图
struct FolderView: View {
    @Binding var folder: Folder
    var onClose: () -> Void
    @EnvironmentObject var store: LauncherStore
    @State private var renaming: Bool = false
    @State private var draftName: String = ""

    private let columns = Array(repeating: SwiftUI.GridItem(.fixed(110), spacing: 16), count: 5)

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Spacer()
                if renaming {
                    TextField("文件夹名称", text: $draftName, onCommit: commitRename)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 240)
                } else {
                    Text(folder.name)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                        .onTapGesture {
                            draftName = folder.name
                            renaming = true
                        }
                }
                Spacer()
            }

            LazyVGrid(columns: columns, spacing: 22) {
                ForEach(folder.appIDs, id: \.self) { id in
                    if let a = store.apps[id] {
                        AppCellView(app: a)
                            .contextMenu {
                                Button("从文件夹移出") {
                                    store.popOutOfFolder(folderID: folder.id,
                                                         appID: id,
                                                         toPage: 0)
                                    onClose()
                                }
                            }
                    }
                }
            }
            .padding(.horizontal, 24)

            Spacer()
        }
        .padding(.top, 24)
        .frame(maxWidth: 720, maxHeight: 480)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.black.opacity(0.35))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
        )
    }

    private func commitRename() {
        let trimmed = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            folder.name = trimmed
            store.renameFolder(folder.id, to: trimmed)
        }
        renaming = false
    }
}
