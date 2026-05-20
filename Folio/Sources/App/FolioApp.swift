import SwiftUI
import SwiftData

@main
struct FolioApp: App {
    @State private var router = AppRouter()
    private let container: ModelContainer

    init() {
        do {
            self.container = try ModelContainer.folio()
        } catch {
            fatalError("Failed to build Folio ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            MacShell()
                .environment(router)
                .folioTheme()
                .frame(minWidth: 960, minHeight: 600)
        }
        .modelContainer(container)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(after: .sidebar) {
                Divider()
                Button("Overview") { router.selection = .overview }
                    .keyboardShortcut("1", modifiers: .command)
                Button("Stocks & ETFs") { router.selection = .stocks }
                    .keyboardShortcut("2", modifiers: .command)
                Button("Crypto") { router.selection = .crypto }
                    .keyboardShortcut("3", modifiers: .command)
                Button("Transactions") { router.selection = .transactions }
                    .keyboardShortcut("4", modifiers: .command)
            }
        }
    }
}
