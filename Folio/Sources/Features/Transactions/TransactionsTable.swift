import SwiftUI

/// Dense, sortable, hover-aware transactions table. Custom-laid-out HStacks
/// (rather than `SwiftUI.Table`) for spacing and tabular-number control,
/// matching the M5/M6 pattern.
///
/// Column widths are fixed; the leading "Asset" cell flexes.
struct TransactionsTable: View {
    @Environment(\.theme) private var theme

    let rows: [PortfolioTransaction]
    let baseCurrency: String
    @Binding var sort: TxnSort

    var body: some View {
        Card(padded: false) {
            VStack(spacing: 0) {
                headerRow
                Rectangle().fill(theme.border).frame(height: 1)
                if rows.isEmpty {
                    emptyState
                } else {
                    ForEach(rows, id: \.id) { row in
                        TransactionsTableRow(txn: row)
                        Rectangle().fill(theme.border).frame(height: 1)
                    }
                    footerRow
                }
            }
        }
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack(spacing: 0) {
            headerCell(.date,    width: 110, alignment: .leading, leadingPad: 18)
            headerCell(.type,    width: 90,  alignment: .leading)
            headerCell(.asset,   width: nil, alignment: .leading)
            headerCell(.qty,     width: 90,  alignment: .trailing)
            headerCell(.price,   width: 110, alignment: .trailing)
            headerCell(.total,   width: 130, alignment: .trailing)
            headerCell(.account, width: 130, alignment: .leading)
            // Trailing "···" column — not a sort target.
            Color.clear
                .frame(width: 40)
                .padding(.trailing, 18)
        }
        .frame(height: 36)
        .background(theme.surface)
    }

    @ViewBuilder
    private func headerCell(
        _ column: TxnSortColumn,
        width: CGFloat?,
        alignment: Alignment,
        leadingPad: CGFloat = 8,
        trailingPad: CGFloat = 8
    ) -> some View {
        Button {
            if sort.column == column {
                sort.ascending.toggle()
            } else {
                sort = TxnSort(column: column, ascending: false)
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

    // MARK: - Footer

    @ViewBuilder
    private var footerRow: some View {
        let net = netTotal()
        HStack(spacing: 0) {
            Text("\(rows.count) transaction\(rows.count == 1 ? "" : "s")")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(theme.text)
                .padding(.leading, 18)
                .padding(.trailing, 8)
                .frame(width: 110, alignment: .leading)
            Color.clear.frame(width: 90)
            Color.clear.frame(maxWidth: .infinity)
            Color.clear.frame(width: 90)
            Color.clear.frame(width: 110)
            Text(signedFormatted(Money(amount: net, currency: baseCurrency)))
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(net >= 0 ? theme.green : theme.red)
                .padding(.trailing, 8)
                .frame(width: 130, alignment: .trailing)
            Color.clear.frame(width: 130)
            Color.clear.frame(width: 40).padding(.trailing, 18)
        }
        .frame(height: 38)
        .background(theme.surface)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 6) {
            Text("No transactions to show")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(theme.text2)
            Text("Add a holding from the toolbar to record your first transaction.")
                .font(.system(size: 12))
                .foregroundStyle(theme.text3)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    // MARK: - Helpers

    /// Signed net total across the visible rows. Sign rules mirror the row:
    /// + sell/dividend/deposit, − buy/withdraw, 0 for stake/transfer.
    private func netTotal() -> Decimal {
        rows.reduce(Decimal(0)) { acc, txn in
            switch txn.type {
            case .sell, .dividend, .deposit:
                return acc + txn.amount
            case .buy, .withdraw:
                return acc - txn.amount
            case .stake, .transfer:
                return acc
            }
        }
    }

    private func signedFormatted(_ m: Money) -> String {
        let s = m.formatted()
        return m.amount >= 0 ? "+\(s)" : s
    }
}
