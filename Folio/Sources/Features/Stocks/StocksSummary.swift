import SwiftUI

/// Three-card summary strip at the top of the Stocks & ETFs screen.
/// Market Value · Unrealized P&L · Dividends YTD (last-dividend strap line).
struct StocksSummary: View {
    let marketValue: Money
    let positionsCount: Int
    let brokersCount: Int
    let unrealizedPnL: Money
    let unrealizedPnLPct: Double?
    let dividendsYTD: Money
    let lastDividend: (ticker: String, amount: Money)?

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Metric(
                label: "Market Value",
                value: marketValue.formatted(),
                sub: positionsLine
            )
            Metric(
                label: "Unrealized P&L",
                value: signedFormatted(unrealizedPnL),
                sub: "vs. cost basis",
                subTone: .neutral,
                badge: pnlBadge
            )
            Metric(
                label: "Dividends YTD",
                value: dividendsYTD.formatted(),
                sub: lastDividendLine,
                subTone: lastDividend == nil ? .neutral : .positive
            )
        }
    }

    private var positionsLine: String {
        let posWord = positionsCount == 1 ? "position" : "positions"
        let brkWord = brokersCount == 1 ? "broker" : "brokers"
        return "\(positionsCount) \(posWord) across \(brokersCount) \(brkWord)"
    }

    private var pnlBadge: MetricBadge? {
        guard let pct = unrealizedPnLPct else { return nil }
        let sign = pct >= 0 ? "+" : ""
        let text = "\(sign)\(String(format: "%.1f", pct))%"
        return MetricBadge(text: text, tone: pct >= 0 ? .positive : .negative)
    }

    private var lastDividendLine: String {
        guard let last = lastDividend else { return "—" }
        let sign = last.amount.amount >= 0 ? "+" : ""
        return "Last: \(last.ticker)  \(sign)\(last.amount.formatted())"
    }

    private func signedFormatted(_ m: Money) -> String {
        let s = m.formatted()
        return m.amount >= 0 ? "+\(s)" : s
    }
}
