import SwiftUI

struct EditorMenuTabLabel: View {
    let title: String
    let systemImage: String
    var isSelected: Bool = false

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .background(
                isSelected
                ? Color(red: 0.16, green: 0.38, blue: 0.82)
                : Color(uiColor: .secondarySystemBackground)
            )
            .clipShape(Capsule())
    }
}
