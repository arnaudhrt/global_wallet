import Foundation
import SwiftData

/// Projects a ledger of `PortfolioTransaction`s into computed `Holding` rows.
///
/// Cost basis is **weighted average** — `.buy` and `.stake` add to qty and
/// cost; `.sell` reduces qty but leaves the per-share average untouched.
/// `.dividend` is income (no qty/basis change). Cash events (`.deposit`,
/// `.withdraw`, `.transfer`) don't touch holdings.
///
/// `priceFor` and `fxAt` are closures so M4's `QuoteProvider` can plug in
/// without touching this file. M3 wires `priceFor` to seeded `PriceQuote` rows
/// and `fxAt` to a single-currency stub.
@MainActor
enum HoldingsReducer {
    /// One row per Asset; sums qty across all accounts; weighted-average cost.
    static func reduceByAsset(
        transactions: [PortfolioTransaction],
        priceFor: (Asset) -> Decimal?,
        fxAt: (_ from: String, _ to: String, _ date: Date) -> Decimal?,
        baseCurrency: String
    ) -> [Holding] {
        reduce(
            transactions: transactions,
            priceFor: priceFor,
            fxAt: fxAt,
            baseCurrency: baseCurrency,
            perAccount: false
        )
    }

    /// One row per (Asset, Account) pair. Used by the Crypto expand-per-wallet
    /// view.
    static func reduceByAssetAndAccount(
        transactions: [PortfolioTransaction],
        priceFor: (Asset) -> Decimal?,
        fxAt: (_ from: String, _ to: String, _ date: Date) -> Decimal?,
        baseCurrency: String
    ) -> [Holding] {
        reduce(
            transactions: transactions,
            priceFor: priceFor,
            fxAt: fxAt,
            baseCurrency: baseCurrency,
            perAccount: true
        )
    }

    /// All-time ledger totals used by the Overview "All-time Gain" card.
    /// Walks the whole transaction history once and accumulates:
    ///
    /// - `realizedPnL` — gain locked in by `.sell`s: `proceeds − sellQty ×
    ///   weighted-avg-cost-before-sale`, in base currency. Mirrors the same
    ///   over-sell clamp as `reduce`. (Unrealized P&L on *open* positions is
    ///   computed separately from `[Holding]`; this is the realized half that
    ///   the holdings projection throws away.)
    /// - `dividendIncome` — sum of `.dividend` cash amounts.
    /// - `stakingIncome` — sum of `.stake` receipt values. Staking is also
    ///   booked into cost basis (like a buy at the receipt price), so this
    ///   income line captures the *free receipt* while realized/unrealized
    ///   capture only subsequent price moves — no double-count.
    /// - `totalInvested` — gross cost of all `.buy`s ever (not reduced by
    ///   sells, excludes staking). Denominator for the all-time return %.
    ///
    /// FX is taken at each transaction's own date (so realized gains include
    /// currency moves, consistent with the cost-vs-market FX treatment in
    /// `reduce`). Transactions whose currency can't be converted are skipped
    /// with a warning, matching `reduce`'s posture.
    static func allTimeBreakdown(
        transactions: [PortfolioTransaction],
        fxAt: (_ from: String, _ to: String, _ date: Date) -> Decimal?,
        baseCurrency: String
    ) -> AllTimeBreakdown {
        var costByAsset: [PersistentIdentifier: (qty: Decimal, cost: Decimal)] = [:]
        var out = AllTimeBreakdown(realizedPnL: 0, dividendIncome: 0, stakingIncome: 0, totalInvested: 0)

        for txn in transactions.sorted(by: { $0.date < $1.date }) {
            let fx: Decimal
            if txn.currency == baseCurrency {
                fx = 1
            } else if let rate = fxAt(txn.currency, baseCurrency, txn.date) {
                fx = rate
            } else {
                FolioLog.holdings.warning("missing FX \(txn.currency, privacy: .public)→\(baseCurrency, privacy: .public) on \(txn.date, privacy: .public) — skipping txn in all-time breakdown")
                continue
            }

            switch txn.type {
            case .buy, .stake:
                guard let asset = txn.asset, let qty = txn.quantity, let price = txn.price else { break }
                let lineCost = qty * price * fx
                var b = costByAsset[asset.persistentModelID] ?? (qty: 0, cost: 0)
                b.qty += qty
                b.cost += lineCost
                costByAsset[asset.persistentModelID] = b
                if txn.type == .buy { out.totalInvested += lineCost } else { out.stakingIncome += lineCost }
            case .sell:
                guard let asset = txn.asset, let qty = txn.quantity, let price = txn.price else { break }
                var b = costByAsset[asset.persistentModelID] ?? (qty: 0, cost: 0)
                guard b.qty > 0 else { break }
                let sellQty = min(qty, b.qty)
                let avgBefore = b.cost / b.qty
                let proceeds = sellQty * price * fx
                out.realizedPnL += proceeds - sellQty * avgBefore
                b.qty -= sellQty
                b.cost -= sellQty * avgBefore
                costByAsset[asset.persistentModelID] = b
            case .dividend:
                out.dividendIncome += txn.amount * fx
            case .deposit, .withdraw, .transfer:
                break
            }
        }
        return out
    }

