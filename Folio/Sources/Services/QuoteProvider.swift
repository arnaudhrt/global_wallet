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
    case d1, w1, m1, m3, ytd, y1, y5, all

    /// Yahoo's `range=` query value. `ytd` is supported natively; `all` maps to
    /// `max`. The rest follow Yahoo's standard suffixes.
    var yahooRange: String {
        switch self {
        case .d1:  return "1d"
        case .w1:  return "5d"
        case .m1:  return "1mo"
        case .m3:  return "3mo"
        case .ytd: return "ytd"
        case .y1:  return "1y"
        case .y5:  return "5y"
        case .all: return "max"
        }
    }

    /// CoinGecko's `days=` query value. Their `market_chart` endpoint takes a
    /// number of days; we pre-compute that here. `.ytd` resolves against `now`
    /// (injectable for tests); `.all` uses a large enough window (10 years) to
    /// cover any seeded history without abusing the API.
    func days(now: Date = .now) -> Int {
        switch self {
        case .d1:  return 1
        case .w1:  return 7
        case .m1:  return 30
        case .m3:  return 90
        case .y1:  return 365
        case .y5:  return 365 * 5
        case .all: return 365 * 10
        case .ytd:
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = TimeZone(identifier: "UTC") ?? .current
            let year = cal.component(.year, from: now)
            let jan1 = cal.date(from: DateComponents(year: year, month: 1, day: 1)) ?? now
            let diff = cal.dateComponents([.day], from: jan1, to: now).day ?? 1
            return max(diff, 1)
        }
    }

    /// Maps the `PeriodPills` raw string to the matching range. Returns nil for
    /// strings outside the chart subset (M8.5 only surfaces 1M / 3M / YTD / 1Y / All).
    init?(pill: String) {
        switch pill {
        case "1M":  self = .m1
        case "3M":  self = .m3
        case "YTD": self = .ytd
        case "1Y":  self = .y1
        case "All": self = .all
        default:    return nil
        }
    }
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
