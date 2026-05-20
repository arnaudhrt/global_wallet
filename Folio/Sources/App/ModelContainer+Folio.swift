import Foundation
import SwiftData

extension ModelContainer {
    /// Builds a `ModelContainer` for Folio's schema. Ensures the `AppSettings`
    /// singleton row exists and runs the seed loader on an empty DB. Pass
    /// `inMemory: true` from tests for an isolated container.
    @MainActor
    static func folio(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema([
            Account.self,
            Asset.self,
            PortfolioTransaction.self,
            PriceQuote.self,
            FXRate.self,
            AppSettings.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        let container = try ModelContainer(for: schema, configurations: [config])

        let context = ModelContext(container)
        try ensureAppSettings(context)
        try SeedDataLoader.seedIfEmpty(context)

        return container
    }

    private static func ensureAppSettings(_ context: ModelContext) throws {
        let existing = try context.fetch(FetchDescriptor<AppSettings>())
        if existing.isEmpty {
            context.insert(AppSettings(baseCurrency: "USD"))
            try context.save()
        }
    }
}
