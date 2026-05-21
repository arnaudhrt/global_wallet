import SwiftUI

/// Dense, hover-aware stocks table. Custom-laid-out HStacks (rather than
/// `SwiftUI.Table`) so spacing, hover, and tabular numerics match the JSX.
///
/// Column widths are fixed (`Layout`); the leading "Asset" cell flexes.
struct StocksTable: View {
    @Environment(\.theme) private var theme

    let rows: [Holding]
    let totalMarketValue: Decimal
    let footerPnL: Money
    let footerPnLPct: Double?
    @Binding var sort: StocksSort

    var body: some View {
        Card(padded: false) {
            VStack(spacing: 0) {
                headerRow
                Rectangle().fill(theme.border).frame(height: 1)
                if rows.isEmpty {
                    emptyState
                } else {
                    ForEach(rows) { row in
                        StocksTableRow(
                            holding: row,
                            allocation: allocation(for: row)
                        )
                        Rectangle().fill(theme.border).frame(height: 1)
                    }
                    footerRow
                }
            }
        }
    }

    private var headerRow: some View {
        HStack(spacing: 0) {
            headerCell(.ticker,      width: nil,  alignment: .leading, leadingPad: 18)
            headerCell(.qty,         width: 80,   alignment: .trailing)
            headerCell(.avgCost,     width: 100,  alignment: .trailing)
            headerCell(.price,       width: 110,  alignment: .trailing)
            headerCell(.marketValue, width: 120,  alignment: .trailing)
            headerCell(.pnl,         width: 110,  alignment: .trailing)
            headerCell(.pnlPct,      width: 80,   alignment: .trailing)
            headerCell(.allocation,  width: 150,  alignment: .trailing, trailingPad: 18)
        }
        .frame(height: 36)
        .background(theme.surface)
    }

    @ViewBuilder
    private func headerCell(
        _ column: StocksSortColumn,
        width: CGFloat?,
        alignment: Alignment,
        leadingPad: CGFloat = 8,
        trailingPad: CGFloat = 8
    ) -> some View {
        Button {
            if sort.column == column {
                sort.ascending.toggle()
            } else {
                sort = StocksSort(column: column, ascending: false)
            }
        } label: {
            HStack(spacing: 4) {
                if alignment == .trailing { Spacer(minLength: 0) }
                Text(column.label.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.4)
                    .foregroundStyle(theme.text3)
                if sort.column == column {
                    Image(systemName: sort.ascending ? "chevron.up" : "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(theme.text3)
                }
                if alignment == .leading { Spacer(minLength: 0) }
            }
            .padding(.leading, leadingPad)
            .padding(.trailing, trailingPad)
            .frame(maxWidth: width.map { $0 } ?? .infinity, alignment: alignment)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(width: width)
    }

    @ViewBuilder
    private var footerRow: some View {
        HStack(spacing: 0) {
            Text("\(rows.count) holding\(rows.count == 1 ? "" : "s")")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(theme.text)
                .padding(.leading, 18)
                .frame(maxWidth: .infinity, alignment: .leading)
            Color.clear.frame(width: 80)
            Color.clear.frame(width: 100)
            Color.clear.frame(width: 110)
            Text(Money(amount: totalMarketValue, currency: footerPnL.currency).formatted())
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(theme.text)
                .frame(width: 120, alignment: .trailing)
                .padding(.trailing, 8)
            Text(signedFormatted(footerPnL))
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(footerPnL.amount >= 0 ? theme.green : theme.red)
                .frame(width: 110, alignment: .trailing)
                .padding(.trailing, 8)
            Text(formatPct(footerPnLPct))
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle((footerPnLPct ?? 0) >= 0 ? theme.green : theme.red)
                .frame(width: 80, alignment: .trailing)
                .padding(.trailing, 8)
            Text("100.0%")
                .font(.system(size: 11, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(theme.text3)
                .frame(width: 150, alignment: .trailing)
                .padding(.trailing, 18)
        }
        .frame(height: 38)
        .background(theme.surface)
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Text("No stocks or ETFs to show")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(theme.text2)
            Text("Add a holding from the toolbar to get started.")
                .font(.system(size: 12))
                .foregroundStyle(theme.text3)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    private func allocation(for row: Holding) -> Double {
        guard totalMarketValue > 0, let mv = row.marketValue?.amount else { return 0 }
        let pct = mv / totalMarketValue * 100
        return Double(truncating: pct as NSDecimalNumber)
    }

    private func signedFormatted(_ m: Money) -> String {
        let s = m.formatted()
        return m.amount >= 0 ? "+\(s)" : s
    }

    private func formatPct(_ pct: Double?) -> String {
        guard let pct else { return "—" }
        let sign = pct >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.1f", pct))%"
    }
}
