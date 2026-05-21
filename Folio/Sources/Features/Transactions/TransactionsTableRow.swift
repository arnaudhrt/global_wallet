import SwiftUI

/// One row in the transactions table. Hover state lives inside the row so
/// the parent doesn't have to track per-row hover. Column widths mirror
/// `TransactionsTable.headerRow`.
struct TransactionsTableRow: View {
    @Environment(\.theme) private var theme
    @State private var isHovered = false

    let txn: PortfolioTransaction

    var body: some View {
        HStack(spacing: 0) {
            // Date
            Text(dateText)
                .font(.system(size: 12, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(theme.text2)
                .padding(.leading, 18)
                .padding(.trailing, 8)
                .frame(width: 110, alignment: .leading)

            // Type badge
            HStack {
                typeBadge
                Spacer(minLength: 0)
            }
            .padding(.trailing, 8)
            .frame(width: 90, alignment: .leading)

            // Asset
            Text(txn.asset?.symbol ?? "—")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(theme.text)
                .padding(.trailing, 8)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Qty
            Text(qtyText)
                .font(.system(size: 12, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(theme.text2)
                .padding(.trailing, 8)
                .frame(width: 90, alignment: .trailing)

            // Price
            Text(priceText)
                .font(.system(size: 12, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(theme.text2)
                .padding(.trailing, 8)
                .frame(width: 110, alignment: .trailing)

            // Total (signed, tinted)
            Text(totalText)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(totalTone)
                .padding(.trailing, 8)
                .frame(width: 130, alignment: .trailing)

            // Account
            HStack {
                AccountBadge(name: txn.account.name)
                Spacer(minLength: 0)
            }
            .padding(.trailing, 8)
            .frame(width: 130, alignment: .leading)

            // "···" overflow stub
            Text("⋯")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(theme.text3)
                .padding(.trailing, 18)
                .frame(width: 40, alignment: .trailing)
                .allowsHitTesting(false)
        }
        .frame(height: 40)
        .background(isHovered ? theme.rowHover : Color.clear)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
    }

    // MARK: - Cells

    private var typeBadge: some View {
        let style = TypeBadgeStyle.style(for: txn.type, theme: theme)
        return Text(txn.type.displayName)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(style.foreground)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(style.background)
            .clipShape(RoundedRectangle(cornerRadius: 3))
    }

    // MARK: - Text formatting

    private var dateText: String {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        f.locale = Locale(identifier: "en_US")
        return f.string(from: txn.date)
    }

    private var qtyText: String {
        guard let qty = txn.quantity else { return "—" }
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: "en_US")
        let small = abs(qty) < 1
        f.minimumFractionDigits = small ? 4 : 0
        f.maximumFractionDigits = small ? 4 : 2
        return f.string(from: qty as NSDecimalNumber) ?? "\(qty)"
    }

    private var priceText: String {
        guard let price = txn.price else { return "—" }
        return Money(amount: price, currency: txn.currency).formatted()
    }

    private var totalText: String {
        let body = Money(amount: txn.amount, currency: txn.currency).formatted()
        switch txn.type {
        case .sell, .dividend, .deposit: return "+\(body)"
        case .buy, .withdraw:            return "−\(body)"
        case .stake, .transfer:          return body
        }
    }

    private var totalTone: Color {
        switch txn.type {
        case .sell, .dividend: return theme.green
        default:               return theme.text
        }
    }
}
