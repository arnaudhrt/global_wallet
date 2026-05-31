import SwiftUI
import SwiftData

/// M8 — Overview dashboard, with M8.5 wiring the chart, YTD%, and per-year
/// performance table to real historical data.
///
/// Data flow:
/// - Current holdings + spot quotes drive the summary cards + allocation card
///   (unchanged from M8).
/// - Historical quotes + FX rates drive the chart, YTD%, and Annual table
///   (M8.5). `HistoricalQuoteService.ensureLoaded` is called from `.task(id:)`
///   on the selected range; the service is idempotent so range switches only
///   fetch what's missing.
struct OverviewScreen: View {
    @Environment(\.theme) private var theme
    @Environment(HistoricalQuoteService.self) private var historicalService
    @Environment(AppRouter.self) private var router

    @Query(sort: \PortfolioTransaction.date, order: .forward)
    private var transactions: [PortfolioTransaction]

    @Query(sort: \PriceQuote.asOf, order: .reverse)
    private var quotes: [PriceQuote]

    @Query(sort: \HistoricalQuote.date, order: .forward)
    private var historicalQuotes: [HistoricalQuote]

    @Query(sort: \FXRate.asOf, order: .forward)
    private var fxRates: [FXRate]

    @Query private var settings: [AppSettings]
    @Query private var assets: [Asset]

    @State private var range: String = "1Y"

