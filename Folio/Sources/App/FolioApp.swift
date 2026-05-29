import SwiftUI
import SwiftData

@main
struct FolioApp: App {
    @State private var router = AppRouter()
    @State private var coordinator: QuoteRefreshCoordinator
    @State private var historicalService: HistoricalQuoteService
    private let container: ModelContainer

    init() {
        do {
            let container = try ModelContainer.folio()
            self.container = container
            let yahoo = YahooQuoteProvider()
            let coinGecko = CoinGeckoQuoteProvider()
            let coordinator = QuoteRefreshCoordinator(
                container: container,
                stocks: yahoo,
                crypto: coinGecko,
                fx: yahoo
            )
            let historicalService = HistoricalQuoteService(
                container: container,
                stocks: yahoo,
                crypto: coinGecko,
                fx: yahoo
            )
            self._coordinator = State(initialValue: coordinator)
            self._historicalService = State(initialValue: historicalService)
        } catch {
            fatalError("Failed to build Folio ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            MacShell()
                .environment(router)
                .environment(coordinator)
                .environment(historicalService)
                .folioTheme()
                .frame(minWidth: 960, minHeight: 600)
                .task {
                    await coordinator.refreshAll()
                    coordinator.startTimer()
                }
        }
        .modelContainer(container)
        .defaultSize(width: 1440, height: 900)
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
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") {
                    router.showSettingsSheet = true
                }
                .keyboardShortcut(",", modifiers: .command)
            }
            CommandGroup(after: .pasteboard) {
                Button("Find Asset") {
                    router.searchFocused = true
                }
                .keyboardShortcut("k", modifiers: .command)
            }
        }
    }
}
