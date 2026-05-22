import SwiftUI

/// Four-card metric row at the top of the Overview screen.
/// Total Value · All-time Gain (badge %) · YTD Performance · Invested Capital.
///
/// YTD% is intentionally `—` in M8 — real year-over-year computation requires
/// historical quotes, which land in M8.5. The slot stays visible so M8.5 is a
/// pure data-fill, not a layout change.
struct OverviewSummary: View {
    let totalValue: Money
    let positionsCount: Int
    let accountsCount: Int
    let allTimeGain: Money
    let allTimeGainPct: Double?
    let earliestTransactionDate: Date?
    let investedCapital: Money

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Metric(
                label: "Total Value",
                value: totalValue.formatted(),
                sub: positionsLine
            )
            Metric(
                label: "All-time Gain",
                value: signedFormatted(allTimeGain),
                sub: sinceLine,
                badge: gainBadge
            )
            Metric(
                label: "YTD Performance",
                value: "—",
                sub: "Available with M8.5",
                subTone: .neutral
            )
            Metric(
                label: "Invested Capital",
                value: investedCapital.formatted(),
                sub: investedLine
            )
        }
    }

    private var positionsLine: String {
        let pos = positionsCount == 1 ? "position" : "positions"
        let acc = accountsCount == 1 ? "account" : "accounts"
        return "\(positionsCount) \(pos) across \(accountsCount) \(acc)"
    }

    private var sinceLine: String {
        guard let date = earliestTransactionDate else { return "No transactions yet" }
        let f = DateFormatter()
        f.dateFormat = "MMM yyyy"
        return "Since \(f.string(from: date))"
    }

    private var investedLine: String {
        let acc = accountsCount == 1 ? "account" : "accounts"
        return "Cost basis across \(accountsCount) \(acc)"
    }

    private var gainBadge: MetricBadge? {
        guard let pct = allTimeGainPct else { return nil }
        let sign = pct >= 0 ? "+" : ""
        let text = "\(sign)\(String(format: "%.1f", pct))%"
        return MetricBadge(text: text, tone: pct >= 0 ? .positive : .negative)
    }

    private func signedFormatted(_ m: Money) -> String {
        let s = m.formatted()
        return m.amount >= 0 ? "+\(s)" : s
    }
}
