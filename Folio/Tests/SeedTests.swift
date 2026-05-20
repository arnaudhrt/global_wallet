import XCTest
import SwiftData
@testable import Folio

@MainActor
final class SeedTests: XCTestCase {
    func testSeedRowCounts() throws {
        let container = try ModelContainer.folio(inMemory: true)
        let ctx = container.mainContext

        let accounts = try ctx.fetch(FetchDescriptor<Account>())
        XCTAssertEqual(accounts.count, 9)

        let assets = try ctx.fetch(FetchDescriptor<Asset>())
        // 10 stocks/ETFs + 6 cryptos
        XCTAssertEqual(assets.count, 16)
        XCTAssertEqual(assets.filter { $0.kind == .stock }.count, 9)
        XCTAssertEqual(assets.filter { $0.kind == .etf }.count, 1)
        XCTAssertEqual(assets.filter { $0.kind == .crypto }.count, 6)

        let quotes = try ctx.fetch(FetchDescriptor<PriceQuote>())
        XCTAssertEqual(quotes.count, 16, "One seed quote per asset")

        let settings = try ctx.fetch(FetchDescriptor<AppSettings>())
        XCTAssertEqual(settings.count, 1, "AppSettings is a singleton")
        XCTAssertEqual(settings.first?.baseCurrency, "USD")

        let txns = try ctx.fetch(FetchDescriptor<PortfolioTransaction>())
        // 10 synthetic stock buys + 12 synthetic crypto-wallet buys + 12 mock txns
        XCTAssertEqual(txns.count, 10 + 12 + 12)
    }

    func testSeedIsIdempotent() throws {
        let container = try ModelContainer.folio(inMemory: true)
        let ctx = container.mainContext

        // Re-run the seeder explicitly; it should detect the non-empty DB and no-op.
        try SeedDataLoader.seedIfEmpty(ctx)
        let accounts = try ctx.fetch(FetchDescriptor<Account>())
        XCTAssertEqual(accounts.count, 9, "Re-running seeder must not duplicate rows")
    }
}
