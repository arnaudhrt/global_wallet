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
}
