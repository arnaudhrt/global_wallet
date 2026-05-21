import SwiftUI

/// Composes the Crypto table: sortable header, aggregate rows interleaved
/// with their per-wallet sub-rows when expanded, and a totals footer.
/// Column widths mirror `StocksTable`.
struct CryptoTable: View {
    @Environment(\.theme) private var theme

    let aggregateRows: [Holding]
    let subRowsByAsset: [String: [Holding]]
    let cryptoSubtotalMV: Decimal
    let footerPnL: Money
    let footerPnLPct: Double?
    @Binding var sort: CryptoSort
    let expanded: Set<String>
    let onToggleExpansion: (String) -> Void
    /// nil in "All wallets" mode; the scoping account otherwise.
    let scopedAccount: Account?

    var body: some View {
        Card(padded: false) {
            VStack(spacing: 0) {
                headerRow
                Rectangle().fill(theme.border).frame(height: 1)
                if aggregateRows.isEmpty {
                    emptyState
                } else {
                    ForEach(aggregateRows) { row in
                        CryptoTableRow(
                            holding: row,
                            walletCount: walletCount(for: row),
                            allocation: allocation(for: row),
                            isExpanded: expanded.contains(row.asset.symbol),
                            canExpand: scopedAccount == nil && walletCount(for: row) > 0,
                            scopedAccount: scopedAccount,
                            onToggle: { onToggleExpansion(row.asset.symbol) }
                        )
                        Rectangle().fill(theme.border).frame(height: 1)

                        if scopedAccount == nil, expanded.contains(row.asset.symbol) {
                            ForEach(subRowsByAsset[row.asset.symbol] ?? []) { sub in
                                CryptoTableSubRow(
                                    holding: sub,
                                    parentQty: row.qty,
                                    allocation: subAllocation(for: sub)
                                )
                                Rectangle().fill(theme.border).frame(height: 1)
                            }
                        }
                    }
                    footerRow
                }
            }
        }
    }

    // MARK: - Header / footer

    private var headerRow: some View {
        HStack(spacing: 0) {
            // Spacer column for chevron — not a sort target.
            Color.clear
                .frame(width: 28)
                .padding(.leading, 18)
            headerCell(.ticker,      width: nil,  alignment: .leading)
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
        _ column: CryptoSortColumn,
        width: CGFloat?,
        alignment: Alignment,
        leadingPad: CGFloat = 8,
        trailingPad: CGFloat = 8
    ) -> some View {
        Button {
            if sort.column == column {
                sort.ascending.toggle()
            } else {
                sort = CryptoSort(column: column, ascending: false)
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
            Color.clear.frame(width: 28).padding(.leading, 18)
            Text("\(aggregateRows.count) coin\(aggregateRows.count == 1 ? "" : "s")")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(theme.text)
                .padding(.leading, 8)
                .padding(.trailing, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
            Color.clear.frame(width: 80)
            Color.clear.frame(width: 100)
            Color.clear.frame(width: 110)
            Text(Money(amount: cryptoSubtotalMV, currency: footerPnL.currency).formatted())
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(theme.text)
                .padding(.trailing, 8)
                .frame(width: 120, alignment: .trailing)
            Text(signedFormatted(footerPnL))
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(footerPnL.amount >= 0 ? theme.green : theme.red)
                .padding(.trailing, 8)
                .frame(width: 110, alignment: .trailing)
            Text(formatPct(footerPnLPct))
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle((footerPnLPct ?? 0) >= 0 ? theme.green : theme.red)
                .padding(.trailing, 8)
                .frame(width: 80, alignment: .trailing)
            Text("100.0%")
                .font(.system(size: 11, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(theme.text3)
                .padding(.trailing, 18)
                .frame(width: 150, alignment: .trailing)
        }
        .frame(height: 38)
        .background(theme.surface)
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Text("No crypto holdings to show")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(theme.text2)
            Text("Add a crypto holding from the toolbar to get started.")
                .font(.system(size: 12))
                .foregroundStyle(theme.text3)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    // MARK: - Helpers

    private func walletCount(for row: Holding) -> Int {
        subRowsByAsset[row.asset.symbol]?.count ?? 0
    }

    private func allocation(for row: Holding) -> Double {
        guard cryptoSubtotalMV > 0, let mv = row.marketValue?.amount else { return 0 }
        let pct = mv / cryptoSubtotalMV * 100
        return Double(truncating: pct as NSDecimalNumber)
    }

    private func subAllocation(for sub: Holding) -> Double {
        guard cryptoSubtotalMV > 0, let mv = sub.marketValue?.amount else { return 0 }
        let pct = mv / cryptoSubtotalMV * 100
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
