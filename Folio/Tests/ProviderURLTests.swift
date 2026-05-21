import XCTest
@testable import Folio

/// Tests the symbol→URL transformations that happen before the network call.
/// These are the only easily-testable parts of the live providers; the rest
/// requires URLSession stubbing (deferred to v2).
final class ProviderURLTests: XCTestCase {
    // MARK: - Yahoo

    func testYahooSymbolReplacesDotWithDash() {
        XCTAssertEqual(YahooQuoteProvider.yahooSymbol(for: "BRK.B"), "BRK-B")
        XCTAssertEqual(YahooQuoteProvider.yahooSymbol(for: "AAPL"), "AAPL")
        XCTAssertEqual(YahooQuoteProvider.yahooSymbol(for: "BF.B"), "BF-B")
    }

    func testYahooChartURLEncodesTransformedSymbol() {
        let url = try? XCTUnwrap(YahooQuoteProvider.chartURL(symbol: "BRK.B"))
        XCTAssertNotNil(url)
        let s = url!.absoluteString
        XCTAssertTrue(s.contains("/v8/finance/chart/BRK-B"), "URL must encode `BRK-B`, got \(s)")
        XCTAssertTrue(s.contains("interval=1d"))
        XCTAssertTrue(s.contains("range=1d"))
    }

    func testYahooFXSymbolFormat() {
        // FX pairs go through the same chart endpoint with the `EURUSD=X` shape.
        // The provider builds this via the public `rate(from:to:)` API, but we
        // can verify the URL construction the same way.
        let url = try? XCTUnwrap(YahooQuoteProvider.chartURL(symbol: "EURUSD=X"))
        XCTAssertNotNil(url)
        let s = url!.absoluteString
        XCTAssertTrue(s.contains("EURUSD=X") || s.contains("EURUSD%3DX"))
    }

    // MARK: - CoinGecko

    func testCoinGeckoMATICMapsToPolygonEcosystemToken() {
        let p = CoinGeckoQuoteProvider()
        // The Sep-2024 rebrand: old `matic-network` id returns {} now.
        XCTAssertEqual(p.coinId(for: "MATIC"), "polygon-ecosystem-token")
        XCTAssertEqual(p.coinId(for: "matic"), "polygon-ecosystem-token", "lookup is case-insensitive")
    }

    func testCoinGeckoSeedSymbolsResolve() {
        let p = CoinGeckoQuoteProvider()
        XCTAssertEqual(p.coinId(for: "BTC"), "bitcoin")
        XCTAssertEqual(p.coinId(for: "ETH"), "ethereum")
        XCTAssertEqual(p.coinId(for: "SOL"), "solana")
        XCTAssertEqual(p.coinId(for: "LINK"), "chainlink")
        XCTAssertEqual(p.coinId(for: "USDC"), "usd-coin")
    }

    func testCoinGeckoUnknownSymbolReturnsNil() {
        let p = CoinGeckoQuoteProvider()
        XCTAssertNil(p.coinId(for: "ZZZZ"))
    }

    func testCoinGeckoPriceURLContainsAllIds() {
        let url = try? XCTUnwrap(CoinGeckoQuoteProvider.priceURL(ids: ["bitcoin", "ethereum"]))
        XCTAssertNotNil(url)
        let s = url!.absoluteString
        XCTAssertTrue(s.contains("ids=bitcoin,ethereum") || s.contains("ids=bitcoin%2Cethereum"))
        XCTAssertTrue(s.contains("vs_currencies=usd"))
        XCTAssertTrue(s.contains("include_last_updated_at=true"))
    }

    func testCoinGeckoPriceURLNilForEmptyInput() {
        XCTAssertNil(CoinGeckoQuoteProvider.priceURL(ids: []))
    }
}
