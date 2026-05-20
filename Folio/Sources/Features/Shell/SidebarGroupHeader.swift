import SwiftUI

/// Uppercased section header used inside the sidebar. Matches the spec's
/// `SidebarHeader` block (11pt semibold, theme.text3, 0.4 letter-spacing).
struct SidebarGroupHeader: View {
    @Environment(\.theme) private var theme
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .tracking(0.4)
            .foregroundStyle(theme.text3)
            .padding(.top, 14)
            .padding(.horizontal, 18)
            .padding(.bottom, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
