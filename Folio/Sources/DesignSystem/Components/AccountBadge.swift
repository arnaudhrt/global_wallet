import SwiftUI

struct AccountBadge: View {
    @Environment(\.theme) private var theme

    let name: String

    var body: some View {
        Text(name)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(theme.text2)
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 3))
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .stroke(theme.border, lineWidth: 1)
            )
    }
}
