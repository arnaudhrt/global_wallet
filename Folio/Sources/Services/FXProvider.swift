import Foundation

/// Foreign-exchange rates. Kept separate from `QuoteProvider` because the API
/// shape is fundamentally different (pair input, not symbol). Yahoo implements
/// both via the `EURUSD=X` symbol convention.
///
/// `historical(from:to:range:)` is declared so M8.5's chart can ask for a span
/// of daily rates without fanning out per-day. Concrete providers that don't
/// support history throw `.notImplemented` via the default extension.
protocol FXProvider: Sendable {
    func rate(from: String, to: String) async throws -> FXResult
    func historical(from: String, to: String, range: QuoteRange) async throws -> [HistoricalFXPoint]
}

extension FXProvider {
    func historical(from: String, to: String, range: QuoteRange) async throws -> [HistoricalFXPoint] {
        throw FXProviderError.network("historical FX not implemented")
    }
}

struct FXResult: Sendable, Equatable {
    let from: String
    let to: String
    let rate: Decimal
    let asOf: Date
}

struct HistoricalFXPoint: Sendable, Equatable {
    let date: Date
    let rate: Decimal
}

enum FXProviderError: Error, Equatable {
    case unsupportedPair(String, String)
    case network(String)
    case decoding(String)
}
