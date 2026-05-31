import XCTest
@testable import Folio

/// `QuoteRange` mapping tests — the range→days math that drives every
/// provider's historical `startDate`. (Provider-specific URL builders moved to
/// `TiingoProviderTests` after the M-Tiingo swap retired Yahoo/CoinGecko.)
final class HistoricalProviderURLTests: XCTestCase {
    func testQuoteRangeDays() {
        XCTAssertEqual(QuoteRange.m1.days(), 30)
        XCTAssertEqual(QuoteRange.m3.days(), 90)
        XCTAssertEqual(QuoteRange.y1.days(), 365)
        XCTAssertEqual(QuoteRange.y5.days(), 365 * 5)
        XCTAssertEqual(QuoteRange.all.days(), 365 * 10)
    }

    func testQuoteRangeYTDDaysFromInjectedNow() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC") ?? .current
        // Pick a date deep into the year so the delta is large enough to be
        // unambiguous (avoids edge cases right at Jan 1).
        let now = cal.date(from: DateComponents(year: 2026, month: 4, day: 15)) ?? Date()
        let days = QuoteRange.ytd.days(now: now)
        // Jan 1 → Apr 15 = 31 + 28 + 31 + 14 = 104 days
        XCTAssertEqual(days, 104)
    }

    func testQuoteRangeFromPill() {
        XCTAssertEqual(QuoteRange(pill: "1M"), .m1)
        XCTAssertEqual(QuoteRange(pill: "3M"), .m3)
        XCTAssertEqual(QuoteRange(pill: "YTD"), .ytd)
        XCTAssertEqual(QuoteRange(pill: "1Y"), .y1)
        XCTAssertEqual(QuoteRange(pill: "All"), .all)
        XCTAssertNil(QuoteRange(pill: "Bogus"))
    }
}
