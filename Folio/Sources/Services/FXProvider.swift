import Foundation

/// Foreign-exchange rates. Kept separate from `QuoteProvider` because the API
/// shape is fundamentally different (pair input, not symbol). Yahoo implements
/// both via the `EURUSD=X` symbol convention.
protocol FXProvider: Sendable {
    func rate(from: String, to: String) async throws -> FXResult
}

struct FXResult: Sendable, Equatable {
    let from: String
    let to: String
    let rate: Decimal
    let asOf: Date
}

enum FXProviderError: Error, Equatable {
    case unsupportedPair(String, String)
    case network(String)
    case decoding(String)
}
