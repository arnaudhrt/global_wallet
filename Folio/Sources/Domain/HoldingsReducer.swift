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
