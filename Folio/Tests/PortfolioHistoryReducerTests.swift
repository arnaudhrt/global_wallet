import XCTest
import SwiftData
@testable import Folio

@MainActor
final class PortfolioHistoryReducerTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext { container.mainContext }

    override func setUp() async throws {
        container = try ModelContainer.folio(inMemory: true)
    }

    override func tearDown() async throws {
        container = nil
    }

    private func usdOnly(_ from: String, _ to: String, _ date: Date) -> Decimal? {
        (from == to) ? 1 : nil
    }

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC") ?? .current
        return cal
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? Date()
    }

    private func freshContainer() throws -> ModelContainer {
        let c = try ModelContainer.folio(inMemory: true)
        let ctx = c.mainContext
        // Wipe seed txns; tests construct their own ledger.
        let existing = try ctx.fetch(FetchDescriptor<PortfolioTransaction>())
        for t in existing { ctx.delete(t) }
        try ctx.save()
        return c
    }

    func testSingleBuyProducesMonotonicSeriesWithConstantPrice() throws {
        let c = try freshContainer()
        let ctx = c.mainContext
        let aapl = try XCTUnwrap(try ctx.fetch(FetchDescriptor<Asset>()).first { $0.symbol == "AAPL" })
        let account = try XCTUnwrap(try ctx.fetch(FetchDescriptor<Account>()).first { $0.name == "Schwab" })
        ctx.insert(PortfolioTransaction(
            date: date(2026, 1, 1), type: .buy, asset: aapl, account: account,
            quantity: 10, price: 100, amount: 1000, currency: "USD"
        ))
        try ctx.save()

        let dates = [date(2026, 2, 1), date(2026, 3, 1), date(2026, 4, 1)]
        let series = PortfolioHistoryReducer.series(
            transactions: try ctx.fetch(FetchDescriptor<PortfolioTransaction>()),
            dates: dates,
            priceOn: { _, _ in 100 },
            fxAt: usdOnly,
            baseCurrency: "USD"
        )
        XCTAssertEqual(series.count, 3)
        for p in series {
            XCTAssertEqual(p.total.amount, Decimal(1000))
            XCTAssertEqual(p.total.currency, "USD")
        }
    }

    func testSeriesIsZeroBeforeBuyDate() throws {
        let c = try freshContainer()
        let ctx = c.mainContext
        let aapl = try XCTUnwrap(try ctx.fetch(FetchDescriptor<Asset>()).first { $0.symbol == "AAPL" })
        let account = try XCTUnwrap(try ctx.fetch(FetchDescriptor<Account>()).first { $0.name == "Schwab" })
        ctx.insert(PortfolioTransaction(
            date: date(2026, 3, 15), type: .buy, asset: aapl, account: account,
            quantity: 5, price: 200, amount: 1000, currency: "USD"
        ))
        try ctx.save()

        let dates = [date(2026, 1, 1), date(2026, 3, 1), date(2026, 4, 1)]
        let series = PortfolioHistoryReducer.series(
            transactions: try ctx.fetch(FetchDescriptor<PortfolioTransaction>()),
            dates: dates,
            priceOn: { _, _ in 200 },
            fxAt: usdOnly,
            baseCurrency: "USD"
        )
        XCTAssertEqual(series[0].total.amount, 0, "before buy → 0")
        XCTAssertEqual(series[1].total.amount, 0, "still before buy → 0")
        XCTAssertEqual(series[2].total.amount, Decimal(1000), "after buy → qty * price")
    }

    func testSellMidRangeDropsSubsequentValues() throws {
        let c = try freshContainer()
        let ctx = c.mainContext
        let aapl = try XCTUnwrap(try ctx.fetch(FetchDescriptor<Asset>()).first { $0.symbol == "AAPL" })
        let account = try XCTUnwrap(try ctx.fetch(FetchDescriptor<Account>()).first { $0.name == "Schwab" })
        ctx.insert(PortfolioTransaction(
            date: date(2026, 1, 1), type: .buy, asset: aapl, account: account,
            quantity: 10, price: 100, amount: 1000, currency: "USD"
        ))
        ctx.insert(PortfolioTransaction(
            date: date(2026, 3, 15), type: .sell, asset: aapl, account: account,
            quantity: 4, price: 100, amount: 400, currency: "USD"
        ))
        try ctx.save()

        let dates = [date(2026, 2, 1), date(2026, 4, 1)]
        let series = PortfolioHistoryReducer.series(
            transactions: try ctx.fetch(FetchDescriptor<PortfolioTransaction>()),
            dates: dates,
            priceOn: { _, _ in 100 },
            fxAt: usdOnly,
            baseCurrency: "USD"
        )
        XCTAssertEqual(series[0].total.amount, Decimal(1000), "pre-sell: 10 * 100")
        XCTAssertEqual(series[1].total.amount, Decimal(600), "post-sell: 6 * 100")
    }

    func testFXAppliedAtTargetDateNotTxnDate() throws {
        // Buy in EUR on day A; chart series asks for value on day B with a
        // different FX rate. The historical reducer must use the rate at the
        // target date — that's the whole point of the chart.
        let c = try freshContainer()
        let ctx = c.mainContext
        let aapl = try XCTUnwrap(try ctx.fetch(FetchDescriptor<Asset>()).first { $0.symbol == "AAPL" })
        let account = try XCTUnwrap(try ctx.fetch(FetchDescriptor<Account>()).first { $0.name == "Schwab" })
        aapl.currency = "EUR"
        ctx.insert(PortfolioTransaction(
            date: date(2026, 1, 1), type: .buy, asset: aapl, account: account,
            quantity: 10, price: 100, amount: 1000, currency: "EUR"
        ))
        try ctx.save()

        let target = date(2026, 4, 1)
        let series = PortfolioHistoryReducer.series(
            transactions: try ctx.fetch(FetchDescriptor<PortfolioTransaction>()),
            dates: [target],
            priceOn: { _, _ in 110 },              // EUR price on target date
            fxAt: { from, to, _ in
                if from == to { return 1 }
                if from == "EUR", to == "USD" { return Decimal(string: "1.2") }
                return nil
            },
            baseCurrency: "USD"
        )
        // qty (10) * price (110 EUR) * fx (1.2 EUR→USD) = 1320 USD
        XCTAssertEqual(series.first?.total.amount, Decimal(1320))
        XCTAssertEqual(series.first?.total.currency, "USD")
    }

    func testMissingPriceForOneAssetDoesNotZeroOthers() throws {
        let c = try freshContainer()
        let ctx = c.mainContext
        let aapl = try XCTUnwrap(try ctx.fetch(FetchDescriptor<Asset>()).first { $0.symbol == "AAPL" })
        let nvda = try XCTUnwrap(try ctx.fetch(FetchDescriptor<Asset>()).first { $0.symbol == "NVDA" })
        let account = try XCTUnwrap(try ctx.fetch(FetchDescriptor<Account>()).first { $0.name == "Schwab" })
        ctx.insert(PortfolioTransaction(
            date: date(2026, 1, 1), type: .buy, asset: aapl, account: account,
            quantity: 10, price: 100, amount: 1000, currency: "USD"
        ))
        ctx.insert(PortfolioTransaction(
            date: date(2026, 1, 1), type: .buy, asset: nvda, account: account,
            quantity: 5, price: 200, amount: 1000, currency: "USD"
        ))
        try ctx.save()

        let series = PortfolioHistoryReducer.series(
            transactions: try ctx.fetch(FetchDescriptor<PortfolioTransaction>()),
            dates: [date(2026, 2, 1)],
            priceOn: { asset, _ in
                asset.symbol == "AAPL" ? Decimal(100) : nil   // NVDA missing
            },
            fxAt: usdOnly,
            baseCurrency: "USD"
        )
        // AAPL 10 * 100 = 1000; NVDA skipped → total stays 1000.
        XCTAssertEqual(series.first?.total.amount, Decimal(1000))
    }

    func testOverSellClampsToZero() throws {
        let c = try freshContainer()
        let ctx = c.mainContext
        let aapl = try XCTUnwrap(try ctx.fetch(FetchDescriptor<Asset>()).first { $0.symbol == "AAPL" })
        let account = try XCTUnwrap(try ctx.fetch(FetchDescriptor<Account>()).first { $0.name == "Schwab" })
        ctx.insert(PortfolioTransaction(
            date: date(2026, 1, 1), type: .buy, asset: aapl, account: account,
            quantity: 5, price: 100, amount: 500, currency: "USD"
        ))
        ctx.insert(PortfolioTransaction(
            date: date(2026, 2, 1), type: .sell, asset: aapl, account: account,
            quantity: 10, price: 100, amount: 1000, currency: "USD"
        ))
        try ctx.save()

        let series = PortfolioHistoryReducer.series(
            transactions: try ctx.fetch(FetchDescriptor<PortfolioTransaction>()),
            dates: [date(2026, 3, 1)],
            priceOn: { _, _ in 100 },
            fxAt: usdOnly,
            baseCurrency: "USD"
        )
        XCTAssertEqual(series.first?.total.amount, Decimal(0), "over-sell clamps qty to 0")
    }

    func testNetFlowAttributedToTheSubPeriodOfTheTransaction() throws {
        // A buy lands in each sub-period; netFlow on a point must be the sum of
        // external flows since the previous point (the basis for TWR).
        let c = try freshContainer()
        let ctx = c.mainContext
        let aapl = try XCTUnwrap(try ctx.fetch(FetchDescriptor<Asset>()).first { $0.symbol == "AAPL" })
        let account = try XCTUnwrap(try ctx.fetch(FetchDescriptor<Account>()).first { $0.name == "Schwab" })
        ctx.insert(PortfolioTransaction(
            date: date(2026, 1, 1), type: .buy, asset: aapl, account: account,
            quantity: 10, price: 100, amount: 1000, currency: "USD"
        ))
        ctx.insert(PortfolioTransaction(
            date: date(2026, 3, 15), type: .sell, asset: aapl, account: account,
            quantity: 4, price: 100, amount: 400, currency: "USD"
        ))
        try ctx.save()

        let dates = [date(2026, 2, 1), date(2026, 4, 1), date(2026, 5, 1)]
        let series = PortfolioHistoryReducer.series(
            transactions: try ctx.fetch(FetchDescriptor<PortfolioTransaction>()),
            dates: dates,
            priceOn: { _, _ in 100 },
            fxAt: usdOnly,
            baseCurrency: "USD"
        )
        XCTAssertEqual(series[0].netFlow.amount, Decimal(1000), "buy flow lands in first sub-period")
        XCTAssertEqual(series[1].netFlow.amount, Decimal(-400), "sell is a negative flow in its sub-period")
        XCTAssertEqual(series[2].netFlow.amount, Decimal(0), "no flows since previous point")
        XCTAssertTrue(series.allSatisfy { $0.netFlow.currency == "USD" })
    }

    func testStakeAndDividendAreNotExternalFlows() throws {
        // Staking yield is return-in-kind, dividends are cash income — neither
        // is a contribution, so neither shows up as netFlow.
        let c = try freshContainer()
        let ctx = c.mainContext
        let eth = try XCTUnwrap(try ctx.fetch(FetchDescriptor<Asset>()).first { $0.symbol == "ETH" })
        let account = try XCTUnwrap(try ctx.fetch(FetchDescriptor<Account>()).first { $0.kind == .exchange })
        ctx.insert(PortfolioTransaction(
            date: date(2026, 1, 1), type: .buy, asset: eth, account: account,
            quantity: 1, price: 2000, amount: 2000, currency: "USD"
        ))
        ctx.insert(PortfolioTransaction(
            date: date(2026, 2, 1), type: .stake, asset: eth, account: account,
            quantity: Decimal(string: "0.1"), price: 2000, amount: 200, currency: "USD"
        ))
        try ctx.save()

        let series = PortfolioHistoryReducer.series(
            transactions: try ctx.fetch(FetchDescriptor<PortfolioTransaction>()),
            dates: [date(2026, 1, 15), date(2026, 3, 1)],
            priceOn: { _, _ in 2000 },
            fxAt: usdOnly,
            baseCurrency: "USD"
        )
        XCTAssertEqual(series[0].netFlow.amount, Decimal(2000), "the buy is a flow")
        XCTAssertEqual(series[1].netFlow.amount, Decimal(0), "stake adds qty but is not a flow")
        // ...and the staked qty does lift market value (real performance).
        XCTAssertEqual(series[1].total.amount, Decimal(2200), "1.1 ETH * 2000")
    }

    func testDailyDatesGeneratesContiguousUTCDays() {
        let start = date(2026, 1, 1)
        let end = date(2026, 1, 5)
        let dates = PortfolioHistoryReducer.dailyDates(from: start, through: end)
        XCTAssertEqual(dates.count, 5)
        XCTAssertEqual(dates.first, calendar.startOfDay(for: start))
        XCTAssertEqual(dates.last, calendar.startOfDay(for: end))
    }
}
