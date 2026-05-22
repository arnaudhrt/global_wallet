import SwiftUI

/// Annual Performance table — header row + an empty body in M8. The full per-
/// year rows (Portfolio % vs S&P 500 % vs Nasdaq 100 % with BEST/WORST badges)
/// require historical quotes that arrive in M8.5; in the meantime the card
/// reserves its place in the layout and explains why the body is blank.
struct AnnualPerformanceCard: View {
    @Environment(\.theme) private var theme

    var body: some View {
        Card(padded: false) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Annual Performance")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(theme.text)
                    Spacer()
                    Text("vs benchmarks")
                        .font(.system(size: 11))
                        .foregroundStyle(theme.text3)
                }
                .padding(.horizontal, 18)
                .padding(.top, 14)
                .padding(.bottom, 10)

                headerRow
                    .padding(.horizontal, 18)
                    .padding(.bottom, 6)

                Divider().overlay(theme.border)

                VStack(spacing: 8) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 24, weight: .light))
                        .foregroundStyle(theme.text3)
                    Text("Historical comparisons available with M8.5")
                        .font(.system(size: 12))
                        .foregroundStyle(theme.text2)
                    Text("Per-year portfolio vs S&P 500 / Nasdaq with BEST/WORST badges")
                        .font(.system(size: 11))
                        .foregroundStyle(theme.text3)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
            }
        }
    }

    private var headerRow: some View {
        HStack(spacing: 0) {
            headerCell("YEAR",       alignment: .leading)
            headerCell("PORTFOLIO",  alignment: .trailing)
            headerCell("S&P 500",    alignment: .trailing)
            headerCell("NASDAQ",     alignment: .trailing)
            Spacer().frame(width: 80)
        }
    }

    private func headerCell(_ text: String, alignment: Alignment) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .tracking(0.4)
            .foregroundStyle(theme.text3)
            .frame(maxWidth: .infinity, alignment: alignment)
    }
}
