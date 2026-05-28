import XCTest
import SwiftData
@testable import Folio

@MainActor
final class PortfolioMetricsTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext { container.mainContext }

    override func setUp() async throws {
        container = try ModelContainer.folio(inMemory: true)
    }

    override func tearDown() async throws {
        container = nil
    }

    // Build a tiny portfolio of three holdings: AAPL (stock), BTC (crypto),
    // and VTI (etf). Cost basis and market value are picked so the math is
    // hand-checkable.
    private func sampleHoldings() throws -> [Holding] {
        let aapl = try XCTUnwrap(try context.fetch(FetchDescriptor<Asset>()).first { $0.symbol == "AAPL" })
        let btc  = try XCTUnwrap(try context.fetch(FetchDescriptor<Asset>()).first { $0.symbol == "BTC" })
        let vti  = try XCTUnwrap(try context.fetch(FetchDescriptor<Asset>()).first { $0.symbol == "VTI" })

        func h(_ asset: Asset, qty: Decimal, avg: Decimal, mv: Decimal?) -> Holding {
            Holding(
                id: Holding.ID(assetID: asset.persistentModelID, accountID: nil),
                asset: asset,
                account: nil,
                qty: qty,
                avgCost: Money(amount: avg, currency: "USD"),
                marketValue: mv.map { Money(amount: $0, currency: "USD") },
                unrealizedPnL: nil,
                unrealizedPnLPct: nil
            )
        }

        return [
            h(aapl, qty: 10, avg: 100, mv: 1500),  // basis 1000, mv 1500
            h(btc,  qty:  1, avg: 50000, mv: 60000), // basis 50000, mv 60000
            h(vti,  qty:  5, avg: 200, mv: 1000),    // basis 1000, mv 1000
        ]
    }

    func testTotalValueSumsMarketValues() throws {
        let total = PortfolioMetrics.totalValue(try sampleHoldings(), baseCurrency: "USD")
        XCTAssertEqual(total.amount, Decimal(string: "62500"))
        XCTAssertEqual(total.currency, "USD")
    }

    func testTotalValueIgnoresHoldingsWithoutPrice() throws {
        var holdings = try sampleHoldings()
        // Drop VTI's market value
        let aapl = holdings[0]
        let btc  = holdings[1]
        let vtiNoPrice = Holding(
            id: holdings[2].id,
            asset: holdings[2].asset,
            account: nil,
            qty: 5,
            avgCost: Money(amount: 200, currency: "USD"),
            marketValue: nil,
            unrealizedPnL: nil,
            unrealizedPnLPct: nil
        )
        holdings = [aapl, btc, vtiNoPrice]
        let total = PortfolioMetrics.totalValue(holdings, baseCurrency: "USD")
        // 1500 + 60000 + 0 (no price)
        XCTAssertEqual(total.amount, Decimal(string: "61500"))
    }

    func testInvestedCapitalSumsCostBasis() throws {
        let invested = PortfolioMetrics.investedCapital(try sampleHoldings(), baseCurrency: "USD")
        // 10*100 + 1*50000 + 5*200 = 1000 + 50000 + 1000 = 52000
        XCTAssertEqual(invested.amount, Decimal(string: "52000"))
    }

    func testGainAllTimeIsTotalMinusInvested() throws {
        let gain = PortfolioMetrics.gainAllTime(try sampleHoldings(), baseCurrency: "USD")
        // 62500 - 52000 = 10500
        XCTAssertEqual(gain.amount, Decimal(string: "10500"))
    }

    func testAllocationByKindSumsToHundred() throws {
        let alloc = PortfolioMetrics.allocationByKind(try sampleHoldings())
        // Expect three kinds present.
        XCTAssertNotNil(alloc[.stock])
        XCTAssertNotNil(alloc[.crypto])
        XCTAssertNotNil(alloc[.etf])

        let sum = alloc.values.reduce(Decimal(0), +)
        let sumDouble = (sum as NSDecimalNumber).doubleValue
        XCTAssertEqual(sumDouble, 100.0, accuracy: 0.0001)

        // Crypto dominates: 60000 / 62500 = 96%
        let cryptoPct = ((alloc[.crypto] ?? 0) as NSDecimalNumber).doubleValue
        XCTAssertEqual(cryptoPct, 96.0, accuracy: 0.01)
    }

    func testAllocationByKindReturnsEmptyWhenNoMarketValue() throws {
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
        let alloc = PortfolioMetrics.allocationByKind([holding])
        XCTAssertTrue(alloc.isEmpty)
    }

    func testGainCanBeNegative() throws {
        let aapl = try XCTUnwrap(try context.fetch(FetchDescriptor<Asset>()).first { $0.symbol == "AAPL" })
        let loss = Holding(
            id: Holding.ID(assetID: aapl.persistentModelID, accountID: nil),
            asset: aapl,
            account: nil,
            qty: 10,
            avgCost: Money(amount: 200, currency: "USD"),
            marketValue: Money(amount: 1500, currency: "USD"),
            unrealizedPnL: nil,
            unrealizedPnLPct: nil
        )
        let gain = PortfolioMetrics.gainAllTime([loss], baseCurrency: "USD")
        XCTAssertEqual(gain.amount, Decimal(string: "-500"))
    }

    func testTotalValueAllNilPricesYieldsZero() throws {
        let aapl = try XCTUnwrap(try context.fetch(FetchDescriptor<Asset>()).first { $0.symbol == "AAPL" })
        let btc  = try XCTUnwrap(try context.fetch(FetchDescriptor<Asset>()).first { $0.symbol == "BTC" })
        func unpriced(_ asset: Asset) -> Holding {
            Holding(
                id: Holding.ID(assetID: asset.persistentModelID, accountID: nil),
                asset: asset,
                account: nil,
                qty: 10,
                avgCost: Money(amount: 100, currency: "USD"),
                marketValue: nil,
                unrealizedPnL: nil,
                unrealizedPnLPct: nil
            )
        }
        let total = PortfolioMetrics.totalValue([unpriced(aapl), unpriced(btc)], baseCurrency: "USD")
        XCTAssertEqual(total, Money.zero("USD"))
    }

    // MARK: - YTD performance

    private static func utcCalendar() -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC") ?? .current
        return cal
    }

    func testYTDPerformanceEmptyHistoryReturnsNil() {
        XCTAssertNil(PortfolioMetrics.ytdPerformance(history: [], now: Date()))
    }

    func testYTDPerformanceAllPointsBeforeJan1ReturnsNil() throws {
        let cal = Self.utcCalendar()
        let now = try XCTUnwrap(cal.date(from: DateComponents(year: 2026, month: 6, day: 15)))
        let dec30 = try XCTUnwrap(cal.date(from: DateComponents(year: 2025, month: 12, day: 30)))
        let history = [HistoryPoint(date: dec30, total: Money.usd(10_000))]
        XCTAssertNil(PortfolioMetrics.ytdPerformance(history: history, now: now))
    }

    func testYTDPerformanceWithJan1ComputesPctChange() throws {
        let cal = Self.utcCalendar()
        let now = try XCTUnwrap(cal.date(from: DateComponents(year: 2026, month: 6, day: 15)))
        let jan1 = try XCTUnwrap(cal.date(from: DateComponents(year: 2026, month: 1, day: 1)))
        let jun15 = try XCTUnwrap(cal.date(from: DateComponents(year: 2026, month: 6, day: 15)))
        let history = [
            HistoryPoint(date: jan1,  total: Money.usd(10_000)),
            HistoryPoint(date: jun15, total: Money.usd(11_000)),
        ]
        let pct = try XCTUnwrap(PortfolioMetrics.ytdPerformance(history: history, now: now))
        // (11000 - 10000) / 10000 * 100 = 10%
        XCTAssertEqual(pct, 10.0, accuracy: 0.0001)
    }

    func testYTDPerformanceJan1ValueZeroReturnsNil() throws {
        let cal = Self.utcCalendar()
        let now = try XCTUnwrap(cal.date(from: DateComponents(year: 2026, month: 6, day: 15)))
        let jan1 = try XCTUnwrap(cal.date(from: DateComponents(year: 2026, month: 1, day: 1)))
        let jun15 = try XCTUnwrap(cal.date(from: DateComponents(year: 2026, month: 6, day: 15)))
        let history = [
            HistoryPoint(date: jan1,  total: Money.usd(0)),
            HistoryPoint(date: jun15, total: Money.usd(5_000)),
        ]
        XCTAssertNil(PortfolioMetrics.ytdPerformance(history: history, now: now))
    }
}
