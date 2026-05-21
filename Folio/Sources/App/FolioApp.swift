import SwiftUI
import SwiftData

@main
struct FolioApp: App {
    @State private var router = AppRouter()
    @State private var coordinator: QuoteRefreshCoordinator
    private let container: ModelContainer

    init() {
        do {
            let container = try ModelContainer.folio()
            self.container = container
            let coordinator = QuoteRefreshCoordinator(
                container: container,
                stocks: YahooQuoteProvider(),
                crypto: CoinGeckoQuoteProvider(),
                fx: YahooQuoteProvider()
            )
            self._coordinator = State(initialValue: coordinator)
        } catch {
            fatalError("Failed to build Folio ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            MacShell()
                .environment(router)
                .environment(coordinator)
                .folioTheme()
                .frame(minWidth: 960, minHeight: 600)
                .task {
                    await coordinator.refreshAll()
                    coordinator.startTimer()
                }
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
            CommandGroup(after: .toolbar) {
                Button("Refresh Quotes") {
                    Task { await coordinator.refreshAll() }
                }
                .keyboardShortcut("r", modifiers: .command)
            }
        }
    }
}
