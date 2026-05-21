import Foundation

/// Sort columns offered on the Stocks & ETFs screen. Each column has an
/// ascending/descending direction; the screen tracks both.
enum StocksSortColumn: String, CaseIterable, Hashable {
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

struct StocksSort: Equatable {
    var column: StocksSortColumn
    var ascending: Bool

    static let `default` = StocksSort(column: .marketValue, ascending: false)
}

/// Pure filter+sort over a precomputed `[Holding]`. Lives outside the view so
/// it's testable without spinning up SwiftData.
///
/// Account-scoping is handled upstream by filtering `transactions` before they
/// hit `HoldingsReducer`, so this helper only needs to drop non-stock kinds
/// and apply the sort.
@MainActor
enum StocksRowsBuilder {
    static func filterAndSort(_ holdings: [Holding], sort: StocksSort) -> [Holding] {
        let stocksOnly = holdings.filter { $0.asset.kind == .stock || $0.asset.kind == .etf }
        return sorted(stocksOnly, by: sort)
    }

    /// Total market value across all stocks/ETFs in the input. Used both for
    /// the summary card and as the denominator for each row's allocation %.
    /// Holdings missing a price are silently ignored.
    static func totalMarketValue(_ holdings: [Holding]) -> Decimal {
        holdings
            .filter { $0.asset.kind == .stock || $0.asset.kind == .etf }
            .compactMap { $0.marketValue?.amount }
            .reduce(0, +)
    }

    /// Distinct account names where any transaction is on a stock/ETF asset,
    /// returned in alphabetical order (matches the JSX's static pill order).
    static func stockAccountNames(from transactions: [PortfolioTransaction]) -> [String] {
        var names: Set<String> = []
        for txn in transactions {
            guard let asset = txn.asset else { continue }
            if asset.kind == .stock || asset.kind == .etf {
                names.insert(txn.account.name)
            }
        }
        return names.sorted()
    }

    // MARK: - Sort

    private static func sorted(_ holdings: [Holding], by sort: StocksSort) -> [Holding] {
        holdings.sorted { a, b in
            let order = compare(a, b, by: sort.column)
            return sort.ascending ? (order == .orderedAscending) : (order == .orderedDescending)
        }
    }

    private static func compare(_ a: Holding, _ b: Holding, by column: StocksSortColumn) -> ComparisonResult {
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
