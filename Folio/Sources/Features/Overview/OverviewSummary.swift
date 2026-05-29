import SwiftUI

/// Four-card metric row at the top of the Overview screen.
/// Total Value · All-time Gain (badge %) · YTD Performance · Invested Capital.
///
/// `ytdPct` arrives from `PortfolioMetrics.ytdPerformance(history:)` (M8.5). Nil
/// when the series doesn't reach back to Jan 1 — in that case we keep the `—`
/// placeholder with a friendlier sublabel.
struct OverviewSummary: View {
    let totalValue: Money
    let accountsCount: Int
    let allTimeGain: Money
    let allTimeGainPct: Double?
    let earliestTransactionDate: Date?
    let investedCapital: Money
    let ytdPct: Double?

    private static let cardMinWidth: CGFloat = 220
    private static let cardSpacing: CGFloat = 14

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: Self.cardSpacing) {
                cards
            }
            Grid(horizontalSpacing: Self.cardSpacing, verticalSpacing: Self.cardSpacing) {
                GridRow {
                    totalValueCard
                    allTimeGainCard
                }
                GridRow {
                    ytdCard
                    investedCard
                }
            }
        }
    }

    @ViewBuilder private var cards: some View {
        totalValueCard
        allTimeGainCard
        ytdCard
        investedCard
    }

    private var totalValueCard: some View {
        Metric(
            label: "Total Value",
            value: totalValue.formatted(),
            sub: positionsLine
        )
        .frame(minWidth: Self.cardMinWidth)
    }

    private var allTimeGainCard: some View {
        Metric(
            label: "All-time Gain",
            value: signedFormatted(allTimeGain),
            sub: sinceLine,
            badge: gainBadge
        )
        .frame(minWidth: Self.cardMinWidth)
    }

    private var ytdCard: some View {
        Metric(
            label: "YTD Performance",
            value: ytdValue,
            sub: ytdSub,
            subTone: ytdSubTone
        )
        .frame(minWidth: Self.cardMinWidth)
    }

    private var investedCard: some View {
        Metric(
            label: "Invested Capital",
            value: investedCapital.formatted(),
            sub: investedLine
        )
        .frame(minWidth: Self.cardMinWidth)
    }

    private var positionsLine: String {
        let acc = accountsCount == 1 ? "account" : "accounts"
        return "Across \(accountsCount) \(acc)"
    }

    private var sinceLine: String {
        guard let date = earliestTransactionDate else { return "No transactions yet" }
        let f = DateFormatter()
        f.dateFormat = "MMM yyyy"
        return "Since \(f.string(from: date))"
    }

    private var investedLine: String {
        let acc = accountsCount == 1 ? "account" : "accounts"
        return "Across \(accountsCount) \(acc)"
    }

    private var gainBadge: MetricBadge? {
        guard let pct = allTimeGainPct else { return nil }
        let sign = pct >= 0 ? "+" : ""
        let text = "\(sign)\(String(format: "%.1f", pct))%"
        return MetricBadge(text: text, tone: pct >= 0 ? .positive : .negative)
    }

    private var ytdValue: String {
        guard let pct = ytdPct else { return "—" }
        let sign = pct >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.2f", pct))%"
    }

    private var ytdSub: String {
        guard ytdPct != nil else { return "Available once history covers Jan 1" }
        let cal = Calendar(identifier: .gregorian)
        return "Since Jan 1, \(cal.component(.year, from: Date()))"
    }

    private var ytdSubTone: FolioTone {
        guard let pct = ytdPct else { return .neutral }
        return pct >= 0 ? .positive : .negative
    }

    private func signedFormatted(_ m: Money) -> String {
        let s = m.formatted()
        return m.amount >= 0 ? "+\(s)" : s
    }
}
