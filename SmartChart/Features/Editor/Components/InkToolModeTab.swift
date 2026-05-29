import SwiftUI

struct InkToolModeTab: View {
    @Binding var mode: EditorInkToolMode

    var body: some View {
        VStack(spacing: 4) {
            ForEach(EditorInkToolMode.allCases, id: \.self) { toolMode in
                Button {
                    mode = toolMode
                } label: {
                    Image(systemName: toolMode.systemImageName)
                        .font(.system(size: 18, weight: .semibold))
                        .frame(width: 40, height: 40)
                        .foregroundStyle(mode == toolMode ? Color.white : Color.black.opacity(0.72))
                        .background(buttonBackground(for: toolMode))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(toolMode.accessibilityLabel)
                .accessibilityAddTraits(mode == toolMode ? [.isSelected] : [])
            }
        }
        .padding(5)
        .background(Color.white.opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.black.opacity(0.10), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.10), radius: 8, x: 0, y: 3)
    }

    @ViewBuilder
    private func buttonBackground(for toolMode: EditorInkToolMode) -> some View {
        if mode == toolMode {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(red: 0.12, green: 0.38, blue: 0.86))
        } else {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.black.opacity(0.04))
        }
    }
}
