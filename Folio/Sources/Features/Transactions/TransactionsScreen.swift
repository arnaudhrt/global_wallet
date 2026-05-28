import SwiftUI
import SwiftData

/// M7 — Transactions. Owns the page-level filter (`selectedType`) and sort
/// state, and composes the summary cards, type filter bar, and dense
/// sortable table. Pure view-of-the-ledger — no derivation beyond filter
/// and sort, which makes this the cheapest of the MVP screens.
///
/// FX is USD-only in M7 — multi-currency summaries light up in M10 when
/// the base-currency picker ships.
struct TransactionsScreen: View {
    @Environment(\.theme) private var theme
    @Environment(AppRouter.self) private var router

    @Query(sort: \PortfolioTransaction.date, order: .reverse)
    private var transactions: [PortfolioTransaction]

    @Query private var settings: [AppSettings]

    @State private var selectedType: TransactionType? = nil
    @State private var sort: TxnSort = .default

    var body: some View {
        ScrollView {
            if transactions.isEmpty {
                EmptyState(
                    icon: "list.bullet.rectangle",
                    headline: "No transactions yet",
                    sub: "Add a buy, sell, deposit, or dividend to get started.",
                    ctaLabel: "Add a transaction",
                    onCTA: { router.showAddSheet = true }
                )
                .frame(maxWidth: .infinity, minHeight: 360)
            } else {
                VStack(alignment: .leading, spacing: 20) {
                    TransactionsSummary(
                        ytdCount: ytdTxns.count,
                        accountsCount: TransactionsRowsBuilder.accountsCount(in: ytdTxns),
                        netInflowsYTD: Money(
                            amount: TransactionsRowsBuilder.netInflowsYTD(from: transactions),
                            currency: baseCurrency
                        ),
                        incomeYTD: Money(
                            amount: TransactionsRowsBuilder.incomeYTD(from: transactions),
                            currency: baseCurrency
                        )
                    )

                    TransactionsFilterBar(selectedType: $selectedType)

                    TransactionsTable(
                        rows: rows,
                        baseCurrency: baseCurrency,
                        sort: $sort
                    )
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(theme.bg)
    }

    // MARK: - Derived state

    private var baseCurrency: String {
        settings.first?.baseCurrency ?? "USD"
    }

    private var ytdTxns: [PortfolioTransaction] {
        TransactionsRowsBuilder.transactionsYTD(from: transactions)
    }

    private var rows: [PortfolioTransaction] {
        TransactionsRowsBuilder.filterAndSort(transactions, type: selectedType, sort: sort)
    }
}
