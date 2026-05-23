import Foundation
import SwiftData

/// Time-series sibling of `HoldingsReducer`. Walks `transactions` chronologically
/// and, for each date in `dates`, emits the portfolio's total value in the base
/// currency at that day's prices.
///
/// `priceOn(asset, date)` returns the asset's close on `date` (with forward-fill
/// already applied — see `HistoricalLookups`). `fxAt(from, to, date)` returns
/// the rate on `date`. Missing prices/FX for an asset on a given day cause that
/// asset to contribute zero to that day's total; the rest of the portfolio is
/// unaffected.
///
/// Same `@MainActor enum` posture as `HoldingsReducer` so call sites in
/// `OverviewScreen` don't have to switch contexts. Pure function — no SwiftData
/// reads from inside the reducer.
@MainActor
enum PortfolioHistoryReducer {
    static func series(
        transactions: [PortfolioTransaction],
        dates: [Date],
        priceOn: (Asset, Date) -> Decimal?,
        fxAt: (_ from: String, _ to: String, _ date: Date) -> Decimal?,
        baseCurrency: String
    ) -> [HistoryPoint] {
        guard !dates.isEmpty else { return [] }

        let sortedDates = dates.sorted()
        let sortedTxns = transactions.sorted(by: { $0.date < $1.date })

        // Per-asset rolling qty state, updated as we cross transactions
        // chronologically. Mirrors the bucket math in HoldingsReducer:96-119
        // but only tracks qty (we don't need cost basis for market-value math).
        var qtyByAsset: [PersistentIdentifier: AssetState] = [:]
        var txnCursor = 0

        var points: [HistoryPoint] = []
        points.reserveCapacity(sortedDates.count)

        for date in sortedDates {
            while txnCursor < sortedTxns.count, sortedTxns[txnCursor].date <= date {
                apply(sortedTxns[txnCursor], to: &qtyByAsset)
                txnCursor += 1
            }

            var total = Decimal(0)
            for state in qtyByAsset.values where state.qty > 0 {
                guard
                    let price = priceOn(state.asset, date),
                    let fx = (state.asset.currency == baseCurrency) ? Decimal(1) : fxAt(state.asset.currency, baseCurrency, date)
                else {
                    continue
                }
                total += state.qty * price * fx
            }
            points.append(HistoryPoint(
                date: date,
                total: Money(amount: total, currency: baseCurrency)
            ))
        }

        return points
    }

    /// Returns a list of UTC midnights from `floor` through `now`, one per day.
    /// Useful default for the `dates` parameter on `series()`.
    static func dailyDates(from floor: Date, through now: Date = .now) -> [Date] {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC") ?? .current
        let start = cal.startOfDay(for: floor)
        let end = cal.startOfDay(for: now)
        guard start <= end else { return [] }
        var out: [Date] = []
        var cursor = start
        while cursor <= end {
            out.append(cursor)
            guard let next = cal.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return out
    }

    // MARK: - Internal

    private struct AssetState {
        let asset: Asset
        var qty: Decimal
    }

    private static func apply(_ txn: PortfolioTransaction, to buckets: inout [PersistentIdentifier: AssetState]) {
        guard let asset = txn.asset, let qty = txn.quantity, qty > 0 else { return }
        let id = asset.persistentModelID
        var state = buckets[id] ?? AssetState(asset: asset, qty: 0)
        switch txn.type {
        case .buy, .stake:
            state.qty += qty
        case .sell:
            // Same over-sell clamp as HoldingsReducer:107 — going short isn't
            // modeled in MVP, so we never let qty go negative.
            state.qty = max(0, state.qty - qty)
        case .dividend, .deposit, .withdraw, .transfer:
            break
        }
        buckets[id] = state
    }
}

struct HistoryPoint: Equatable, Sendable {
    let date: Date
    let total: Money
}
