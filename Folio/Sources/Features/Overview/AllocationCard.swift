import SwiftUI

/// Asset Allocation card: split bar across (Stocks & ETFs, Crypto) buckets
/// plus a legend row per bucket. Cash bucket deferred until cash tracking
/// lands. When no priced holdings exist, the card renders a single empty-state
/// line under the section header so the layout doesn't collapse.
struct AllocationCard: View {
    @Environment(\.theme) private var theme

    let entries: [OverviewMetricsBuilder.AllocationEntry]

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 0) {
                SectionHeader(title: "Asset Allocation") {
                    Text("Current")
                        .font(.system(size: 11))
                        .foregroundStyle(theme.text3)
                }

                if entries.isEmpty {
                    Text("No holdings yet")
                        .font(.system(size: 12))
                        .foregroundStyle(theme.text2)
                        .padding(.vertical, 12)
                } else {
                    splitBar
                        .padding(.top, 2)

                    VStack(spacing: 12) {
                        ForEach(entries, id: \.category) { entry in
                            legendRow(entry)
                        }
                    }
                    .padding(.top, 18)
                }
            }
        }
    }

    private var splitBar: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                ForEach(entries, id: \.category) { entry in
                    Rectangle()
                        .fill(color(for: entry.category))
                        .frame(width: geo.size.width * pctFraction(entry.pct))
                }
            }
        }
        .frame(height: 12)
        .clipShape(RoundedRectangle(cornerRadius: 3))
        .overlay(
            RoundedRectangle(cornerRadius: 3)
                .stroke(theme.border, lineWidth: 1)
        )
    }

    private func legendRow(_ entry: OverviewMetricsBuilder.AllocationEntry) -> some View {
        HStack(spacing: 12) {
            Dot(color: color(for: entry.category), size: 10)
            Text(entry.category.displayName)
                .font(.system(size: 13))
                .foregroundStyle(theme.text)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(entry.amount.formatted())
                .font(.system(size: 12, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(theme.text2)
            Text(pctLabel(entry.pct))
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(theme.text)
                .frame(width: 56, alignment: .trailing)
        }
    }

    private func color(for cat: OverviewMetricsBuilder.AllocationCategory) -> Color {
        switch cat {
        case .stocks: return theme.green
        case .crypto: return theme.amber
        }
    }

    private func pctFraction(_ pct: Decimal) -> CGFloat {
        let clamped = max(Decimal(0), min(Decimal(100), pct))
        return CGFloat((clamped as NSDecimalNumber).doubleValue) / 100
    }

    private func pctLabel(_ pct: Decimal) -> String {
        String(format: "%.1f%%", (pct as NSDecimalNumber).doubleValue)
    }
}
