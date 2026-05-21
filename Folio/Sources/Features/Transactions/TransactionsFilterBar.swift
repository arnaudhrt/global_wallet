import SwiftUI

/// Type filter pills + month label + disabled Export stub above the
/// transactions table. Matches the right-hand cluster from
/// `project/transactions.jsx`. Export is a visual-only stub (real export
/// is v2); ⌘K search is wired separately in M10.
struct TransactionsFilterBar: View {
    @Environment(\.theme) private var theme

    @Binding var selectedType: TransactionType?

    var body: some View {
        HStack(alignment: .center) {
            HStack(spacing: 8) {
                FilterPill(
                    label: "All types",
                    isActive: selectedType == nil
                ) { selectedType = nil }

                ForEach(TransactionType.allCases, id: \.self) { type in
                    FilterPill(
                        label: type.displayName,
                        isActive: selectedType == type
                    ) { selectedType = type }
                }
            }

            Spacer()

            rightCluster
        }
    }

    private var rightCluster: some View {
        HStack(spacing: 8) {
            Text(monthLabel)
                .font(.system(size: 12))
                .foregroundStyle(theme.text2)

            Rectangle()
                .fill(theme.border)
                .frame(width: 1, height: 14)

            // Visual-only — real Export ships in v2.
            HStack(spacing: 4) {
                Image(systemName: "arrow.down.to.line")
                    .font(.system(size: 10, weight: .semibold))
                Text("Export")
                    .font(.system(size: 12))
            }
            .foregroundStyle(theme.text2)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(theme.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(theme.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .allowsHitTesting(false)
        }
    }

    private var monthLabel: String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        f.locale = Locale(identifier: "en_US")
        return "This month · \(f.string(from: Date()))"
    }
}
