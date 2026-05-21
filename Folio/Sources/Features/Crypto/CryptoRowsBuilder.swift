import Foundation

/// Sort columns offered on the Crypto screen. Each column has an
/// ascending/descending direction; the screen tracks both.
enum CryptoSortColumn: String, CaseIterable, Hashable {
    case ticker
    case qty
    case avgCost
    case price
    case marketValue
    case pnl
    case pnlPct
    case allocation

    var label: String {
        switch self {
        case .ticker:      return "Asset"
        case .qty:         return "Qty"
        case .avgCost:     return "Avg Cost"
        case .price:       return "Current Price"
        case .marketValue: return "Market Value"
        case .pnl:         return "P&L $"
        case .pnlPct:      return "P&L %"
        case .allocation:  return "Allocation"
        }
    }
}

struct CryptoSort: Equatable {
    var column: CryptoSortColumn
    var ascending: Bool

    static let `default` = CryptoSort(column: .marketValue, ascending: false)
}

/// Pure filter+sort over precomputed `[Holding]` arrays plus a couple of
/// crypto-specific aggregations. Lives outside the view so it's testable
/// without spinning up SwiftData.
///
/// Wallet-scoping is handled upstream by filtering `transactions` before they
/// hit `HoldingsReducer` — same pattern as `StocksRowsBuilder`. This helper
/// only needs to keep crypto kinds and apply the sort.
@MainActor
enum CryptoRowsBuilder {
    static func filterAndSort(_ holdings: [Holding], sort: CryptoSort) -> [Holding] {
        let cryptoOnly = holdings.filter { $0.asset.kind == .crypto }
        return sorted(cryptoOnly, by: sort)
    }

    /// Distinct wallet/exchange account names from crypto-asset transactions,
    /// alphabetized. Used to populate the filter pills.
    static func walletAccountNames(from transactions: [PortfolioTransaction]) -> [String] {
        var names: Set<String> = []
        for txn in transactions {
            guard let asset = txn.asset, asset.kind == .crypto else { continue }
            names.insert(txn.account.name)
        }
        return names.sorted()
    }

    /// Sum of `.stake` transaction amounts for crypto assets within the
    /// current calendar year (gregorian, system tz). Mirrors how
    /// `StocksScreen` computes Dividends YTD.
    static func stakingYTD(from transactions: [PortfolioTransaction], now: Date = Date()) -> Decimal {
        let cal = Calendar(identifier: .gregorian)
        let year = cal.component(.year, from: now)
        return transactions
            .filter { txn in
                guard txn.type == .stake, let asset = txn.asset, asset.kind == .crypto else { return false }
                return cal.component(.year, from: txn.date) == year
            }
            .reduce(Decimal(0)) { $0 + $1.amount }
    }

    /// Per-wallet sub-rows belonging to the given aggregate asset symbol.
    /// `perWalletHoldings` should be the output of
    /// `HoldingsReducer.reduceByAssetAndAccount`.
    static func subRows(
        for symbol: String,
        from perWalletHoldings: [Holding]
    ) -> [Holding] {
        perWalletHoldings
            .filter { $0.asset.kind == .crypto && $0.asset.symbol == symbol }
            .sorted { (a, b) in
                let av = a.marketValue?.amount ?? 0
                let bv = b.marketValue?.amount ?? 0
                return av > bv
            }
    }

    // MARK: - Sort

    private static func sorted(_ holdings: [Holding], by sort: CryptoSort) -> [Holding] {
        holdings.sorted { a, b in
            let order = compare(a, b, by: sort.column)
            return sort.ascending ? (order == .orderedAscending) : (order == .orderedDescending)
        }
    }

    private static func compare(_ a: Holding, _ b: Holding, by column: CryptoSortColumn) -> ComparisonResult {
        switch column {
        case .ticker:
            return a.asset.symbol.compare(b.asset.symbol)
        case .qty:
            return decimalCompare(a.qty, b.qty)
        case .avgCost:
            return decimalCompare(a.avgCost.amount, b.avgCost.amount)
        case .price:
            return decimalCompare(unitPrice(a), unitPrice(b))
        case .marketValue, .allocation:
            return decimalCompare(a.marketValue?.amount, b.marketValue?.amount)
        case .pnl:
            return decimalCompare(a.unrealizedPnL?.amount, b.unrealizedPnL?.amount)
        case .pnlPct:
            return doubleCompare(a.unrealizedPnLPct, b.unrealizedPnLPct)
        }
    }

    private static func unitPrice(_ h: Holding) -> Decimal? {
        guard let mv = h.marketValue?.amount, h.qty > 0 else { return nil }
        return mv / h.qty
    }

    /// `nil` sorts below any real value in either direction — missing
    /// prices/PnL sink to the bottom regardless of asc/desc.
    private static func decimalCompare(_ a: Decimal?, _ b: Decimal?) -> ComparisonResult {
        switch (a, b) {
        case let (a?, b?):
            if a < b { return .orderedAscending }
            if a > b { return .orderedDescending }
            return .orderedSame
        case (nil, nil): return .orderedSame
        case (nil, _):   return .orderedAscending
        case (_, nil):   return .orderedDescending
        }
    }

    private static func doubleCompare(_ a: Double?, _ b: Double?) -> ComparisonResult {
        switch (a, b) {
        case let (a?, b?):
            if a < b { return .orderedAscending }
            if a > b { return .orderedDescending }
            return .orderedSame
        case (nil, nil): return .orderedSame
        case (nil, _):   return .orderedAscending
        case (_, nil):   return .orderedDescending
        }
    }
}
