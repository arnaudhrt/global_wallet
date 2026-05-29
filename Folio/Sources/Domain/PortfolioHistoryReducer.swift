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

        // Net external cash flow accumulated since the previous emitted point.
        // Reset after each point so every point carries only the flows that
        // landed in its own sub-period.
        var flowSincePrev = Decimal(0)

        for date in sortedDates {
            while txnCursor < sortedTxns.count, sortedTxns[txnCursor].date <= date {
                let txn = sortedTxns[txnCursor]
                apply(txn, to: &qtyByAsset)
                flowSincePrev += externalFlow(txn, baseCurrency: baseCurrency, fxAt: fxAt)
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
                total: Money(amount: total, currency: baseCurrency),
                netFlow: Money(amount: flowSincePrev, currency: baseCurrency)
            ))
            flowSincePrev = 0
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

    /// Net external cash flow this transaction injects into (buy, +) or removes
    /// from (sell, −) the asset-value pool, expressed in `baseCurrency` at the
    /// transaction's own date. Used to neutralize contributions in TWR.
    ///
    /// Only `buy`/`sell` are external flows. `stake` adds qty but is return-in-
    /// kind (staking yield), so it's deliberately *not* a flow — its value bump
    /// is real performance. `dividend`/`deposit`/`withdraw`/`transfer` don't
    /// touch asset qty. When the txn currency differs from base and no FX rate
    /// is available for that date, falls back to 1 (same forgiving posture as
    /// the value path) rather than dropping the flow entirely.
    private static func externalFlow(
        _ txn: PortfolioTransaction,
        baseCurrency: String,
        fxAt: (_ from: String, _ to: String, _ date: Date) -> Decimal?
    ) -> Decimal {
        let signed: Decimal
        switch txn.type {
        case .buy: signed = txn.amount
        case .sell: signed = -txn.amount
        case .stake, .dividend, .deposit, .withdraw, .transfer: return 0
        }
        let fx = txn.currency == baseCurrency ? Decimal(1) : (fxAt(txn.currency, baseCurrency, txn.date) ?? Decimal(1))
        return signed * fx
    }
}

struct HistoryPoint: Equatable, Sendable {
    let date: Date
    let total: Money
    /// Net external cash flow attributed to this point, in the base currency:
    /// money added by buys minus proceeds removed by sells, summed over the
    /// transactions applied since the previous point in the series. Used to
    /// neutralize contributions when computing time-weighted return
    /// (`PortfolioMetrics.timeWeightedReturn`). Stake/dividend/deposit/withdraw/
    /// transfer events are *not* flows here — staking yield is return-in-kind,
    /// and cash events don't touch the asset-value pool the series tracks.
    /// Defaults to zero so callers/tests that don't care about flows are
    /// unaffected (and TWR over a zero-flow series telescopes to plain
    /// value-change).
    let netFlow: Money

    init(date: Date, total: Money, netFlow: Money? = nil) {
        self.date = date
        self.total = total
        self.netFlow = netFlow ?? Money(amount: 0, currency: total.currency)
    }
}
