import XCTest
@testable import Folio

/// URL builder + range-mapping tests for the M8.5 historical fetchers. No
/// network. Mirrors the structure of `ProviderURLTests` but specifically
/// covers the parameterized `range`/`interval` paths added in M8.5.
final class HistoricalProviderURLTests: XCTestCase {
    // MARK: - QuoteRange mapping

    func testQuoteRangeYahooMapping() {
        XCTAssertEqual(QuoteRange.m1.yahooRange, "1mo")
        XCTAssertEqual(QuoteRange.m3.yahooRange, "3mo")
        XCTAssertEqual(QuoteRange.ytd.yahooRange, "ytd")
        XCTAssertEqual(QuoteRange.y1.yahooRange, "1y")
        XCTAssertEqual(QuoteRange.all.yahooRange, "max")
    }

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

    // MARK: - Yahoo

    func testYahooChartURLAcceptsRangeAndIntervalParams() throws {
        let url = try XCTUnwrap(YahooQuoteProvider.chartURL(symbol: "AAPL", range: "1mo", interval: "1d"))
        let s = url.absoluteString
        XCTAssertTrue(s.contains("/v8/finance/chart/AAPL"))
        XCTAssertTrue(s.contains("range=1mo"))
        XCTAssertTrue(s.contains("interval=1d"))
    }

    func testYahooChartURLDefaultsToDailyForBackwardsCompat() throws {
        let url = try XCTUnwrap(YahooQuoteProvider.chartURL(symbol: "AAPL"))
        let s = url.absoluteString
        XCTAssertTrue(s.contains("range=1d"))
        XCTAssertTrue(s.contains("interval=1d"))
    }

    func testYahooChartURLHistoricalRangePreservesSymbolFix() throws {
        let url = try XCTUnwrap(YahooQuoteProvider.chartURL(symbol: "BRK.B", range: "5y", interval: "1d"))
        XCTAssertTrue(url.absoluteString.contains("/v8/finance/chart/BRK-B"))
        XCTAssertTrue(url.absoluteString.contains("range=5y"))
    }

    func testYahooFXHistoricalURLUsesEqualsXForm() throws {
        let url = try XCTUnwrap(YahooQuoteProvider.chartURL(symbol: "EURUSD=X", range: "1y", interval: "1d"))
        let s = url.absoluteString
        XCTAssertTrue(s.contains("EURUSD=X") || s.contains("EURUSD%3DX"))
        XCTAssertTrue(s.contains("range=1y"))
    }

    // MARK: - CoinGecko

    func testCoinGeckoMarketChartURLBuilds() throws {
        let url = try XCTUnwrap(CoinGeckoQuoteProvider.marketChartURL(coinID: "bitcoin", days: 30))
        let s = url.absoluteString
        XCTAssertTrue(s.contains("/coins/bitcoin/market_chart"))
        XCTAssertTrue(s.contains("vs_currency=usd"))
        XCTAssertTrue(s.contains("days=30"))
        XCTAssertTrue(s.contains("interval=daily"))
    }

    func testCoinGeckoMarketChartURLRejectsEmptyIDOrZeroDays() {
        XCTAssertNil(CoinGeckoQuoteProvider.marketChartURL(coinID: "", days: 30))
        XCTAssertNil(CoinGeckoQuoteProvider.marketChartURL(coinID: "bitcoin", days: 0))
    }
}
