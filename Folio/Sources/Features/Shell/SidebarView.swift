import SwiftUI

/// Fully custom (non-`List`) sidebar matching `project/shell.jsx`. Uses
/// `ScrollView` + `VStack` so we get pixel-accurate control over row chrome and
/// avoid the system sidebar material that fights the spec's flat `sidebarBg`.
struct SidebarView: View {
    @Environment(\.theme) private var theme
    @Binding var selection: Destination
    @State private var hoveredID: Destination?

    var body: some View {
        VStack(spacing: 0) {
            brandRow

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(SidebarGroup.allCases.enumerated()), id: \.offset) { _, group in
                        if let header = group.header {
                            SidebarGroupHeader(title: header)
                        } else {
                            Spacer().frame(height: 6)
                        }
                        ForEach(group.destinations) { dest in
                            SidebarItem(
                                destination: dest,
                                isActive: selection == dest,
                                isHovered: hoveredID == dest
                            ) {
                                selection = dest
                            }
                            .onHover { hovering in
                                guard dest.isAvailable else { return }
                                hoveredID = hovering ? dest : (hoveredID == dest ? nil : hoveredID)
                            }
                        }
                    }
                    Spacer(minLength: 12)
                }
            }
            .scrollContentBackground(.hidden)

            SidebarFooter()
        }
        .frame(maxHeight: .infinity)
        .background(theme.sidebarBg)
        .navigationSplitViewColumnWidth(min: 220, ideal: 220, max: 260)
    }

    /// Brand-mark row aligned with the native titlebar so traffic lights overlay
    /// cleanly onto `sidebarBg`.
    private var brandRow: some View {
        HStack(spacing: 7) {
            Spacer().frame(width: 60) // leave room for the traffic lights
            ZStack {
                RoundedRectangle(cornerRadius: 3)
                    .fill(theme.text)
                Circle()
                    .fill(theme.green)
                    .frame(width: 6, height: 6)
            }
            .frame(width: 16, height: 16)
            Text("Folio")
                .font(.system(size: 13, weight: .semibold))
                .tracking(-0.2)
                .foregroundStyle(theme.text)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
        .overlay(alignment: .bottom) {
            Rectangle().fill(theme.border).frame(height: 1)
        }
    }
}