    // MARK: - Internal

    private struct BucketKey: Hashable {
        let asset: PersistentIdentifier
        let account: PersistentIdentifier?
    }

    private struct Bucket {
        let asset: Asset
        let account: Account?
        var qty: Decimal
        var cost: Decimal
    }

    private static func reduce(
        transactions: [PortfolioTransaction],
        priceFor: (Asset) -> Decimal?,
        fxAt: (_ from: String, _ to: String, _ date: Date) -> Decimal?,
        baseCurrency: String,
        perAccount: Bool
    ) -> [Holding] {
        var buckets: [BucketKey: Bucket] = [:]

        for txn in transactions.sorted(by: { $0.date < $1.date }) {
            guard let asset = txn.asset, let qty = txn.quantity, let price = txn.price else { continue }

            let fx: Decimal
            if txn.currency == baseCurrency {
                fx = 1
            } else if let rate = fxAt(txn.currency, baseCurrency, txn.date) {
                fx = rate
            } else {
                FolioLog.holdings.warning("missing FX \(txn.currency, privacy: .public)→\(baseCurrency, privacy: .public) on \(txn.date, privacy: .public) — skipping txn")
                continue
            }

            let lineCost = qty * price * fx
            let key = BucketKey(
                asset: asset.persistentModelID,
                account: perAccount ? txn.account.persistentModelID : nil
            )
            var bucket = buckets[key] ?? Bucket(
                asset: asset,
                account: perAccount ? txn.account : nil,
                qty: 0,
                cost: 0
            )
            switch txn.type {
            case .buy, .stake:
                bucket.qty  += qty
                bucket.cost += lineCost
            case .sell:
                // Standard weighted-avg: reduce qty and cost proportionally so
                // the per-share avg-cost is preserved across the sale. Sells
                // larger than current qty are clamped at zero — going short
                // isn't modeled in MVP and a negative-qty bucket would make
                // the basis math undefined for any subsequent buy.
                if bucket.qty > 0 {
                    let sellQty = min(qty, bucket.qty)
                    if sellQty < qty {
                        FolioLog.holdings.warning("over-sell on \(asset.symbol, privacy: .public) — sold \(qty.description, privacy: .public), only \(bucket.qty.description, privacy: .public) held; clamping")
                    }
                    let avgBefore = bucket.cost / bucket.qty
                    bucket.qty  -= sellQty
                    bucket.cost -= sellQty * avgBefore
                } else {
                    FolioLog.holdings.warning("sell on \(asset.symbol, privacy: .public) with no holdings — ignoring")
                }
            case .dividend, .deposit, .withdraw, .transfer:
                break
            }
            buckets[key] = bucket
        }

        return buckets.values.compactMap { bucket in
            guard bucket.qty > 0 else { return nil }
            let avgCostAmount = bucket.cost / bucket.qty
            let avgCost = Money(amount: avgCostAmount, currency: baseCurrency)

            let marketValue: Money? = priceFor(bucket.asset).map {
                Money(amount: $0 * bucket.qty, currency: baseCurrency)
            }
            let pnl: Money? = marketValue.map { Money(amount: $0.amount - bucket.cost, currency: baseCurrency) }
            let pnlPct: Double? = {
                guard let mv = marketValue, bucket.cost > 0 else { return nil }
                let pct = (mv.amount - bucket.cost) / bucket.cost * 100
                return Double(truncating: pct as NSDecimalNumber)
            }()

            return Holding(
                id: Holding.ID(
                    assetID: bucket.asset.persistentModelID,
                    accountID: bucket.account?.persistentModelID
                ),
                asset: bucket.asset,
                account: bucket.account,
                qty: bucket.qty,
                avgCost: avgCost,
                marketValue: marketValue,
                unrealizedPnL: pnl,
                unrealizedPnLPct: pnlPct
            )
        }
    }
}

/// All-time ledger totals produced by `HoldingsReducer.allTimeBreakdown`.
/// Amounts are in the portfolio's base currency.
struct AllTimeBreakdown: Equatable, Sendable {
    var realizedPnL: Decimal
    var dividendIncome: Decimal
    var stakingIncome: Decimal
    var totalInvested: Decimal

    /// Realized capital gains + dividend + staking income — the "closed" half
    /// of total return that `[Holding]` (open positions only) can't see.
    var realizedPlusIncome: Decimal { realizedPnL + dividendIncome + stakingIncome }
}
