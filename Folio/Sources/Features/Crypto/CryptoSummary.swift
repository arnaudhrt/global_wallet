import SwiftUI

/// Three-card summary strip at the top of the Crypto screen.
/// Market Value · Unrealized P&L · Staking YTD.
struct CryptoSummary: View {
    let marketValue: Money
    let positionsCount: Int
    let walletsCount: Int
    let unrealizedPnL: Money
    let unrealizedPnLPct: Double?
    let stakingYTD: Money
    let stakingSubtitle: String

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
                label: "Staking YTD",
                value: stakingYTD.formatted(),
                sub: stakingSubtitle,
                subTone: stakingYTD.amount > 0 ? .positive : .neutral
            )
        }
    }

    private var positionsLine: String {
        let coinsWord = positionsCount == 1 ? "coin" : "coins"
        let walletsWord = walletsCount == 1 ? "wallet" : "wallets"
        return "\(positionsCount) \(coinsWord) across \(walletsCount) \(walletsWord)"
    }

    private var pnlBadge: MetricBadge? {
        guard let pct = unrealizedPnLPct else { return nil }
        let sign = pct >= 0 ? "+" : ""
        let text = "\(sign)\(String(format: "%.1f", pct))%"
        return MetricBadge(text: text, tone: pct >= 0 ? .positive : .negative)
    }

    private func signedFormatted(_ m: Money) -> String {
        let s = m.formatted()
        return m.amount >= 0 ? "+\(s)" : s
    }
}
