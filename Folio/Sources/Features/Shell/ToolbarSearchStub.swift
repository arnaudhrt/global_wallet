import SwiftUI

/// Non-functional search field shown in the macOS toolbar. Wired to a real
/// holdings search in M10. Rendered as a styled `HStack` (not a `TextField`) so
/// the focus ring never lands on it.
struct ToolbarSearchStub: View {
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(theme.text3)
            Text("Search holdings")
                .font(.system(size: 12))
                .foregroundStyle(theme.text2)
            Spacer(minLength: 12)
            Text("⌘K")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(theme.text3)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .frame(width: 200)
        .background(theme.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .stroke(theme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .allowsHitTesting(false)
    }
}
