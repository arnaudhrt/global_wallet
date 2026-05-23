import Foundation
import SwiftData

/// Append-only archive of daily historical closes per (asset, source). Sibling
/// of `PriceQuote` — that one is an ephemeral snapshot refreshed on a timer,
/// this one is a stable historical record fetched lazily and never overwritten.
///
/// Used by M8.5's Overview chart: `HistoricalQuoteService` populates rows on
/// first paint for the selected `QuoteRange`; `PortfolioHistoryReducer` reads
/// them via a forward-fill lookup.
@Model
final class HistoricalQuote {
    var id: UUID
    /// Composite natural key: `"\(assetSymbol)/\(source)/\(yyyy-MM-dd UTC)"`.
    /// Enforces one row per (asset, source, day) — re-fetches of an already-
    /// stored day are silently dropped by SwiftData's unique constraint.
    @Attribute(.unique) var key: String
    var asset: Asset
    /// UTC midnight of the trading day.
    var date: Date
    var close: Decimal
    var currency: String
    var source: String

    init(
        id: UUID = UUID(),
        asset: Asset,
        date: Date,
        close: Decimal,
        currency: String,
        source: String
    ) {
        self.id = id
        self.asset = asset
        self.date = date
        self.close = close
        self.currency = currency
        self.source = source
        self.key = Self.makeKey(assetSymbol: asset.symbol, source: source, date: date)
    }

    static func makeKey(assetSymbol: String, source: String, date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        return "\(assetSymbol)/\(source)/\(f.string(from: date))"
    }
}
