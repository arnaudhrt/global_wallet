import SwiftUI
import SwiftData

/// M8 — Overview dashboard. Composes the 4-card summary, chart placeholder
/// (M8.5 fills it in), and the bottom row of Allocation + Annual Performance.
///
/// Data flow mirrors M5/M6: `@Query` pulls transactions + the latest PriceQuote
/// per asset; `HoldingsReducer.reduceByAsset` produces holdings; metrics are
/// rolled up via `PortfolioMetrics` and `OverviewMetricsBuilder`. FX is USD-only
/// until M10's base-currency picker lands.
struct OverviewScreen: View {
    @Environment(\.theme) private var theme

    @Query(sort: \PortfolioTransaction.date, order: .forward)
    private var transactions: [PortfolioTransaction]

    @Query(sort: \PriceQuote.asOf, order: .reverse)
    private var quotes: [PriceQuote]

    @Query private var settings: [AppSettings]

    @State private var range: String = "1Y"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                OverviewSummary(
                    totalValue: totalValue,
                    positionsCount: positionsCount,
                    accountsCount: accountsCount,
                    allTimeGain: allTimeGain,
                    allTimeGainPct: allTimeGainPct,
                    earliestTransactionDate: earliestDate,
                    investedCapital: investedCapital
                )

                OverviewChartCard(range: $range)

                HStack(alignment: .top, spacing: 14) {
                    AllocationCard(entries: allocationEntries)
                        .frame(maxWidth: .infinity)

                    AnnualPerformanceCard()
                        .frame(maxWidth: .infinity)
                }
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

    private var holdings: [Holding] {
        HoldingsReducer.reduceByAsset(
            transactions: transactions,
            priceFor: priceFor,
            fxAt: { from, to, _ in from == to ? 1 : nil },
            baseCurrency: baseCurrency
        )
    }

    private var totalValue: Money {
        PortfolioMetrics.totalValue(holdings, baseCurrency: baseCurrency)
    }

    private var investedCapital: Money {
        PortfolioMetrics.investedCapital(holdings, baseCurrency: baseCurrency)
    }

    private var allTimeGain: Money {
        PortfolioMetrics.gainAllTime(holdings, baseCurrency: baseCurrency)
    }

    private var allTimeGainPct: Double? {
        let invested = investedCapital.amount
        guard invested > 0 else { return nil }
        let pct = allTimeGain.amount / invested * 100
        return Double(truncating: pct as NSDecimalNumber)
    }

    private var positionsCount: Int {
        OverviewMetricsBuilder.positionsCount(holdings)
    }

    private var accountsCount: Int {
        OverviewMetricsBuilder.accountsCount(from: transactions)
    }

    private var earliestDate: Date? {
        OverviewMetricsBuilder.earliestTransactionDate(from: transactions)
    }

    private var allocationEntries: [OverviewMetricsBuilder.AllocationEntry] {
        OverviewMetricsBuilder.allocation(holdings, baseCurrency: baseCurrency)
    }

    private func priceFor(asset: Asset) -> Decimal? {
        quotes.first { $0.asset.persistentModelID == asset.persistentModelID }?.amount
    }
}
