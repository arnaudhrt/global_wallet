import Foundation

/// Sort columns offered on the Transactions screen. The right-most "···"
/// column is intentionally absent — it's an action affordance, not a sort
/// target.
enum TxnSortColumn: String, CaseIterable, Hashable {
    case date
    case type
    case asset
    case qty
    case price
    case total
    case account

    var label: String {
        switch self {
        case .date:    return "Date"
        case .type:    return "Type"
        case .asset:   return "Asset"
        case .qty:     return "Qty"
        case .price:   return "Price"
        case .total:   return "Total"
        case .account: return "Account"
        }
    }
}

struct TxnSort: Equatable {
    var column: TxnSortColumn
    var ascending: Bool

    /// Newest first — matches the prototype's natural transaction ordering.
    static let `default` = TxnSort(column: .date, ascending: false)
}

/// Pure filter+sort + YTD aggregates over `[PortfolioTransaction]`. Lives
/// outside the view so it's testable without spinning up SwiftUI; mirrors
/// the M5 (`StocksRowsBuilder`) and M6 (`CryptoRowsBuilder`) shape.
@MainActor
enum TransactionsRowsBuilder {
    static func filterAndSort(
        _ txns: [PortfolioTransaction],
        type: TransactionType?,
        sort: TxnSort
    ) -> [PortfolioTransaction] {
        let filtered: [PortfolioTransaction] = {
            guard let type else { return txns }
            return txns.filter { $0.type == type }
        }()
        return sorted(filtered, by: sort)
    }

    // MARK: - YTD aggregates

    /// Transactions whose year matches `now`'s year in the gregorian calendar.
    static func transactionsYTD(
        from txns: [PortfolioTransaction],
        now: Date = Date()
    ) -> [PortfolioTransaction] {
        let cal = Calendar(identifier: .gregorian)
        let year = cal.component(.year, from: now)
        return txns.filter { cal.component(.year, from: $0.date) == year }
    }

    /// Σ(sell + dividend + deposit) − Σ(buy + withdraw). Stake and Transfer
    /// are net-neutral (no cash in or out of the portfolio perimeter).
    /// Assumes all amounts are in the user's base currency — multi-currency
    /// FX in summaries lights up in M10.
    static func netInflowsYTD(
        from txns: [PortfolioTransaction],
        now: Date = Date()
    ) -> Decimal {
        let ytd = transactionsYTD(from: txns, now: now)
        let inflows = ytd
            .filter { $0.type == .sell || $0.type == .dividend || $0.type == .deposit }
            .reduce(Decimal(0)) { $0 + $1.amount }
        let outflows = ytd
            .filter { $0.type == .buy || $0.type == .withdraw }
            .reduce(Decimal(0)) { $0 + $1.amount }
        return inflows - outflows
    }

    /// Σ(dividend + stake) for the current year. Mirrors how M5 computes
    /// Dividends YTD and M6 computes Staking YTD — combined here.
    static func incomeYTD(
        from txns: [PortfolioTransaction],
        now: Date = Date()
    ) -> Decimal {
        transactionsYTD(from: txns, now: now)
            .filter { $0.type == .dividend || $0.type == .stake }
            .reduce(Decimal(0)) { $0 + $1.amount }
    }

    /// Distinct `account.name` count across the input set.
    static func accountsCount(in txns: [PortfolioTransaction]) -> Int {
        Set(txns.map { $0.account.name }).count
    }

    // MARK: - Sort

    private static func sorted(_ txns: [PortfolioTransaction], by sort: TxnSort) -> [PortfolioTransaction] {
        txns.sorted { a, b in
            let order = compare(a, b, by: sort.column)
            return sort.ascending ? (order == .orderedAscending) : (order == .orderedDescending)
        }
    }

    private static func compare(_ a: PortfolioTransaction, _ b: PortfolioTransaction, by column: TxnSortColumn) -> ComparisonResult {
        switch column {
        case .date:
            if a.date < b.date { return .orderedAscending }
            if a.date > b.date { return .orderedDescending }
            return .orderedSame
        case .type:
            return a.type.rawValue.compare(b.type.rawValue)
        case .asset:
            return stringCompare(a.asset?.symbol, b.asset?.symbol)
        case .qty:
            return decimalCompare(a.quantity, b.quantity)
        case .price:
            return decimalCompare(a.price, b.price)
        case .total:
            if a.amount < b.amount { return .orderedAscending }
            if a.amount > b.amount { return .orderedDescending }
            return .orderedSame
        case .account:
            return a.account.name.compare(b.account.name)
        }
    }

    /// `nil` sorts below any real value in either direction — missing
    /// asset/qty/price sink to the bottom regardless of asc/desc.
    private static func stringCompare(_ a: String?, _ b: String?) -> ComparisonResult {
        switch (a, b) {
        case let (a?, b?): return a.compare(b)
        case (nil, nil):   return .orderedSame
        case (nil, _):     return .orderedAscending
        case (_, nil):     return .orderedDescending
        }
    }

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
}
