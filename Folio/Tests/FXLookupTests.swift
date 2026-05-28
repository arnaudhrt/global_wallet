import XCTest
import SwiftData
@testable import Folio

@MainActor
final class FXLookupTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext { container.mainContext }

    override func setUp() async throws {
        container = try ModelContainer(
            for: Account.self, Asset.self, PortfolioTransaction.self,
                 PriceQuote.self, FXRate.self, AppSettings.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    override func tearDown() async throws {
        container = nil
    }

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC") ?? .current
        return cal.date(from: DateComponents(year: y, month: m, day: d))!
    }

    private func rate(_ from: String, _ to: String, _ value: Decimal, on day: Date) -> FXRate {
        let r = FXRate(from: from, to: to, asOf: day, rate: value, source: "test")
        context.insert(r)
        return r
    }

    func testIdentityPairReturnsOne() {
        let f = FXLookup.fxAt(rates: [])
        XCTAssertEqual(f("USD", "USD", date(2026, 5, 1)), 1)
        XCTAssertEqual(f("EUR", "EUR", date(2026, 5, 1)), 1)
    }

    func testForwardFillReturnsLatestOnOrBefore() {
        _ = rate("USD", "EUR", Decimal(90) / Decimal(100), on: date(2026, 5, 1))
        _ = rate("USD", "EUR", Decimal(92) / Decimal(100), on: date(2026, 5, 10))
        _ = rate("USD", "EUR", Decimal(94) / Decimal(100), on: date(2026, 5, 20))
        let all = try! context.fetch(FetchDescriptor<FXRate>())
        let f = FXLookup.fxAt(rates: all)
        XCTAssertEqual(f("USD", "EUR", date(2026, 5, 1)), Decimal(90) / Decimal(100))
        XCTAssertEqual(f("USD", "EUR", date(2026, 5, 5)), Decimal(90) / Decimal(100))
        XCTAssertEqual(f("USD", "EUR", date(2026, 5, 15)), Decimal(92) / Decimal(100))
        XCTAssertEqual(f("USD", "EUR", date(2026, 6, 1)), Decimal(94) / Decimal(100))
    }

    func testBeforeFirstRateReturnsNil() {
        _ = rate("USD", "EUR", Decimal(90) / Decimal(100), on: date(2026, 5, 10))
        let all = try! context.fetch(FetchDescriptor<FXRate>())
        let f = FXLookup.fxAt(rates: all)
        XCTAssertNil(f("USD", "EUR", date(2026, 5, 1)))
    }

    func testMissingPairReturnsNil() {
        _ = rate("USD", "EUR", Decimal(90) / Decimal(100), on: date(2026, 5, 10))
        let all = try! context.fetch(FetchDescriptor<FXRate>())
        let f = FXLookup.fxAt(rates: all)
        XCTAssertNil(f("USD", "JPY", date(2026, 5, 10)))
        XCTAssertNil(f("GBP", "USD", date(2026, 5, 10)))
    }

    func testEmptyRatesIdentityStillWorks() {
        let f = FXLookup.fxAt(rates: [])
        XCTAssertEqual(f("BRL", "BRL", date(2026, 5, 1)), 1)
        XCTAssertNil(f("BRL", "USD", date(2026, 5, 1)))
    }
}
