import SwiftUI
import SwiftData

/// M6 — Crypto. Owns page state (wallet filter, sort, expansion set) and
/// composes the summary cards, filter bar, and expandable per-asset table.
///
/// Data flow:
/// 1. `@Query` pulls transactions + the latest PriceQuote per asset.
/// 2. If a wallet filter is set, transactions are pre-filtered to that
///    account (same pattern as Stocks). The aggregate row then reflects only
///    that wallet's slice; sub-rows are suppressed (single-wallet rollup is
///    self-explanatory) and an `AccountBadge` is shown on the aggregate row.
/// 3. `HoldingsReducer.reduceByAsset` produces the aggregate rows.
///    `reduceByAssetAndAccount` produces the per-(asset, wallet) sub-rows.
///
/// FX is USD-only in M6 — multi-currency lights up in M10.
struct CryptoScreen: View {
    @Environment(\.theme) private var theme
    @Environment(\.modelContext) private var context

    @Query(sort: \PortfolioTransaction.date, order: .forward)
    private var transactions: [PortfolioTransaction]

    @Query(sort: \PriceQuote.asOf, order: .reverse)
    private var quotes: [PriceQuote]

    @Query private var settings: [AppSettings]

    @Query private var accounts: [Account]

    @State private var selectedWallet: String? = nil
    @State private var sort: CryptoSort = .default
    @State private var expanded: Set<String> = ["BTC", "ETH"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                CryptoSummary(
                    marketValue: summary.marketValue,
                    positionsCount: summary.positionsCount,
                    walletsCount: summary.walletsCount,
                    unrealizedPnL: summary.unrealizedPnL,
                    unrealizedPnLPct: summary.unrealizedPnLPct,
                    stakingYTD: summary.stakingYTD,
                    stakingSubtitle: summary.stakingSubtitle
                )

                CryptoFilterBar(
                    wallets: walletPills,
                    selectedWallet: $selectedWallet,
                    sort: $sort,
                    onExpandAll: expandAll,
                    onCollapseAll: collapseAll,
                    expandControlsEnabled: selectedWallet == nil
                )

                CryptoTable(
                    aggregateRows: aggregateRows,
                    subRowsByAsset: subRowsByAsset,
                    cryptoSubtotalMV: summary.marketValue.amount,
                    footerPnL: summary.unrealizedPnL,
                    footerPnLPct: summary.unrealizedPnLPct,
                    sort: $sort,
                    expanded: expanded,
                    onToggleExpansion: toggleExpansion,
                    scopedAccount: scopedAccount
                )
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(theme.bg)
    }

    // MARK: - Derived state

    private var baseCurrency: String {
        settings.first?.baseCurrency ?? "USD"
    }

    private var scopedAccount: Account? {
        guard let name = selectedWallet else { return nil }
        return accounts.first { $0.name == name }
    }

    /// Wallet pills are built from accounts that hold *any* crypto txn so
    /// the colored Dot can come from the account row directly.
    private var walletPills: [CryptoFilterBar.WalletPill] {
        let names = CryptoRowsBuilder.walletAccountNames(from: transactions)
        let byName = Dictionary(uniqueKeysWithValues: accounts.map { ($0.name, $0) })
        return names.compactMap { name -> CryptoFilterBar.WalletPill? in
            guard let account = byName[name] else { return nil }
            return CryptoFilterBar.WalletPill(name: name, colorHex: account.colorHex)
        }
    }

    private var scopedTransactions: [PortfolioTransaction] {
        guard let name = selectedWallet else { return transactions }
        return transactions.filter { $0.account.name == name }
    }

    private var aggregateHoldings: [Holding] {
        HoldingsReducer.reduceByAsset(
            transactions: scopedTransactions,
            priceFor: priceFor,
            fxAt: { from, to, _ in from == to ? 1 : nil },
            baseCurrency: baseCurrency
        )
    }

    private var aggregateRows: [Holding] {
        CryptoRowsBuilder.filterAndSort(aggregateHoldings, sort: sort)
    }

    /// Per-(asset, account) holdings. Built from the *unscoped* transactions
    /// because the wallet filter, when active, hides sub-rows anyway and we
    /// don't want to pay for this reduction in single-wallet mode.
    private var perWalletHoldings: [Holding] {
        guard selectedWallet == nil else { return [] }
        return HoldingsReducer.reduceByAssetAndAccount(
            transactions: transactions,
            priceFor: priceFor,
            fxAt: { from, to, _ in from == to ? 1 : nil },
            baseCurrency: baseCurrency
        )
    }

    private var subRowsByAsset: [String: [Holding]] {
        var out: [String: [Holding]] = [:]
        for row in aggregateRows {
            let subs = CryptoRowsBuilder.subRows(for: row.asset.symbol, from: perWalletHoldings)
            if !subs.isEmpty { out[row.asset.symbol] = subs }
        }
        return out
    }

    // MARK: - Summary

    private struct Summary {
        let marketValue: Money
        let positionsCount: Int
        let walletsCount: Int
        let unrealizedPnL: Money
        let unrealizedPnLPct: Double?
        let stakingYTD: Money
        let stakingSubtitle: String
    }

    private var summary: Summary {
        let crypto = aggregateHoldings.filter { $0.asset.kind == .crypto }
        let mvTotal = crypto.compactMap { $0.marketValue?.amount }.reduce(Decimal(0), +)
        let costTotal = crypto.map { $0.avgCost.amount * $0.qty }.reduce(Decimal(0), +)
        let pnlAmount = mvTotal - costTotal
        let pnlPct: Double? = {
            guard costTotal > 0 else { return nil }
            let pct = pnlAmount / costTotal * 100
            return Double(truncating: pct as NSDecimalNumber)
        }()
        let wallets = Set(
            scopedTransactions.compactMap { txn -> String? in
                guard let asset = txn.asset, asset.kind == .crypto else { return nil }
                return txn.account.name
            }
        )
        let staking = CryptoRowsBuilder.stakingYTD(from: scopedTransactions)
        let stakingMoney = Money(amount: staking, currency: baseCurrency)
        return Summary(
            marketValue: Money(amount: mvTotal, currency: baseCurrency),
            positionsCount: crypto.count,
            walletsCount: wallets.count,
            unrealizedPnL: Money(amount: pnlAmount, currency: baseCurrency),
            unrealizedPnLPct: pnlPct,
            stakingYTD: stakingMoney,
            stakingSubtitle: stakingSubtitleLine(amount: staking)
        )
    }

    private func stakingSubtitleLine(amount: Decimal) -> String {
        guard amount > 0 else { return "No rewards this year" }
        let tickers = Set(
            scopedTransactions.compactMap { txn -> String? in
                guard txn.type == .stake, let asset = txn.asset, asset.kind == .crypto else { return nil }
                let cal = Calendar(identifier: .gregorian)
                guard cal.component(.year, from: txn.date) == cal.component(.year, from: Date()) else { return nil }
                return asset.symbol
            }
        ).sorted()
        if tickers.isEmpty { return "Staking rewards" }
        return tickers.joined(separator: " + ") + " staking"
    }

    // MARK: - Expansion + quote lookup

    private func expandAll() {
        expanded = Set(aggregateRows.map { $0.asset.symbol })
    }

    private func collapseAll() {
        expanded.removeAll()
    }

    private func toggleExpansion(_ symbol: String) {
        if expanded.contains(symbol) {
            expanded.remove(symbol)
        } else {
            expanded.insert(symbol)
        }
    }

    private func priceFor(asset: Asset) -> Decimal? {
        quotes.first { $0.asset.persistentModelID == asset.persistentModelID }?.amount
    }
}
