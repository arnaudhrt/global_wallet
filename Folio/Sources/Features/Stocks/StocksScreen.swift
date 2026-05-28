import SwiftUI
import SwiftData

/// M5 — Stocks & ETFs. Owns the page-level state (account filter, sort) and
/// composes the summary cards, filter bar, and dense sortable table.
///
/// Data flow:
/// 1. `@Query` pulls transactions (sorted by date) + the latest PriceQuote per
///    asset (we read them in descending `asOf` order and pick `first` per asset).
/// 2. If an account filter is set, transactions are pre-filtered to that account
///    so dividends, summary totals, and table rows all stay scoped consistently.
/// 3. `HoldingsReducer.reduceByAsset` turns transactions into Holdings; the
///    builder filters to stocks/ETFs and applies the requested sort.
///
/// FX is USD-only in M5 — multi-currency lights up in M10 when the base-currency
/// picker ships.
struct StocksScreen: View {
    @Environment(\.theme) private var theme
    @Environment(\.modelContext) private var context
    @Environment(AppRouter.self) private var router

    @Query(sort: \PortfolioTransaction.date, order: .forward)
    private var transactions: [PortfolioTransaction]

    @Query(sort: \PriceQuote.asOf, order: .reverse)
    private var quotes: [PriceQuote]

    @Query private var settings: [AppSettings]

    @Query private var fxRates: [FXRate]

    @State private var selectedAccount: String? = nil
    @State private var sort: StocksSort = .default

    var body: some View {
        ScrollView {
            if !hasAnyStockTxn {
                EmptyState(
                    icon: "chart.line.uptrend.xyaxis",
                    headline: "No positions yet",
                    sub: "Add a buy for a stock or ETF to see it here.",
                    ctaLabel: "Add a transaction",
                    onCTA: { router.showAddSheet = true }
                )
                .frame(maxWidth: .infinity, minHeight: 360)
            } else {
                VStack(alignment: .leading, spacing: 20) {
                    StocksSummary(
                        marketValue: summary.marketValue,
                        positionsCount: summary.positionsCount,
                        brokersCount: summary.brokersCount,
                        unrealizedPnL: summary.unrealizedPnL,
                        unrealizedPnLPct: summary.unrealizedPnLPct,
                        dividendsYTD: summary.dividendsYTD,
                        lastDividend: summary.lastDividend
                    )

                    StocksFilterBar(
                        accountNames: accountNames,
                        selectedAccount: $selectedAccount,
                        sort: $sort
                    )

                    StocksTable(
                        rows: rows,
                        totalMarketValue: summary.marketValue.amount,
                        footerPnL: summary.unrealizedPnL,
                        footerPnLPct: summary.unrealizedPnLPct,
                        sort: $sort
                    )
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(theme.bg)
    }

    private var hasAnyStockTxn: Bool {
        transactions.contains { txn in
            guard let kind = txn.asset?.kind else { return false }
            return kind == .stock || kind == .etf
        }
    }

    // MARK: - Derived state

    private var baseCurrency: String {
        settings.first?.baseCurrency ?? "USD"
    }

    private var accountNames: [String] {
        StocksRowsBuilder.stockAccountNames(from: transactions)
    }

    private var scopedTransactions: [PortfolioTransaction] {
        guard let accountName = selectedAccount else { return transactions }
        return transactions.filter { $0.account.name == accountName }
    }

    private var allHoldings: [Holding] {
        HoldingsReducer.reduceByAsset(
            transactions: scopedTransactions,
            priceFor: priceFor,
            fxAt: FXLookup.fxAt(rates: fxRates),
            baseCurrency: baseCurrency
        )
    }

    private var rows: [Holding] {
        StocksRowsBuilder.filterAndSort(allHoldings, sort: sort)
    }

    private struct Summary {
        let marketValue: Money
        let positionsCount: Int
        let brokersCount: Int
        let unrealizedPnL: Money
        let unrealizedPnLPct: Double?
        let dividendsYTD: Money
        let lastDividend: (ticker: String, amount: Money)?
    }

    private var summary: Summary {
        let stocks = allHoldings.filter { $0.asset.kind == .stock || $0.asset.kind == .etf }
        let mvTotal = stocks.compactMap { $0.marketValue?.amount }.reduce(Decimal(0), +)
        let costTotal = stocks.map { $0.avgCost.amount * $0.qty }.reduce(Decimal(0), +)
        let pnlAmount = mvTotal - costTotal
        let pnlPct: Double? = {
            guard costTotal > 0 else { return nil }
            let pct = pnlAmount / costTotal * 100
            return Double(truncating: pct as NSDecimalNumber)
        }()
        let brokers = Set(
            scopedTransactions.compactMap { txn -> String? in
                guard let asset = txn.asset, asset.kind == .stock || asset.kind == .etf else { return nil }
                return txn.account.name
            }
        )

        return Summary(
            marketValue: Money(amount: mvTotal, currency: baseCurrency),
            positionsCount: stocks.count,
            brokersCount: brokers.count,
            unrealizedPnL: Money(amount: pnlAmount, currency: baseCurrency),
            unrealizedPnLPct: pnlPct,
            dividendsYTD: dividendsYTDMoney(),
            lastDividend: latestStockDividend()
        )
    }

    // MARK: - Dividends YTD

    private func dividendsYTDMoney() -> Money {
        let currentYear = Calendar(identifier: .gregorian).component(.year, from: Date())
        let cal = Calendar(identifier: .gregorian)
        let amount = scopedTransactions
            .filter { txn in
                guard txn.type == .dividend, let asset = txn.asset else { return false }
                guard asset.kind == .stock || asset.kind == .etf else { return false }
                return cal.component(.year, from: txn.date) == currentYear
            }
            .reduce(Decimal(0)) { $0 + $1.amount }
        return Money(amount: amount, currency: baseCurrency)
    }

    private func latestStockDividend() -> (ticker: String, amount: Money)? {
        let dividend = scopedTransactions
            .filter { txn in
                guard txn.type == .dividend, let asset = txn.asset else { return false }
                return asset.kind == .stock || asset.kind == .etf
            }
            .max(by: { $0.date < $1.date })
        guard let dividend, let asset = dividend.asset else { return nil }
        return (asset.symbol, Money(amount: dividend.amount, currency: dividend.currency))
    }

    // MARK: - Quote lookup

    /// Most recent PriceQuote for an asset, irrespective of source. Since
    /// `quotes` is sorted by `asOf` descending, `first` matching is enough.
    private func priceFor(asset: Asset) -> Decimal? {
        quotes.first { $0.asset.persistentModelID == asset.persistentModelID }?.amount
    }
}
