import XCTest
import SwiftData
@testable import Folio

@MainActor
final class OverviewMetricsBuilderTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext { container.mainContext }

    override func setUp() async throws {
        container = try ModelContainer.folio(inMemory: true)
    }

    override func tearDown() async throws {
        container = nil
    }

    private func priceFromSeed(_ asset: Asset) -> Decimal? {
        asset.quotes.first?.amount
    }

    private func usdOnly(_ from: String, _ to: String, _ date: Date) -> Decimal? {
        from == to ? 1 : nil
    }

    private func seededHoldings() throws -> [Holding] {
        let txns = try context.fetch(FetchDescriptor<PortfolioTransaction>())
        return HoldingsReducer.reduceByAsset(
            transactions: txns,
            priceFor: priceFromSeed,
            fxAt: usdOnly,
            baseCurrency: "USD"
        )
    }

    // MARK: - earliestTransactionDate

    func testEarliestTransactionDateIsSyntheticBuyDate() throws {
        let txns = try context.fetch(FetchDescriptor<PortfolioTransaction>())
        let earliest = OverviewMetricsBuilder.earliestTransactionDate(from: txns)
        XCTAssertEqual(earliest, SeedDataLoader.syntheticBuyDate)
    }

    func testEarliestTransactionDateNilWhenEmpty() {
        XCTAssertNil(OverviewMetricsBuilder.earliestTransactionDate(from: []))
    }

    // MARK: - positionsCount

    func testPositionsCountMatchesSeededAssets() throws {
        // 10 stocks + 6 cryptos = 16 distinct rollups (TSLA/JNJ sells reduce qty
        // but stay positive; no symbol gets zeroed).
        XCTAssertEqual(OverviewMetricsBuilder.positionsCount(try seededHoldings()), 16)
    }

    func testPositionsCountIgnoresZeroQty() throws {
        let aapl = try XCTUnwrap(try context.fetch(FetchDescriptor<Asset>()).first { $0.symbol == "AAPL" })
        let zero = Holding(
            id: Holding.ID(assetID: aapl.persistentModelID, accountID: nil),
            asset: aapl,
            account: nil,
            qty: 0,
            avgCost: Money(amount: 0, currency: "USD"),
            marketValue: nil,
            unrealizedPnL: nil,
            unrealizedPnLPct: nil
        )
        XCTAssertEqual(OverviewMetricsBuilder.positionsCount([zero]), 0)
    }

    // MARK: - accountsCount

    func testAccountsCountIsNineFromSeed() throws {
        let txns = try context.fetch(FetchDescriptor<PortfolioTransaction>())
        XCTAssertEqual(OverviewMetricsBuilder.accountsCount(from: txns), 9)
    }

    // MARK: - allocation

    func testAllocationHasStocksAndCryptoSummingToHundred() throws {
        let entries = OverviewMetricsBuilder.allocation(try seededHoldings(), baseCurrency: "USD")
        let categories = Set(entries.map(\.category))
        XCTAssertEqual(categories, [.stocks, .crypto])

        let sum = entries.map(\.pct).reduce(Decimal(0), +)
        XCTAssertEqual((sum as NSDecimalNumber).doubleValue, 100.0, accuracy: 0.0001)
    }

    func testAllocationPutsStocksFirstInOrder() throws {
        let entries = OverviewMetricsBuilder.allocation(try seededHoldings(), baseCurrency: "USD")
        XCTAssertEqual(entries.first?.category, .stocks)
    }

    func testAllocationAmountsMatchMarketValueSum() throws {
        let entries = OverviewMetricsBuilder.allocation(try seededHoldings(), baseCurrency: "USD")
        let totalFromEntries = entries.map(\.amount.amount).reduce(Decimal(0), +)
        let totalFromHoldings = try seededHoldings().compactMap { $0.marketValue?.amount }.reduce(Decimal(0), +)
        XCTAssertEqual(totalFromEntries, totalFromHoldings)
    }

    func testAllocationEmptyWhenNoMarketValue() throws {
        let aapl = try XCTUnwrap(try context.fetch(FetchDescriptor<Asset>()).first { $0.symbol == "AAPL" })
        let holding = Holding(
            id: Holding.ID(assetID: aapl.persistentModelID, accountID: nil),
            asset: aapl,
            account: nil,
            qty: 10,
            avgCost: Money(amount: 100, currency: "USD"),
            marketValue: nil,
            unrealizedPnL: nil,
            unrealizedPnLPct: nil
        )
        XCTAssertTrue(OverviewMetricsBuilder.allocation([holding], baseCurrency: "USD").isEmpty)
    }
}
