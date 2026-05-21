import XCTest
import SwiftData
@testable import Folio

@MainActor
final class QuoteRefreshCoordinatorTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext { container.mainContext }

    override func setUp() async throws {
        container = try ModelContainer.folio(inMemory: true)
    }

    override func tearDown() async throws {
        container = nil
    }

    private func makeCoordinator() -> QuoteRefreshCoordinator {
        let mock = MockQuoteProvider(seedBase: 11)
        return QuoteRefreshCoordinator(
            container: container,
            stocks: mock,
            crypto: mock,
            fx: mock
        )
    }

    func testInitialStatusIsIdle() {
        let coord = makeCoordinator()
        XCTAssertEqual(coord.status, .idle)
    }

    func testRefreshAllInsertsPriceQuotesAndSetsOk() async throws {
        let coord = makeCoordinator()
        let before = try context.fetchCount(FetchDescriptor<PriceQuote>())
        let assetCount = try context.fetchCount(FetchDescriptor<Asset>())
        XCTAssertGreaterThan(assetCount, 0, "seed should have populated assets")

        await coord.refreshAll()

        let after = try context.fetchCount(FetchDescriptor<PriceQuote>())
        XCTAssertEqual(after - before, assetCount, "one new PriceQuote per asset")

        if case .ok(let at) = coord.status {
            XCTAssertLessThan(Date().timeIntervalSince(at), 5)
        } else {
            XCTFail("Expected .ok, got \(coord.status)")
        }
    }

    func testRefreshAllUpdatesLastQuoteRefresh() async throws {
        let coord = makeCoordinator()
        let settings = try XCTUnwrap(context.fetch(FetchDescriptor<AppSettings>()).first)
        XCTAssertNil(settings.lastQuoteRefresh)

        await coord.refreshAll()

        // SwiftData should have the same row reflected back via the mainContext.
        let refreshed = try XCTUnwrap(context.fetch(FetchDescriptor<AppSettings>()).first)
        XCTAssertNotNil(refreshed.lastQuoteRefresh)
    }

    func testRefreshAllSucceedsTwiceAndDedupes() async throws {
        let coord = makeCoordinator()
        await coord.refreshAll()
        let mid = try context.fetchCount(FetchDescriptor<PriceQuote>())
        await coord.refreshAll()
        let final = try context.fetchCount(FetchDescriptor<PriceQuote>())
        // Second refresh lands within 60s of the first → updates the same
        // (asset, source) rows in place instead of appending. Verifies the
        // per-minute dedupe is in effect.
        XCTAssertEqual(final, mid, "second refresh updates existing rows in place")
        if case .ok = coord.status { /* ok */ } else { XCTFail("expected .ok") }
    }

    func testPartialSuccessYieldsOk() async throws {
        // Stocks provider fails for everything; crypto provider succeeds.
        // Expectation: at least one PriceQuote landed → status .ok.
        let coord = QuoteRefreshCoordinator(
            container: container,
            stocks: AlwaysFailingProvider(),
            crypto: MockQuoteProvider(seedBase: 3),
            fx: MockQuoteProvider(seedBase: 3)
        )
        await coord.refreshAll()
        if case .ok = coord.status { /* ok */ } else { XCTFail("expected .ok, got \(coord.status)") }

        let cryptoQuotes = try context.fetch(FetchDescriptor<PriceQuote>())
            .filter { $0.source == "coingecko" }
        XCTAssertGreaterThan(cryptoQuotes.count, 0, "crypto provider should have written rows")
    }

    func testTotalFailureYieldsFailed() async throws {
        let coord = QuoteRefreshCoordinator(
            container: container,
            stocks: AlwaysFailingProvider(),
            crypto: AlwaysFailingProvider(),
            fx: AlwaysFailingFXProvider()
        )
        await coord.refreshAll()
        if case .failed = coord.status { /* ok */ } else { XCTFail("expected .failed, got \(coord.status)") }
    }

    func testNewestPriceQuoteWinsForReducer() async throws {
        let coord = makeCoordinator()

        // Seed-based total (every asset priced at its $92k BTC / $214 AAPL / etc.)
        let txnsBefore = try context.fetch(FetchDescriptor<PortfolioTransaction>())
        let seedTotal = PortfolioMetrics.totalValue(
            HoldingsReducer.reduceByAsset(
                transactions: txnsBefore,
                priceFor: { $0.quotes.sorted(by: { $0.asOf > $1.asOf }).first?.amount },
                fxAt: { from, to, _ in from == to ? 1 : nil },
                baseCurrency: "USD"
            ),
            baseCurrency: "USD"
        ).amount

        await coord.refreshAll()

        let txnsAfter = try context.fetch(FetchDescriptor<PortfolioTransaction>())
        let liveTotal = PortfolioMetrics.totalValue(
            HoldingsReducer.reduceByAsset(
                transactions: txnsAfter,
                priceFor: { $0.quotes.sorted(by: { $0.asOf > $1.asOf }).first?.amount },
                fxAt: { from, to, _ in from == to ? 1 : nil },
                baseCurrency: "USD"
            ),
            baseCurrency: "USD"
        ).amount

        // The mock random walk hovers near $100/unit (vs. seed prices like
        // $92k for BTC), so the live total must differ from the seed total
        // by far more than rounding noise — proving the reducer is reading
        // the freshly-inserted PriceQuote rows.
        XCTAssertGreaterThan(liveTotal, 0)
        XCTAssertNotEqual(liveTotal, seedTotal)
        let delta = ((liveTotal - seedTotal) as NSDecimalNumber).doubleValue
        XCTAssertGreaterThan(abs(delta), 1000)
    }
}

private struct AlwaysFailingProvider: QuoteProvider {
    func quote(symbol: String) async throws -> QuoteResult {
        throw QuoteProviderError.network("stub failure")
    }
    func historical(symbol: String, range: QuoteRange) async throws -> [HistoricalPoint] {
        throw QuoteProviderError.notImplemented
    }
    func search(query: String) async throws -> [SymbolMatch] {
        throw QuoteProviderError.notImplemented
    }
}

private struct AlwaysFailingFXProvider: FXProvider {
    func rate(from: String, to: String) async throws -> FXResult {
        throw FXProviderError.network("stub failure")
    }
}
