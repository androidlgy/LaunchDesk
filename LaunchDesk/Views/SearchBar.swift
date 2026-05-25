import SwiftUI

struct SearchBar: View {
    @Binding var text: String
    var focused: FocusState<Bool>.Binding? = nil
    var onSubmit: () -> Void = {}

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.55))
            Group {
                if let focused = focused {
                    TextField("搜索", text: $text)
                        .textFieldStyle(.plain)
                        .focused(focused)
                        .onSubmit(onSubmit)
                } else {
                    TextField("搜索", text: $text)
                        .textFieldStyle(.plain)
                        .onSubmit(onSubmit)
                }
            }
            .font(.system(size: 13))
            .foregroundStyle(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.28))
                .overlay(
                    Capsule().stroke(Color.white.opacity(0.10), lineWidth: 0.5)
                )
        )
        .frame(maxWidth: 240)
    }
}
