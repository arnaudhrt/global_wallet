import XCTest
@testable import Folio

final class MockQuoteProviderTests: XCTestCase {
    func testSameSeedProducesIdenticalSequence() async throws {
        let a = MockQuoteProvider(seedBase: 42)
        let b = MockQuoteProvider(seedBase: 42)
        for _ in 0..<5 {
            let qa = try await a.quote(symbol: "AAPL")
            let qb = try await b.quote(symbol: "AAPL")
            XCTAssertEqual(qa.price, qb.price, "Same seed must replay identically")
        }
    }

    func testPriceStaysPositiveOverManyTicks() async throws {
        let p = MockQuoteProvider(seedBase: 7)
        for _ in 0..<500 {
            let q = try await p.quote(symbol: "BTC")
            XCTAssertGreaterThan(q.price, 0)
        }
    }

    func testDifferentSeedsProduceDifferentSequences() async throws {
        let a = MockQuoteProvider(seedBase: 1)
        let b = MockQuoteProvider(seedBase: 2)
        let qa = try await a.quote(symbol: "AAPL")
        let qb = try await b.quote(symbol: "AAPL")
        XCTAssertNotEqual(qa.price, qb.price)
    }

    func testHistoricalAndSearchAreNotImplemented() async {
        let p = MockQuoteProvider()
        await XCTAssertThrowsErrorAsync(try await p.historical(symbol: "AAPL", range: .y1)) { err in
            XCTAssertEqual(err as? QuoteProviderError, .notImplemented)
        }
        await XCTAssertThrowsErrorAsync(try await p.search(query: "App")) { err in
            XCTAssertEqual(err as? QuoteProviderError, .notImplemented)
        }
    }

    func testFXRateSameCurrencyIsOne() async throws {
        let p = MockQuoteProvider()
        let r = try await p.rate(from: "USD", to: "USD")
        XCTAssertEqual(r.rate, 1)
    }

    func testFXRateUSDEURRoundtripCloseToOne() async throws {
        let p = MockQuoteProvider()
        let usdEur = try await p.rate(from: "USD", to: "EUR")
        let eurUsd = try await p.rate(from: "EUR", to: "USD")
        let product = (usdEur.rate as NSDecimalNumber).doubleValue * (eurUsd.rate as NSDecimalNumber).doubleValue
        XCTAssertEqual(product, 1.0, accuracy: 0.01)
    }
}

/// Async equivalent of `XCTAssertThrowsError` — XCTest's version doesn't take
/// an async autoclosure.
func XCTAssertThrowsErrorAsync<T>(
    _ expression: @autoclosure () async throws -> T,
    file: StaticString = #file,
    line: UInt = #line,
    _ handler: (Error) -> Void = { _ in }
) async {
    do {
        _ = try await expression()
        XCTFail("Expected error, got success", file: file, line: line)
    } catch {
        handler(error)
    }
}
