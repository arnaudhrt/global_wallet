import SwiftUI

/// Root window content for Folio. Owns the `NavigationSplitView`, drives the
/// detail slot off `router.selection`, and mounts the Add-Transaction stub sheet.
struct MacShell: View {
    @Environment(\.theme) private var theme
    @Environment(AppRouter.self) private var router
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        @Bindable var router = router

        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(selection: $router.selection)
        } detail: {
            detailView(for: router.selection)
                .navigationTitle(router.selection.title)
                .navigationSubtitle(router.selection.subtitle)
                .toolbar { toolbarContent }
                .toolbarBackground(.hidden, for: .windowToolbar)
                .sheet(isPresented: $router.showAddSheet) {
                    AddTransactionStubSheet()
                }
        }
    }

    @ViewBuilder
    private func detailView(for destination: Destination) -> some View {
        switch destination {
        case .stocks:
            StocksScreen()
        default:
            PlaceholderScreen(destination: destination)
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        // Each control gets its own ToolbarItem so styling doesn't bleed
        // across siblings — macOS groups sibling controls inside one ToolbarItem.
        ToolbarItem(placement: .secondaryAction) {
            ToolbarSearchStub()
        }
        ToolbarItem(placement: .primaryAction) {
    Button {
        router.showAddSheet = true
    } label: {
        Image(systemName: "plus")
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(theme.text2)
            .frame(width: 34, height: 28)
            .contentShape(Circle())
    }
    .buttonStyle(.plain)
    .keyboardShortcut("n", modifiers: .command)
    .help("Add holding (⌘N)")
}
    }
}
