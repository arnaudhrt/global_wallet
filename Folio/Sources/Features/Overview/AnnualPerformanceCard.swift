import SwiftUI

/// Annual Performance table — per-year rows from `AnnualPerformanceBuilder`.
/// S&P 500 / Nasdaq 100 columns intentionally render as `—` in MVP (benchmark
/// tickers aren't seeded yet — deferred to v2 per the M8.5 follow-up list).
struct AnnualPerformanceCard: View {
    @Environment(\.theme) private var theme
    let rows: [AnnualPerformanceRow]

    var body: some View {
        Card(padded: false) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Annual Performance")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(theme.text)
                    Spacer()
                    Text("Yearly returns")
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

                if rows.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 0) {
                        ForEach(rows, id: \.year) { row in
                            rowView(row)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 8)
                            Divider().overlay(theme.border.opacity(0.5))
                        }
                    }
                }
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

    private func rowView(_ row: AnnualPerformanceRow) -> some View {
        HStack(spacing: 0) {
            Text(String(row.year))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(theme.text)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(pctText(row.portfolioPct))
                .font(.system(size: 12, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(tone(for: row.portfolioPct))
                .frame(maxWidth: .infinity, alignment: .trailing)

            Text("—")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(theme.text3)
                .frame(maxWidth: .infinity, alignment: .trailing)

            Text("—")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(theme.text3)
                .frame(maxWidth: .infinity, alignment: .trailing)

            HStack {
                Spacer()
                if let badge = row.badge {
                    badgeChip(badge)
                }
            }
            .frame(width: 80)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(theme.text3)
            Text("No history yet for this portfolio")
                .font(.system(size: 12))
                .foregroundStyle(theme.text2)
            Text("Per-year returns appear once historical quotes are loaded")
                .font(.system(size: 11))
                .foregroundStyle(theme.text3)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }

    private func pctText(_ pct: Double?) -> String {
        guard let pct else { return "—" }
        let sign = pct >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.2f", pct))%"
    }

    private func tone(for pct: Double?) -> Color {
        guard let pct else { return theme.text3 }
        return pct >= 0 ? theme.green : theme.red
    }

    private func badgeChip(_ badge: AnnualPerformanceRow.Badge) -> some View {
        let text: String
        let fg: Color
        let bg: Color
        switch badge {
        case .best:
            text = "BEST"
            fg = theme.green
            bg = theme.greenBg
        case .worst:
            text = "WORST"
            fg = theme.red
            bg = theme.redBg
        }
        return Text(text)
            .font(.system(size: 10, weight: .semibold))
            .tracking(0.4)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(bg)
            .foregroundStyle(fg)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}
