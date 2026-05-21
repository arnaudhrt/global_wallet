import SwiftUI

/// Sidebar footer: refresh status indicator only.
struct SidebarFooter: View {
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 0) {
            ToolbarRefreshStatus()
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(theme.border)
                .frame(height: 1)
        }
    }
}
