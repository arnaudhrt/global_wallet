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
        // Reproducible synthetic series — walks backward from a per-symbol seed
        // so each call returns the same points. Tests use this to drive the
        // history reducer without hitting the network.
        let days = range.days()
        var local = Int(seedBase &+ symbol.unicodeScalars.reduce(into: 0) { $0 = $0 &+ Int($1.value) })
        var price = Decimal(100)
        var points: [HistoricalPoint] = []
        points.reserveCapacity(days)
        let cal = Calendar(identifier: .gregorian)
        let today = cal.startOfDay(for: Date())
        for offset in 0..<days {
            local = (local &* 9301 &+ 49297) % 233280
            let r = Decimal(local) / 233280
            let step = (r - Decimal(42) / Decimal(100)) * (Decimal(16) / Decimal(10))
            price = max(Decimal(1) / Decimal(100), price + step)
            if let d = cal.date(byAdding: .day, value: -(days - 1 - offset), to: today) {
                points.append(HistoricalPoint(date: d, close: price))
            }
        }
        return points
    }

    func search(query: String) async throws -> [SymbolMatch] {
        throw QuoteProviderError.notImplemented
    }

    // MARK: - FXProvider

    func rate(from: String, to: String) async throws -> FXResult {
        let rate = try fxRate(from: from, to: to)
        return FXResult(from: from, to: to, rate: rate, asOf: Date())
    }

    func historical(from: String, to: String, range: QuoteRange) async throws -> [HistoricalFXPoint] {
        if from == to { return [] }
        let rate = try fxRate(from: from, to: to)
        let days = range.days()
        let cal = Calendar(identifier: .gregorian)
        let today = cal.startOfDay(for: Date())
        var points: [HistoricalFXPoint] = []
        points.reserveCapacity(days)
        for offset in 0..<days {
            if let d = cal.date(byAdding: .day, value: -(days - 1 - offset), to: today) {
                // Flat series — tests don't need realistic FX drift, just a
                // stable rate at each requested date.
                points.append(HistoricalFXPoint(date: d, rate: rate))
            }
        }
        return points
    }

    private func fxRate(from: String, to: String) throws -> Decimal {
        switch (from, to) {
        case let (a, b) where a == b: return 1
        case ("USD", "EUR"): return Decimal(92) / Decimal(100)
        case ("EUR", "USD"): return Decimal(1087) / Decimal(1000)
        case ("USD", "GBP"): return Decimal(79) / Decimal(100)
        case ("GBP", "USD"): return Decimal(1266) / Decimal(1000)
        default: throw FXProviderError.unsupportedPair(from, to)
        }
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
        let step = (r - Decimal(42) / Decimal(100)) * (Decimal(16) / Decimal(10))
        state.price = max(Decimal(1) / Decimal(100), state.price + step)
        states[symbol] = state
        return state.price
    }
}
