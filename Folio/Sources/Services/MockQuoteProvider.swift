import Foundation

/// Deterministic price generator for tests + offline dev. Ports the LCG random
/// walk from the prototype's `project/data.jsx` (seed → (s*9301+49297) % 233280).
///
/// `quote(symbol:)` advances per-symbol state so repeated calls produce a
/// monotonically-drifting series. Stateless across instances — each
/// `MockQuoteProvider` reseeds from a baseline so test runs are bit-for-bit
/// reproducible.
///
/// Also conforms to `FXProvider` with a tiny fixed-rate table — enough for
/// `HoldingsReducer` tests that exercise non-USD transactions.
actor MockQuoteProvider: QuoteProvider, FXProvider {
    /// Seed per-symbol generators from this baseline. Same baseline → same series.
    private let seedBase: Int
    private var states: [String: WalkState] = [:]

    init(seedBase: Int = 7) {
        self.seedBase = seedBase
    }

    // MARK: - QuoteProvider

    func quote(symbol: String) async throws -> QuoteResult {
        let price = nextPrice(for: symbol)
        return QuoteResult(
            symbol: symbol,
            price: price,
            currency: "USD",
            asOf: Date()
        )
    }

    func historical(symbol: String, range: QuoteRange) async throws -> [HistoricalPoint] {
        throw QuoteProviderError.notImplemented
    }

    func search(query: String) async throws -> [SymbolMatch] {
        throw QuoteProviderError.notImplemented
    }

    // MARK: - FXProvider

    func rate(from: String, to: String) async throws -> FXResult {
        let rate: Decimal
        switch (from, to) {
        case let (a, b) where a == b: rate = 1
        case ("USD", "EUR"): rate = Decimal(string: "0.92")!
        case ("EUR", "USD"): rate = Decimal(string: "1.087")!
        case ("USD", "GBP"): rate = Decimal(string: "0.79")!
        case ("GBP", "USD"): rate = Decimal(string: "1.266")!
        default: throw FXProviderError.unsupportedPair(from, to)
        }
        return FXResult(from: from, to: to, rate: rate, asOf: Date())
    }

    // MARK: - Internal walk

    /// LCG (Linear Congruential Generator) lifted from `data.jsx:74`:
    /// `s = (s * 9301 + 49297) % 233280; return s / 233280`.
    /// Starting price 100, step ≈ (r - 0.42) * 1.6 — same drift as the prototype.
    private struct WalkState {
        var seed: Int
        var price: Decimal
    }

    private func nextPrice(for symbol: String) -> Decimal {
        let symbolHash = symbol.unicodeScalars.reduce(into: 0) { $0 = $0 &+ Int($1.value) }
        var state = states[symbol] ?? WalkState(
            seed: seedBase &+ symbolHash,
            price: 100
        )
        state.seed = (state.seed &* 9301 &+ 49297) % 233280
        let r = Decimal(state.seed) / 233280
        let step = (r - Decimal(string: "0.42")!) * Decimal(string: "1.6")!
        state.price = max(Decimal(string: "0.01")!, state.price + step)
        states[symbol] = state
        return state.price
    }
}
