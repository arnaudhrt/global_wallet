import XCTest
import SwiftData
@testable import Folio

@MainActor
final class CryptoRowsBuilderTests: XCTestCase {
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

    private func aggregateHoldings() throws -> [Holding] {
        let txns = try context.fetch(FetchDescriptor<PortfolioTransaction>())
        return HoldingsReducer.reduceByAsset(
            transactions: txns,
            priceFor: priceFromSeed,
            fxAt: usdOnly,
            baseCurrency: "USD"
        )
    }

    private func perWalletHoldings() throws -> [Holding] {
        let txns = try context.fetch(FetchDescriptor<PortfolioTransaction>())
        return HoldingsReducer.reduceByAssetAndAccount(
            transactions: txns,
            priceFor: priceFromSeed,
            fxAt: usdOnly,
            baseCurrency: "USD"
        )
    }

    // MARK: - Filter

    func testFilterAndSortDropsNonCryptoRows() throws {
        let rows = CryptoRowsBuilder.filterAndSort(try aggregateHoldings(), sort: .default)
        XCTAssertTrue(rows.allSatisfy { $0.asset.kind == .crypto })
        // Seed has 6 crypto symbols.
        XCTAssertEqual(rows.count, 6)
    }

    func testWalletAccountNamesAreCryptoOnlyAndAlphabetical() throws {
        let txns = try context.fetch(FetchDescriptor<PortfolioTransaction>())
        let names = CryptoRowsBuilder.walletAccountNames(from: txns)
        // Seeded crypto txns span: Binance, Coinbase, Ledger, MetaMask, Phantom.
        XCTAssertEqual(names, ["Binance", "Coinbase", "Ledger", "MetaMask", "Phantom"])
        XCTAssertFalse(names.contains("Schwab"))
        XCTAssertFalse(names.contains("Fidelity"))
    }

    // MARK: - Sort

    func testSortByMarketValueDescendingPutsBTCFirst() throws {
        let rows = CryptoRowsBuilder.filterAndSort(
            try aggregateHoldings(),
            sort: CryptoSort(column: .marketValue, ascending: false)
        )
        // BTC (~1.075 BTC × 92480) dominates the seeded crypto book.
        XCTAssertEqual(rows.first?.asset.symbol, "BTC")
    }

    func testSortByTickerAscending() throws {
        let rows = CryptoRowsBuilder.filterAndSort(
            try aggregateHoldings(),
            sort: CryptoSort(column: .ticker, ascending: true)
        )
        let symbols = rows.map { $0.asset.symbol }
        XCTAssertEqual(symbols, symbols.sorted())
        XCTAssertEqual(symbols.first, "BTC")
    }

    // MARK: - Sub-rows

    func testSubRowsForBTCMatchSeededWallets() throws {
        let subs = CryptoRowsBuilder.subRows(for: "BTC", from: try perWalletHoldings())
        let wallets = Set(subs.compactMap { $0.account?.name })
        XCTAssertEqual(wallets, ["Binance", "Ledger", "Coinbase"])
    }

    func testSubRowsAreSortedByMarketValueDescending() throws {
        let subs = CryptoRowsBuilder.subRows(for: "BTC", from: try perWalletHoldings())
        let mvs = subs.compactMap { $0.marketValue?.amount }
        XCTAssertEqual(mvs, mvs.sorted(by: >))
    }

    func testSubRowsForUnknownSymbolReturnEmpty() throws {
        let subs = CryptoRowsBuilder.subRows(for: "DOGE", from: try perWalletHoldings())
        XCTAssertTrue(subs.isEmpty)
    }

    // MARK: - Staking YTD

    func testStakingYTDIncludesOnlyCurrentYearStakeTxns() throws {
        // The seed includes one .stake txn (ETH, 2026-04-02, amount $1605).
        // Test under the assumption "now" sits in the same calendar year.
        let txns = try context.fetch(FetchDescriptor<PortfolioTransaction>())
        let now = makeDate(year: 2026, month: 6, day: 1)
        let total = CryptoRowsBuilder.stakingYTD(from: txns, now: now)
        XCTAssertEqual(total, Decimal(string: "1605.00"))
    }

    func testStakingYTDExcludesPriorYears() throws {
        let txns = try context.fetch(FetchDescriptor<PortfolioTransaction>())
        let now = makeDate(year: 2030, month: 1, day: 1)
        let total = CryptoRowsBuilder.stakingYTD(from: txns, now: now)
        XCTAssertEqual(total, 0)
    }

    func testStakingYTDIgnoresNonStakeTypes() throws {
        // Replace stake with a buy on the same date — staking should drop to 0.
        let txns = try context.fetch(FetchDescriptor<PortfolioTransaction>())
        for txn in txns where txn.type == .stake { txn.type = .buy }
        try context.save()
        let now = makeDate(year: 2026, month: 6, day: 1)
        let total = CryptoRowsBuilder.stakingYTD(from: try context.fetch(FetchDescriptor<PortfolioTransaction>()), now: now)
        XCTAssertEqual(total, 0)
    }

    // MARK: - Utilities

    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        var c = DateComponents()
        c.year = year; c.month = month; c.day = day
        c.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: c)!
    }
}
