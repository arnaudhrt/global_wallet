import SwiftUI

/// Aggregate row for an asset on the Crypto screen. Tappable to toggle
/// expansion when in "All wallets" mode; chevron and tap target are
/// suppressed when a single wallet filter is active (the aggregate already
/// reflects that single wallet, so per-wallet sub-rows would be redundant).
struct CryptoTableRow: View {
    @Environment(\.theme) private var theme
    @State private var isHovered = false

    let holding: Holding
    /// Number of (asset, account) buckets backing this aggregate row. Used
    /// for the "N wallets" line beneath the asset name.
    let walletCount: Int
    /// Allocation as a percentage in 0…100 (crypto-subtotal denominator).
    let allocation: Double
    let isExpanded: Bool
    let canExpand: Bool
    /// Single account name to show as a trailing badge when a wallet filter is
    /// active. Nil in "All wallets" mode.
    let scopedAccount: Account?
    let onToggle: () -> Void

    var body: some View {
        Button(action: { if canExpand { onToggle() } }) {
            HStack(spacing: 0) {
                Group {
                    if canExpand {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(theme.text2)
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                            .animation(.easeInOut(duration: 0.12), value: isExpanded)
                    } else {
                        Color.clear
                    }
                }
                .frame(width: 28, alignment: .center)
                .padding(.leading, 18)

                // Asset
                HStack(spacing: 10) {
                    CryptoLogo(symbol: holding.asset.symbol)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(holding.asset.symbol)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(theme.text)
                        Text(subtitleText)
                            .font(.system(size: 11))
                            .foregroundStyle(theme.text3)
                            .lineLimit(1)
                    }
                    if let account = scopedAccount {
                        AccountBadge(name: account.name)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.leading, 8)
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
                    AllocBar(pct: allocation, color: theme.amber)
                        .padding(.trailing, 18)
                }
                .frame(width: 150)
            }
            .frame(height: 44)
            .background(isHovered ? theme.rowHover : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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

    private var subtitleText: String {
        let walletsWord = walletCount == 1 ? "wallet" : "wallets"
        return "\(holding.asset.name) · \(walletCount) \(walletsWord)"
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
