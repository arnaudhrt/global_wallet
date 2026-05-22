import Foundation
import SwiftData

/// Aggregations specific to the Overview screen (M8). Lives next to
/// `OverviewScreen` because the helpers (earliest-txn date, positions count,
/// stocks-vs-crypto bucketing) aren't reused elsewhere yet. If a second screen
/// ever wants the allocation bucketing, hoist into `PortfolioMetrics`.
@MainActor
enum OverviewMetricsBuilder {
    enum AllocationCategory: String, Hashable, CaseIterable {
        case stocks
        case crypto

        var displayName: String {
            switch self {
            case .stocks: return "Stocks & ETFs"
            case .crypto: return "Crypto"
            }
        }
    }

    struct AllocationEntry: Equatable {
        let category: AllocationCategory
        let amount: Money
        let pct: Decimal
    }

    static func earliestTransactionDate(from transactions: [PortfolioTransaction]) -> Date? {
        transactions.map(\.date).min()
    }

    /// `HoldingsReducer` already drops zero-qty buckets, so this is effectively
    /// `holdings.count` — kept defensive in case a future reducer change keeps
    /// zero rows for display.
    static func positionsCount(_ holdings: [Holding]) -> Int {
        holdings.filter { $0.qty > 0 }.count
    }

    /// Distinct accounts that appear on any transaction. Reflects the full
    /// ledger footprint (matches the JSX "across N accounts" intent), including
    /// accounts whose holdings have been fully sold out.
    static func accountsCount(from transactions: [PortfolioTransaction]) -> Int {
        Set(transactions.map { $0.account.persistentModelID }).count
    }

    /// Stocks (= stock + etf lumped) and Crypto buckets with USD amount and
    /// pct of total. Returned in display order (Stocks first). Empty when no
    /// holding has a market value, or when no stock/crypto holdings exist.
    /// Cash bucket deferred until cash tracking is properly modeled.
    static func allocation(_ holdings: [Holding], baseCurrency: String) -> [AllocationEntry] {
        var amount: [AllocationCategory: Decimal] = [:]
        for h in holdings {
            guard let mv = h.marketValue?.amount else { continue }
            switch h.asset.kind {
            case .stock, .etf: amount[.stocks, default: 0] += mv
            case .crypto:      amount[.crypto, default: 0] += mv
            case .cash:        break
            }
        }
        let total = amount.values.reduce(Decimal(0), +)
        guard total > 0 else { return [] }

        return AllocationCategory.allCases.compactMap { cat in
            guard let value = amount[cat], value > 0 else { return nil }
            return AllocationEntry(
                category: cat,
                amount: Money(amount: value, currency: baseCurrency),
                pct: value / total * 100
            )
        }
    }
}
