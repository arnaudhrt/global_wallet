import SwiftUI

/// Per-wallet sub-row shown below an expanded aggregate Crypto row. The
/// "Current Price" column is intentionally rendered as "—" since price is
/// asset-level and already shown on the aggregate row above. Allocation is
/// a small text % (no bar) using the crypto subtotal as denominator —
/// matches the choice taken in M6's aggregate row.
struct CryptoTableSubRow: View {
    @Environment(\.theme) private var theme

    let holding: Holding
    /// Parent's aggregate qty for this asset; drives the "X% of holding" pill.
    let parentQty: Decimal
    /// Allocation against the crypto subtotal in 0…100.
    let allocation: Double

    var body: some View {
        HStack(spacing: 0) {
            // Empty leading cell aligns with parent chevron column.
            Color.clear.frame(width: 28)

            // Wallet identity block (aligned beneath the parent's asset name)
            HStack(spacing: 10) {
                Color.clear.frame(width: 28) // logo gutter
                Dot(color: dotColor, size: 8)
                Text(holding.account?.name ?? "—")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(theme.text)
                Text(percentOfHoldingText)
                    .font(.system(size: 11))
                    .foregroundStyle(theme.text3)
                Spacer(minLength: 0)
            }
            .padding(.leading, 18)
            .padding(.trailing, 8)
            .frame(maxWidth: .infinity, alignment: .leading)

            cell(qtyText, width: 80, color: theme.text)
            cell(holding.avgCost.formatted(), width: 100, color: theme.text)
            cell("—", width: 110, color: theme.text3)
            cell(marketValueText, width: 120, color: theme.text)
            cell(pnlText, width: 110, color: pnlTone)
            cell(pnlPctText, width: 80, color: pnlTone)

            Text(allocationText)
                .font(.system(size: 11, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(theme.text3)
                .padding(.trailing, 18)
                .frame(width: 150, alignment: .trailing)
        }
        .frame(height: 36)
        .background(theme.surface)
    }

    @ViewBuilder
    private func cell(_ text: String, width: CGFloat, color: Color) -> some View {
        Text(text)
            .font(.system(size: 12, design: .monospaced))
            .monospacedDigit()
            .foregroundStyle(color)
            .padding(.trailing, 8)
            .frame(width: width, alignment: .trailing)
    }

    private var dotColor: Color {
        guard let account = holding.account else { return theme.text3 }
        return Color(hex: account.colorHex)
    }

    private var percentOfHoldingText: String {
        guard parentQty > 0 else { return "" }
        let pct = holding.qty / parentQty * 100
        let d = Double(truncating: pct as NSDecimalNumber)
        return "\(String(format: "%.1f", d))% of holding"
    }

    private var qtyText: String {
        let needsFraction = holding.qty < 1
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: "en_US")
        f.minimumFractionDigits = needsFraction ? 4 : 0
        f.maximumFractionDigits = needsFraction ? 4 : 2
        return f.string(from: holding.qty as NSDecimalNumber) ?? "\(holding.qty)"
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
        return "\(sign)\(String(format: "%.1f", pct))%"
    }

    private var pnlTone: Color {
        guard let pnl = holding.unrealizedPnL else { return theme.text }
        return pnl.amount >= 0 ? theme.green : theme.red
    }

    private var allocationText: String {
        "\(String(format: "%.2f", allocation))%"
    }
}
