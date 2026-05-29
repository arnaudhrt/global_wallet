import Foundation

/// Roll-ups over `[Holding]` for the Overview screen (M8). Lives in M3 because
/// the sidebar footer (and tests) can use `totalValue` immediately.
@MainActor
enum PortfolioMetrics {
    static func totalValue(_ holdings: [Holding], baseCurrency: String) -> Money {
        let sum = holdings.compactMap { $0.marketValue?.amount }.reduce(Decimal(0), +)
        return Money(amount: sum, currency: baseCurrency)
    }

    static func investedCapital(_ holdings: [Holding], baseCurrency: String) -> Money {
        let sum = holdings
            .map { $0.avgCost.amount * $0.qty }
            .reduce(Decimal(0), +)
        return Money(amount: sum, currency: baseCurrency)
    }

    /// Unrealized P&L on *currently held* positions: current market value −
    /// current cost basis. Excludes realized gains and income — see
    /// `allTimeGain` for the full picture.
    static func gainAllTime(_ holdings: [Holding], baseCurrency: String) -> Money {
        let mv = totalValue(holdings, baseCurrency: baseCurrency).amount
        let cost = investedCapital(holdings, baseCurrency: baseCurrency).amount
        return Money(amount: mv - cost, currency: baseCurrency)
    }

    /// Total return for the Overview "All-time Gain" card:
    /// **unrealized** P&L on open positions (`gainAllTime`) **+ realized** gains
    /// from past sells **+ income** (dividends + staking), all in base currency.
    ///
    /// `pct` is total gain ÷ total capital ever invested (gross `.buy` cost,
    /// excluding staking), giving an intuitive "put in $X over time, up Y%"
    /// figure that doesn't distort when positions close. Nil when nothing was
    /// ever bought.
    static func allTimeGain(
        holdings: [Holding],
        transactions: [PortfolioTransaction],
        fxAt: (_ from: String, _ to: String, _ date: Date) -> Decimal?,
        baseCurrency: String
    ) -> AllTimeGain {
        let unrealized = gainAllTime(holdings, baseCurrency: baseCurrency).amount
        let breakdown = HoldingsReducer.allTimeBreakdown(
            transactions: transactions,
            fxAt: fxAt,
            baseCurrency: baseCurrency
        )
        let total = unrealized + breakdown.realizedPlusIncome
        let pct: Double? = {
            guard breakdown.totalInvested > 0 else { return nil }
            let p = total / breakdown.totalInvested * 100
            return Double(truncating: p as NSDecimalNumber)
        }()
        return AllTimeGain(
            total: Money(amount: total, currency: baseCurrency),
            pct: pct,
            unrealized: Money(amount: unrealized, currency: baseCurrency),
            realized: Money(amount: breakdown.realizedPnL, currency: baseCurrency),
            income: Money(amount: breakdown.dividendIncome + breakdown.stakingIncome, currency: baseCurrency)
        )
    }

    /// Result of `allTimeGain` — the headline `total` and `pct` plus the three
    /// components (for sublabels / tooltips / tests).
    struct AllTimeGain: Equatable, Sendable {
        let total: Money
        let pct: Double?
        let unrealized: Money
        let realized: Money
        let income: Money
    }

    /// Returns percentage of total market value for each `AssetKind` present.
    /// Missing kinds are omitted (not zero). Percentages sum to ~100 (subject
    /// to rounding); each value is in 0…100 range, not 0…1.
    static func allocationByKind(_ holdings: [Holding]) -> [AssetKind: Decimal] {
        let total = holdings.compactMap { $0.marketValue?.amount }.reduce(Decimal(0), +)
        guard total > 0 else { return [:] }
        var result: [AssetKind: Decimal] = [:]
        for holding in holdings {
            guard let mv = holding.marketValue?.amount else { continue }
            result[holding.asset.kind, default: 0] += mv
        }
        return result.mapValues { $0 / total * 100 }
    }

    /// YTD performance as a **time-weighted return** percentage (0…100 range),
    /// computed from a chart-shaped history series. Slices the series from the
    /// first point on/after Jan 1 of `now`'s year and chains each sub-period's
    /// return, neutralizing buy/sell contributions via each point's `netFlow`
    /// (see `timeWeightedReturn`). Returns nil if the series doesn't span Jan 1,
    /// or if the Jan 1 value is zero (no portfolio yet).
    ///
    /// TWR (not raw value-change) so that adding or withdrawing capital doesn't
    /// distort the figure — depositing cash and buying more shares makes total
    /// value climb but leaves this number reflecting only price performance.
    /// For a zero-flow series TWR telescopes to plain value-change, so a
    /// contribution-free year reads identically to the old metric.
    static func ytdPerformance(history: [HistoryPoint], now: Date = .now) -> Double? {
        guard !history.isEmpty else { return nil }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC") ?? .current
        let year = cal.component(.year, from: now)
        guard let jan1 = cal.date(from: DateComponents(year: year, month: 1, day: 1)) else { return nil }

        let sorted = history.sorted(by: { $0.date < $1.date })
        guard let startIdx = sorted.firstIndex(where: { $0.date >= jan1 }) else { return nil }
        return timeWeightedReturn(Array(sorted[startIdx...]))
    }

    /// Time-weighted return over an already-sorted history slice, as a
    /// percentage (0…100 range). Chains each sub-period's growth factor
    /// `(Vᵢ − flowᵢ) / Vᵢ₋₁` — a flow-at-end-of-period convention that subtracts
    /// the period's net external cash flow from its ending value before
    /// comparing to the start, so contributions earn no spurious return. The
    /// product telescopes to `Vₙ / V₀` when all flows are zero.
    ///
    /// The first point is the baseline; its own `netFlow` is ignored (flows
    /// before the window are already baked into the starting value). Returns nil
    /// if there's no positive starting capital. Sub-periods that start from zero
    /// capital contribute a neutral factor (the flow just establishes the base).
    static func timeWeightedReturn(_ points: [HistoryPoint]) -> Double? {
        guard let first = points.first, first.total.amount > 0 else { return nil }
        var factor = Decimal(1)
        var prev = first.total.amount
        for point in points.dropFirst() {
            let value = point.total.amount
            if prev > 0 {
                factor *= (value - point.netFlow.amount) / prev
            }
            prev = value
        }
        let pct = (factor - 1) * 100
        return Double(truncating: pct as NSDecimalNumber)
    }
}
