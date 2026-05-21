import XCTest
import SwiftData
@testable import Folio

@MainActor
final class StocksRowsBuilderTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext { container.mainContext }

    override func setUp() async throws {
        container = try ModelContainer.folio(inMemory: true)
    }

    override func tearDown() async throws {
        container = nil
    }

    // MARK: - Helpers

    private func priceFromSeed(_ asset: Asset) -> Decimal? {
        asset.quotes.first?.amount
    }

    private func usdOnly(_ from: String, _ to: String, _ date: Date) -> Decimal? {
        (from == to) ? 1 : nil
    }

    private func allHoldings() throws -> [Holding] {
        let txns = try context.fetch(FetchDescriptor<PortfolioTransaction>())
        return HoldingsReducer.reduceByAsset(
            transactions: txns,
            priceFor: priceFromSeed,
            fxAt: usdOnly,
            baseCurrency: "USD"
        )
    }

    // MARK: - Filter

    func testFilterAndSortDropsCryptoRows() throws {
        let rows = StocksRowsBuilder.filterAndSort(try allHoldings(), sort: .default)
        XCTAssertTrue(rows.allSatisfy { $0.asset.kind == .stock || $0.asset.kind == .etf })
        // The seed has 10 stock/ETF rows.
        XCTAssertEqual(rows.count, 10)
    }

    func testStockAccountNamesAreDistinctAndAlphabetical() throws {
        let txns = try context.fetch(FetchDescriptor<PortfolioTransaction>())
        let names = StocksRowsBuilder.stockAccountNames(from: txns)
        XCTAssertEqual(names, ["Fidelity", "Robinhood", "Schwab", "Vanguard"])
    }

    // MARK: - Sort

    func testSortByMarketValueDescending() throws {
        let rows = StocksRowsBuilder.filterAndSort(
            try allHoldings(),
            sort: StocksSort(column: .marketValue, ascending: false)
        )
        // COST: 42 × 924.10 = 38812.20 (highest), but actually MSFT 160 × 432.18 = 69148.80
        // Largest seeded holding by MV is MSFT (post-mock-buy = 160 shares).
        XCTAssertEqual(rows.first?.asset.symbol, "MSFT")
    }

    func testSortByTickerAscending() throws {
        let rows = StocksRowsBuilder.filterAndSort(
            try allHoldings(),
            sort: StocksSort(column: .ticker, ascending: true)
        )
        let symbols = rows.map { $0.asset.symbol }
        XCTAssertEqual(symbols, symbols.sorted())
        XCTAssertEqual(symbols.first, "AAPL")
    }

    func testSortByPnLPctDescendingPutsBiggestWinnerFirst() throws {
        let rows = StocksRowsBuilder.filterAndSort(
            try allHoldings(),
            sort: StocksSort(column: .pnlPct, ascending: false)
        )
        // Every row should have a non-nil pnlPct given seed prices, and the
        // first row's pct must be ≥ every subsequent row's.
        guard let firstPct = rows.first?.unrealizedPnLPct else {
            return XCTFail("expected pct on first row")
        }
        for row in rows.dropFirst() {
            if let p = row.unrealizedPnLPct {
                XCTAssertLessThanOrEqual(p, firstPct)
            }
        }
    }

    func testTotalMarketValueSumsOnlyStocksAndETFs() throws {
        let holdings = try allHoldings()
        let total = StocksRowsBuilder.totalMarketValue(holdings)
        let manual = holdings
            .filter { $0.asset.kind == .stock || $0.asset.kind == .etf }
            .compactMap { $0.marketValue?.amount }
            .reduce(Decimal(0), +)
        XCTAssertEqual(total, manual)
        XCTAssertGreaterThan(total, 0)
    }
}
