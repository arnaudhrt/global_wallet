import SwiftUI

/// Placeholder for the Portfolio-vs-Indexes chart. Owns the visible (but
/// functionally inert in M8) `PeriodPills` so M8.5 only has to swap the empty
/// state for a `Chart` view — the layout, header, and range binding are already
/// in place.
struct OverviewChartCard: View {
    @Environment(\.theme) private var theme
    @Binding var range: String

    private let chartHeight: CGFloat = 280

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Portfolio vs Indexes")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(theme.text)
                        Text("Normalized to 100 at start of period")
                            .font(.system(size: 11))
                            .foregroundStyle(theme.text3)
                    }
                    Spacer()
                    PeriodPills(selection: $range)
                }

                ZStack {
                    VStack(spacing: 8) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 28, weight: .light))
                            .foregroundStyle(theme.text3)
                        Text("Chart available with M8.5")
                            .font(.system(size: 12))
                            .foregroundStyle(theme.text2)
                        Text("Historical portfolio value vs. S&P 500 and Nasdaq 100")
                            .font(.system(size: 11))
                            .foregroundStyle(theme.text3)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: chartHeight)
                .padding(.top, 12)
            }
        }
    }
}
