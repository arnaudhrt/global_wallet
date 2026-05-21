import SwiftUI

/// Three-card summary strip at the top of the Transactions screen.
/// Transactions YTD · Net Inflows YTD · Income YTD.
struct TransactionsSummary: View {
    let ytdCount: Int
    let accountsCount: Int
    let netInflowsYTD: Money
    let incomeYTD: Money

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Metric(
                label: "Transactions YTD",
                value: "\(ytdCount)",
                sub: accountsLine
            )
            Metric(
                label: "Net Inflows YTD",
                value: signedFormatted(netInflowsYTD),
                sub: "Buys − Sells",
                subTone: netInflowsYTD.amount >= 0 ? .positive : .negative
            )
            Metric(
                label: "Income YTD",
                value: incomeYTD.formatted(),
                sub: "Dividends + Staking",
                subTone: incomeYTD.amount > 0 ? .positive : .neutral
            )
        }
    }

    private var accountsLine: String {
        let word = accountsCount == 1 ? "account" : "accounts"
        return "Across \(accountsCount) \(word)"
    }

    private func signedFormatted(_ m: Money) -> String {
        let s = m.formatted()
        return m.amount >= 0 ? "+\(s)" : s
    }
}
