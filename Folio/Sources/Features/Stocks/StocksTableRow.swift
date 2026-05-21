import SwiftUI

/// One row in the stocks table. Hover state lives inside the row so the parent
/// doesn't have to track per-row hover.
struct StocksTableRow: View {
    @Environment(\.theme) private var theme
    @State private var isHovered = false

    let holding: Holding
    /// Allocation as a percentage in 0…100.
    let allocation: Double

    var body: some View {
        HStack(spacing: 0) {
            // Asset
            HStack(spacing: 10) {
                TickerLogo(ticker: holding.asset.symbol)
                VStack(alignment: .leading, spacing: 1) {
                    Text(holding.asset.symbol)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(theme.text)
                    Text(holding.asset.name)
                        .font(.system(size: 11))
                        .foregroundStyle(theme.text3)
                        .lineLimit(1)
                }
                if let account = holding.account {
                    AccountBadge(name: account.name)
                }
                Spacer(minLength: 0)
            }
            .padding(.leading, 18)
            .padding(.trailing, 8)
            .frame(maxWidth: .infinity, alignment: .leading)

            cell(qtyText, width: 80, color: theme.text)
            cell(holding.avgCost.formatted(), width: 100, color: theme.text)
            cell(priceText, width: 110, color: theme.text)
            cell(marketValueText, width: 120, color: theme.text, weight: .semibold)
            cell(pnlText, width: 110, color: pnlTone, weight: .semibold)
            cell(pnlPctText, width: 80, color: pnlTone)

            HStack(spacing: 0) {
                Spacer(minLength: 0)
                AllocBar(pct: allocation, color: theme.green)
                    .padding(.trailing, 18)
            }
            .frame(width: 150)
        }
        .frame(height: 44)
        .background(isHovered ? theme.rowHover : Color.clear)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
    }

    @ViewBuilder
    private func cell(_ text: String, width: CGFloat, color: Color, weight: Font.Weight = .regular) -> some View {
        Text(text)
            .font(.system(size: 12, weight: weight, design: .monospaced))
            .monospacedDigit()
            .foregroundStyle(color)
            .padding(.trailing, 8)
            .frame(width: width, alignment: .trailing)
    }

    private var qtyText: String {
        let needsFraction = holding.qty < 1
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: "en_US")
        f.minimumFractionDigits = needsFraction ? 4 : 0
        f.maximumFractionDigits = needsFraction ? 4 : 0
        return f.string(from: holding.qty as NSDecimalNumber) ?? "\(holding.qty)"
    }

    private var priceText: String {
        guard let mv = holding.marketValue?.amount, holding.qty > 0 else { return "—" }
        let unit = mv / holding.qty
        return Money(amount: unit, currency: holding.marketValue?.currency ?? holding.avgCost.currency).formatted()
    }

    private var marketValueText: String {
        holding.marketValue?.formatted() ?? "—"
    }

    private var pnlText: String {
        guard let pnl = holding.unrealizedPnL else { return "—" }
        let s = pnl.formatted()
        return pnl.amount >= 0 ? "+\(s)" : s
    }

    private var pnlPctText: String {
        guard let pct = holding.unrealizedPnLPct else { return "—" }
        let sign = pct >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.2f", pct))%"
    }

    private var pnlTone: Color {
        guard let pnl = holding.unrealizedPnL else { return theme.text }
        return pnl.amount >= 0 ? theme.green : theme.red
    }
}
