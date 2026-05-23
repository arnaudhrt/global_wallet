import Foundation

/// Roll-ups over `[Holding]` for the Overview screen (M8). Lives in M3 because
/// the sidebar footer (and tests) can use `totalValue` immediately.
@MainActor
enum PortfolioMetrics {
    static func totalValue(_ holdings: [Holding], baseCurrency: String) -> Money {
        let sum = holdings.compactMap { $0.marketValue?.amount }.reduce(Decimal(0), +)
        return Money(amount: sum, currency: baseCurrency)
    }

    static func investedCapital(_ holdings: [Holding], baseCurrency: String) -> Money {
        let sum = holdings
            .map { $0.avgCost.amount * $0.qty }
            .reduce(Decimal(0), +)
        return Money(amount: sum, currency: baseCurrency)
    }

    static func gainAllTime(_ holdings: [Holding], baseCurrency: String) -> Money {
        let mv = totalValue(holdings, baseCurrency: baseCurrency).amount
        let cost = investedCapital(holdings, baseCurrency: baseCurrency).amount
        return Money(amount: mv - cost, currency: baseCurrency)
    }

    /// Returns percentage of total market value for each `AssetKind` present.
    /// Missing kinds are omitted (not zero). Percentages sum to ~100 (subject
    /// to rounding); each value is in 0…100 range, not 0…1.
    static func allocationByKind(_ holdings: [Holding]) -> [AssetKind: Decimal] {
        let total = holdings.compactMap { $0.marketValue?.amount }.reduce(Decimal(0), +)
        guard total > 0 else { return [:] }
        var result: [AssetKind: Decimal] = [:]
        for holding in holdings {
            guard let mv = holding.marketValue?.amount else { continue }
            result[holding.asset.kind, default: 0] += mv
        }
        return result.mapValues { $0 / total * 100 }
    }

    /// YTD performance as a percentage (0…100 range), computed from a chart-
    /// shaped history series. Looks up the first point on/after Jan 1 of `now`'s
    /// year and compares it to the latest point. Returns nil if the series
    /// doesn't span Jan 1, or if the Jan 1 value is zero (no portfolio yet).
    static func ytdPerformance(history: [HistoryPoint], now: Date = .now) -> Double? {
        guard !history.isEmpty else { return nil }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC") ?? .current
        let year = cal.component(.year, from: now)
        guard let jan1 = cal.date(from: DateComponents(year: year, month: 1, day: 1)) else { return nil }

        let sorted = history.sorted(by: { $0.date < $1.date })
        guard let start = sorted.first(where: { $0.date >= jan1 }) else { return nil }
        guard let end = sorted.last else { return nil }
        let startAmount = start.total.amount
        guard startAmount > 0 else { return nil }

        let pct = (end.total.amount - startAmount) / startAmount * 100
        return Double(truncating: pct as NSDecimalNumber)
    }
}
