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

    func testSearchIsNotImplemented() async {
        let p = MockQuoteProvider()
        await XCTAssertThrowsErrorAsync(try await p.search(query: "App")) { err in
            XCTAssertEqual(err as? QuoteProviderError, .notImplemented)
        }
    }

    func testHistoricalReturnsDeterministicSeries() async throws {
        // M8.5 — Mock now produces a reproducible backward LCG walk so the
        // history reducer can be tested against it without hitting the network.
        let a = MockQuoteProvider(seedBase: 5)
        let b = MockQuoteProvider(seedBase: 5)
        let aPoints = try await a.historical(symbol: "AAPL", range: .m1)
        let bPoints = try await b.historical(symbol: "AAPL", range: .m1)
        XCTAssertFalse(aPoints.isEmpty)
        XCTAssertEqual(aPoints.count, QuoteRange.m1.days())
        XCTAssertEqual(aPoints.map(\.close), bPoints.map(\.close))
        for p in aPoints {
            XCTAssertGreaterThan(p.close, 0)
        }
    }

    func testFXRateSameCurrencyIsOne() async throws {
        let p = MockQuoteProvider()
        let r = try await p.rate(from: "USD", to: "USD")
        XCTAssertEqual(r.rate, 1)
    }

    func testFXProviderRoundtripConsistency() async throws {
        // For every supported pair, A→B→A round-trip through the provider's
        // public API should yield ~1. This tests provider *behavior*, not a
        // property of the literal table — if a future maintainer changes
        // either constant without updating its inverse, this fails.
        let p = MockQuoteProvider()
        let pairs: [(String, String)] = [("USD", "EUR"), ("USD", "GBP")]
        for (a, b) in pairs {
            let ab = try await p.rate(from: a, to: b)
            let ba = try await p.rate(from: b, to: a)
            let product = (ab.rate as NSDecimalNumber).doubleValue
                        * (ba.rate as NSDecimalNumber).doubleValue
            XCTAssertEqual(product, 1.0, accuracy: 0.01, "round-trip \(a)→\(b)→\(a)")
        }
    }

    func testMultiSymbolStateIsIndependent() async throws {
        // AAPL's per-symbol walk must not be perturbed by interleaved BTC
        // calls — each symbol has its own LCG state.
        let solo = MockQuoteProvider(seedBase: 99)
        var soloAapl: [Decimal] = []
        for _ in 0..<3 {
            soloAapl.append(try await solo.quote(symbol: "AAPL").price)
        }

        let mixed = MockQuoteProvider(seedBase: 99)
        var mixedAapl: [Decimal] = []
        for _ in 0..<3 {
            mixedAapl.append(try await mixed.quote(symbol: "AAPL").price)
            _ = try await mixed.quote(symbol: "BTC")
        }
        XCTAssertEqual(soloAapl, mixedAapl)
    }

    func testFXUnsupportedPairThrows() async {
        let p = MockQuoteProvider()
        await XCTAssertThrowsErrorAsync(try await p.rate(from: "CHF", to: "JPY")) { err in
            guard case FXProviderError.unsupportedPair(let from, let to) = err else {
                return XCTFail("expected .unsupportedPair, got \(err)")
            }
            XCTAssertEqual(from, "CHF")
            XCTAssertEqual(to, "JPY")
        }
    }

    func testHistoricalFXIsFlatOverRange() async throws {
        let p = MockQuoteProvider()
        let points = try await p.historical(from: "USD", to: "EUR", range: .m1)
        XCTAssertFalse(points.isEmpty)
        let rates = Set(points.map(\.rate))
        XCTAssertEqual(rates.count, 1, "historical FX is flat — every point shares one rate")
        XCTAssertEqual(rates.first, Decimal(92) / Decimal(100))
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
