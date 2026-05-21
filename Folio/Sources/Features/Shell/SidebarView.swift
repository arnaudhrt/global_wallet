import SwiftUI

/// Fully custom (non-`List`) sidebar matching `project/shell.jsx`. Uses
/// `ScrollView` + `VStack` so we get pixel-accurate control over row chrome and
/// avoid the system sidebar material that fights the spec's flat `sidebarBg`.
struct SidebarView: View {
    @Environment(\.theme) private var theme
    @Binding var selection: Destination

    var body: some View {
        VStack(spacing: 0) {
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
                                isActive: selection == dest
                            ) {
                                selection = dest
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
}