    var body: some View {
        ScrollView {
            if transactions.isEmpty {
                EmptyState(
                    icon: "chart.pie",
                    headline: "Welcome to Folio",
                    sub: "Add your first transaction — buys, deposits, dividends — to see your portfolio here.",
                    ctaLabel: "Add a transaction",
                    onCTA: { router.showAddSheet = true }
                )
                .frame(maxWidth: .infinity, minHeight: 480)
            } else {
                VStack(alignment: .leading, spacing: 20) {
                    OverviewSummary(
                        totalValue: totalValue,
                        accountsCount: accountsCount,
                        allTimeGain: allTimeGain,
                        allTimeGainPct: allTimeGainPct,
                        earliestTransactionDate: earliestDate,
                        investedCapital: investedCapital,
                        ytdPct: ytdPct
                    )

                    OverviewChartCard(
                        range: $range,
                        series: chartSeries,
                        isLoading: historicalService.isFetching
                    )

                    HStack(alignment: .top, spacing: 14) {
                        AllocationCard(entries: allocationEntries)
                            .frame(maxWidth: .infinity)

                        AnnualPerformanceCard(rows: annualRows)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(theme.bg)
        .task(id: range) {
            guard let rangeEnum = QuoteRange(pill: range) else { return }
            await historicalService.ensureLoaded(
                assets: chartAssets,
                baseCurrency: baseCurrency,
                range: rangeEnum
            )
        }
    }

    // MARK: - Derived state

    private var baseCurrency: String {
        settings.first?.baseCurrency ?? "USD"
    }

    private var holdings: [Holding] {
        HoldingsReducer.reduceByAsset(
            transactions: transactions,
            priceFor: priceFor,
            fxAt: FXLookup.fxAt(rates: fxRates),
            baseCurrency: baseCurrency
        )
    }

    private var totalValue: Money {
        PortfolioMetrics.totalValue(holdings, baseCurrency: baseCurrency)
    }

    private var investedCapital: Money {
        PortfolioMetrics.investedCapital(holdings, baseCurrency: baseCurrency)
    }

    /// Total return: unrealized (open positions) + realized (past sells) +
    /// income (dividends + staking). See `PortfolioMetrics.allTimeGain`.
    private var allTimeGainResult: PortfolioMetrics.AllTimeGain {
        PortfolioMetrics.allTimeGain(
            holdings: holdings,
            transactions: transactions,
            fxAt: FXLookup.fxAt(rates: fxRates),
            baseCurrency: baseCurrency
        )
    }

    private var allTimeGain: Money { allTimeGainResult.total }

    private var allTimeGainPct: Double? { allTimeGainResult.pct }

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

    // MARK: - Historical chart

    /// Assets actually represented in the ledger — we only fetch history for
    /// what the user holds (or held).
    private var chartAssets: [Asset] {
        let ids = Set(transactions.compactMap { $0.asset?.persistentModelID })
        return assets.filter { ids.contains($0.persistentModelID) }
    }

    private var chartSeries: [HistoryPoint] {
        guard let rangeEnum = QuoteRange(pill: range) else { return [] }
        let now = Date()
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC") ?? .current
        let rangeFloor = cal.date(byAdding: .day, value: -rangeEnum.days(now: now), to: cal.startOfDay(for: now)) ?? now
        // Clamp the left edge to the first transaction. There's nothing to chart
        // before the portfolio existed, and a floor that predates it (e.g. "All"
        // = now − 10y) draws a flat $0 line that ramps up at the first buy. The
        // Annual table already clamps the same way (see `annualRows`).
        let floor: Date
        if let earliest = earliestDate, earliest > rangeFloor {
            floor = cal.startOfDay(for: earliest)
        } else {
            floor = rangeFloor
        }
        // Sample density follows the *actual* charted span, not the nominal
        // range — a freshly-started portfolio on "All" still gets daily detail.
        // Daily for ≤ 3 months, weekly otherwise, to keep the chart responsive.
        let spanDays = cal.dateComponents([.day], from: floor, to: cal.startOfDay(for: now)).day ?? rangeEnum.days(now: now)
        let stride = spanDays <= 90 ? 1 : 7
        let dates = stridedDates(from: floor, to: now, every: stride, calendar: cal)
        return PortfolioHistoryReducer.series(
            transactions: transactions,
            dates: dates,
            priceOn: HistoricalLookups.priceOn(quotes: historicalQuotes),
            fxAt: HistoricalLookups.fxAt(rates: fxRates),
            baseCurrency: baseCurrency
        )
    }

    private var ytdPct: Double? {
        PortfolioMetrics.ytdPerformance(history: ytdSeries)
    }

    /// Slim series spanning the full year for YTD%. Sampled weekly to stay
    /// cheap regardless of the currently-selected chart range.
    private var ytdSeries: [HistoryPoint] {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC") ?? .current
        let now = Date()
        let year = cal.component(.year, from: now)
        guard let jan1 = cal.date(from: DateComponents(year: year, month: 1, day: 1)) else { return [] }
        let dates = stridedDates(from: jan1, to: now, every: 7, calendar: cal)
        return PortfolioHistoryReducer.series(
            transactions: transactions,
            dates: dates,
            priceOn: HistoricalLookups.priceOn(quotes: historicalQuotes),
            fxAt: HistoricalLookups.fxAt(rates: fxRates),
            baseCurrency: baseCurrency
        )
    }

    private var annualRows: [AnnualPerformanceRow] {
        // Annual table walks the whole on-record series. We sample weekly
        // because year-over-year deltas don't need daily resolution.
        guard let earliest = earliestDate else { return [] }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC") ?? .current
        let dates = stridedDates(from: earliest, to: Date(), every: 7, calendar: cal)
        let history = PortfolioHistoryReducer.series(
            transactions: transactions,
            dates: dates,
            priceOn: HistoricalLookups.priceOn(quotes: historicalQuotes),
            fxAt: HistoricalLookups.fxAt(rates: fxRates),
            baseCurrency: baseCurrency
        )
        return AnnualPerformanceBuilder.rows(history: history)
    }

    private func stridedDates(from start: Date, to end: Date, every days: Int, calendar: Calendar) -> [Date] {
        let s = calendar.startOfDay(for: start)
        let e = calendar.startOfDay(for: end)
        guard s <= e else { return [] }
        var out: [Date] = []
        var cursor = s
        while cursor <= e {
            out.append(cursor)
            guard let next = calendar.date(byAdding: .day, value: days, to: cursor) else { break }
            cursor = next
        }
        // Always include today's anchor so the latest value lands at the right edge.
        if out.last != e {
            out.append(e)
        }
        return out
    }
}
