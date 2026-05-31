import XCTest
@testable import Folio

/// Symbol-mapping, URL-builder, and date-parsing tests for `TiingoQuoteProvider`.
/// These are the pure, network-free parts (same testing posture the retired
/// Yahoo/CoinGecko providers had — live decoding needs URLSession stubbing,
/// deferred to v2). A fixed token keeps URL assertions stable.
final class TiingoProviderTests: XCTestCase {
    private let token = "TESTTOKEN"

    // MARK: - Symbol mapping

    func testEquityTickerLowercasesAndDashesDots() {
        XCTAssertEqual(TiingoQuoteProvider.equityTicker(for: "AAPL"), "aapl")
        XCTAssertEqual(TiingoQuoteProvider.equityTicker(for: "BRK.B"), "brk-b")
        XCTAssertEqual(TiingoQuoteProvider.equityTicker(for: "BF.B"), "bf-b")
    }

    func testCryptoTickerAppendsUsd() {
        XCTAssertEqual(TiingoQuoteProvider.cryptoTicker(for: "BTC"), "btcusd")
        XCTAssertEqual(TiingoQuoteProvider.cryptoTicker(for: "eth"), "ethusd")
        XCTAssertEqual(TiingoQuoteProvider.cryptoTicker(for: "SOL"), "solusd")
    }

    func testCryptoTickerHonorsOverrides() {
        // MATIC→POL rebrand: routed through the override map, case-insensitive.
        XCTAssertEqual(TiingoQuoteProvider.cryptoTicker(for: "MATIC"), "maticusd")
        XCTAssertEqual(TiingoQuoteProvider.cryptoTicker(for: "matic"), "maticusd")
    }

    func testFXTickerConcatenatesLowercased() {
        XCTAssertEqual(TiingoQuoteProvider.fxTicker(from: "EUR", to: "USD"), "eurusd")
        XCTAssertEqual(TiingoQuoteProvider.fxTicker(from: "usd", to: "JPY"), "usdjpy")
    }

    // MARK: - URL builders

    func testEquityLatestPriceURL() throws {
        let url = try XCTUnwrap(TiingoQuoteProvider.equityPricesURL(symbol: "BRK.B", token: token))
        let s = url.absoluteString
        XCTAssertTrue(s.contains("/tiingo/daily/brk-b/prices"), s)
        XCTAssertTrue(s.contains("token=TESTTOKEN"))
        XCTAssertTrue(s.contains("format=json"))
        // No startDate → latest-only, so no resampleFreq is appended.
        XCTAssertFalse(s.contains("resampleFreq"))
        XCTAssertFalse(s.contains("startDate"))
    }

    func testEquityHistoricalURLAddsStartAndResample() throws {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC") ?? .current
        let start = cal.date(from: DateComponents(year: 2024, month: 1, day: 2))!
        let url = try XCTUnwrap(TiingoQuoteProvider.equityPricesURL(symbol: "AAPL", startDate: start, token: token))
        let s = url.absoluteString
        XCTAssertTrue(s.contains("/tiingo/daily/aapl/prices"), s)
        XCTAssertTrue(s.contains("startDate=2024-01-02"), s)
        XCTAssertTrue(s.contains("resampleFreq=daily"))
    }

    func testCryptoPricesURLJoinsTickers() throws {
        let url = try XCTUnwrap(TiingoQuoteProvider.cryptoPricesURL(tickers: ["btcusd", "ethusd"], token: token))
        let s = url.absoluteString
        XCTAssertTrue(s.contains("/tiingo/crypto/prices"), s)
        XCTAssertTrue(s.contains("tickers=btcusd,ethusd") || s.contains("tickers=btcusd%2Cethusd"), s)
        XCTAssertTrue(s.contains("token=TESTTOKEN"))
    }

    func testCryptoHistoricalURLUsesOneDayResample() throws {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC") ?? .current
        let start = cal.date(from: DateComponents(year: 2024, month: 1, day: 2))!
        let url = try XCTUnwrap(TiingoQuoteProvider.cryptoPricesURL(tickers: ["btcusd"], startDate: start, token: token))
        let s = url.absoluteString
        XCTAssertTrue(s.contains("startDate=2024-01-02"))
        XCTAssertTrue(s.contains("resampleFreq=1day"))
    }

    func testCryptoPricesURLNilForEmptyTickers() {
        XCTAssertNil(TiingoQuoteProvider.cryptoPricesURL(tickers: [], token: token))
    }

    func testIEXURLBatchesTickers() throws {
        let url = try XCTUnwrap(TiingoQuoteProvider.iexURL(tickers: ["aapl", "msft", "brk-b"], token: token))
        let s = url.absoluteString
        XCTAssertTrue(s.contains("api.tiingo.com/iex"), s)
        XCTAssertTrue(s.contains("tickers=aapl,msft,brk-b") || s.contains("tickers=aapl%2Cmsft%2Cbrk-b"), s)
        XCTAssertTrue(s.contains("token=TESTTOKEN"))
    }

    func testIEXURLNilForEmptyTickers() {
        XCTAssertNil(TiingoQuoteProvider.iexURL(tickers: [], token: token))
    }

    func testFXPricesURL() throws {
        let url = try XCTUnwrap(TiingoQuoteProvider.fxPricesURL(ticker: "eurusd", startDate: nil, token: token))
        let s = url.absoluteString
        XCTAssertTrue(s.contains("/tiingo/fx/eurusd/prices"), s)
        XCTAssertTrue(s.contains("resampleFreq=1day"))
        XCTAssertTrue(s.contains("token=TESTTOKEN"))
    }

    func testFXTopURL() throws {
        let url = try XCTUnwrap(TiingoQuoteProvider.fxTopURL(ticker: "eurusd", token: token))
        let s = url.absoluteString
        XCTAssertTrue(s.contains("/tiingo/fx/top"), s)
        XCTAssertTrue(s.contains("tickers=eurusd"))
    }

    // MARK: - Date parsing

    func testParseDateHandlesZuluWithFractionalSeconds() throws {
        // EOD + FX shape: "2019-01-02T00:00:00.000Z"
        let d = try XCTUnwrap(TiingoQuoteProvider.parseDate("2019-01-02T00:00:00.000Z"))
        XCTAssertEqual(d.timeIntervalSince1970, 1546387200, accuracy: 1)
    }

    func testParseDateHandlesOffsetForm() throws {
        // Crypto shape: "2019-01-02T00:00:00+00:00"
        let d = try XCTUnwrap(TiingoQuoteProvider.parseDate("2019-01-02T00:00:00+00:00"))
        XCTAssertEqual(d.timeIntervalSince1970, 1546387200, accuracy: 1)
    }

    func testParseDateReturnsNilForGarbage() {
        XCTAssertNil(TiingoQuoteProvider.parseDate("not-a-date"))
    }

    // MARK: - startDate

    func testStartDateIsRangeDaysBeforeNow() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC") ?? .current
        let now = cal.date(from: DateComponents(year: 2026, month: 6, day: 1))!
        let start = TiingoQuoteProvider.startDate(for: .y1, now: now)
        // 365 days before 2026-06-01 (UTC midnight) = 2025-06-01.
        XCTAssertEqual(TiingoQuoteProvider.ymd(start), "2025-06-01")
    }
}
