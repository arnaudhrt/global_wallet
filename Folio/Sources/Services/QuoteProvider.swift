import Foundation

/// Abstraction over a price-data source. M4 implementations: `MockQuoteProvider`
/// (deterministic walk for tests/offline), `YahooQuoteProvider` (stocks/ETFs/FX),
/// `CoinGeckoQuoteProvider` (crypto).
///
/// `historical(symbol:range:)` and `search(query:)` are declared so M8 (Overview
/// chart) and M9 (Add Transaction autocomplete) can layer on without re-shaping
/// callers. Concrete providers in M4 throw `.notImplemented` for them.
protocol QuoteProvider: Sendable {
    func quote(symbol: String) async throws -> QuoteResult
    func historical(symbol: String, range: QuoteRange) async throws -> [HistoricalPoint]
    func search(query: String) async throws -> [SymbolMatch]

    /// Batched quote fetch. Default implementation fans out to `quote()` per
    /// symbol concurrently; providers with a true batch endpoint (CoinGecko's
    /// `simple/price?ids=a,b,c`) override this to issue a single network call —
    /// otherwise we burn rate-limit budget for nothing.
    func batchQuotes(symbols: [String]) async -> [String: Result<QuoteResult, Error>]
}

extension QuoteProvider {
    func batchQuotes(symbols: [String]) async -> [String: Result<QuoteResult, Error>] {
        await withTaskGroup(of: (String, Result<QuoteResult, Error>).self) { group in
            for symbol in symbols {
                group.addTask {
                    do { return (symbol, .success(try await self.quote(symbol: symbol))) }
                    catch { return (symbol, .failure(error)) }
                }
            }
            var out: [String: Result<QuoteResult, Error>] = [:]
            while let (s, r) = await group.next() { out[s] = r }
            return out
        }
    }
}

struct QuoteResult: Sendable, Equatable {
    let symbol: String
    let price: Decimal
    let currency: String
    let asOf: Date
}

enum QuoteRange: String, Sendable, CaseIterable {
    case d1, w1, m1, m3, y1, y5
}

struct HistoricalPoint: Sendable, Equatable {
    let date: Date
    let close: Decimal
}

struct SymbolMatch: Sendable, Equatable {
    let symbol: String
    let name: String
    let exchange: String?
}

enum QuoteProviderError: Error, Equatable {
    case notImplemented
    case unsupportedSymbol(String)
    case network(String)
    case decoding(String)
    case rateLimited
}
