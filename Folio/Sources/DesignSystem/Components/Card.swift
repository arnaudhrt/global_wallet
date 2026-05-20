import SwiftUI

struct Card<Content: View>: View {
    @Environment(\.theme) private var theme

    var padded: Bool = true
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padded ? 18 : 0)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.cardBg)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(theme.border, lineWidth: 1)
            )
    }
}
