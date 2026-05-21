import SwiftUI

/// Non-functional search field shown in the macOS toolbar. Wired to a real
/// holdings search in M10. Rendered as a styled `HStack` (not a `TextField`) so
/// the focus ring never lands on it.
struct ToolbarSearchStub: View {
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(theme.text3)
            Text("Search")
                .font(.system(size: 13))
                .foregroundStyle(theme.text3)
            Spacer(minLength: 0)
            
        }
        .padding(.horizontal, 10)
        .frame(width: 240, height: 28)
        .allowsHitTesting(true)
    }
}
