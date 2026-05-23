import SwiftUI
import Charts

/// Real M8.5 chart. Owns the `PeriodPills` so `OverviewScreen` only has to
/// pipe `series` + `status` down; range mutation flows back through `@Binding`.
///
/// States the card switches between:
/// - `series.isEmpty` + service fetching → centered ProgressView
/// - `series.isEmpty` + idle → empty-state copy (no historicals yet for any
///   loaded asset; treat as "load failed" or "no transactions to chart")
/// - otherwise → Swift Charts `LineMark` with hover crosshair
struct OverviewChartCard: View {
    @Environment(\.theme) private var theme
    @Binding var range: String

    let series: [HistoryPoint]
    let isLoading: Bool

    @State private var hoverDate: Date?

    private let chartHeight: CGFloat = 280

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Portfolio Value")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(theme.text)
                        Text(subtitle)
                            .font(.system(size: 11))
                            .foregroundStyle(theme.text3)
                    }
                    Spacer()
                    PeriodPills(selection: $range)
                }

                Group {
                    if series.isEmpty {
                        emptyOrLoading
                    } else {
                        chart
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: chartHeight)
                .padding(.top, 12)
            }
        }
    }

    // MARK: - States

    private var emptyOrLoading: some View {
        ZStack {
            if isLoading {
                VStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Loading history…")
                        .font(.system(size: 11))
                        .foregroundStyle(theme.text3)
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 28, weight: .light))
                        .foregroundStyle(theme.text3)
                    Text("No historical data for this range")
                        .font(.system(size: 12))
                        .foregroundStyle(theme.text2)
                    Text("Try a longer range, or wait for the next quote refresh")
                        .font(.system(size: 11))
                        .foregroundStyle(theme.text3)
                }
            }
        }
    }

    private var chart: some View {
        Chart {
            ForEach(series, id: \.date) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Value", (point.total.amount as NSDecimalNumber).doubleValue)
                )
                .foregroundStyle(theme.blue)
                .interpolationMethod(.monotone)
            }
            if let hoverDate, let p = pointNear(hoverDate) {
                RuleMark(x: .value("Hover", p.date))
                    .foregroundStyle(theme.border)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 3]))
                PointMark(
                    x: .value("Date", p.date),
                    y: .value("Value", (p.total.amount as NSDecimalNumber).doubleValue)
                )
                .foregroundStyle(theme.blue)
                .symbolSize(60)
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { value in
                AxisGridLine().foregroundStyle(theme.border.opacity(0.4))
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    .foregroundStyle(theme.text3)
            }
        }
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { value in
                AxisGridLine().foregroundStyle(theme.border.opacity(0.4))
                AxisValueLabel {
                    if let d = value.as(Double.self) {
                        Text(compactCurrency(d))
                            .font(.system(size: 10))
                            .foregroundStyle(theme.text3)
                    }
                }
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let location):
                            let origin = geo[proxy.plotAreaFrame].origin
                            let relativeX = location.x - origin.x
                            if let date: Date = proxy.value(atX: relativeX) {
                                hoverDate = date
                            }
                        case .ended:
                            hoverDate = nil
                        }
                    }
            }
        }
        .overlay(alignment: .topLeading) {
            if let tooltip = tooltipText {
                Text(tooltip)
                    .font(.system(size: 10, weight: .medium).monospacedDigit())
                    .foregroundStyle(theme.text)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(theme.cardBg)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(theme.border, lineWidth: 1)
                            )
                    )
                    .padding(8)
            }
        }
    }

    // MARK: - Helpers

    private var subtitle: String {
        guard let first = series.first, let last = series.last else {
            return "Historical portfolio value"
        }
        let delta = last.total.amount - first.total.amount
        let pct: String = {
            guard first.total.amount > 0 else { return "" }
            let p = delta / first.total.amount * 100
            let n = (p as NSDecimalNumber).doubleValue
            let sign = n >= 0 ? "+" : ""
            return " (\(sign)\(String(format: "%.1f", n))%)"
        }()
        let sign = delta >= 0 ? "+" : ""
        return "\(sign)\(Money(amount: delta, currency: first.total.currency).formatted())\(pct) over period"
    }

    private var tooltipText: String? {
        guard let hoverDate, let p = pointNear(hoverDate), let first = series.first else { return nil }
        let df = DateFormatter()
        df.dateFormat = "MMM d, yyyy"
        let value = p.total.formatted()
        let delta = p.total.amount - first.total.amount
        let sign = delta >= 0 ? "+" : ""
        let deltaStr = Money(amount: delta, currency: p.total.currency).formatted()
        return "\(df.string(from: p.date)) · \(value) · \(sign)\(deltaStr)"
    }

    /// Returns the series point closest to `target` by date.
    private func pointNear(_ target: Date) -> HistoryPoint? {
        guard !series.isEmpty else { return nil }
        var best = series[0]
        var bestDelta = abs(best.date.timeIntervalSince(target))
        for p in series.dropFirst() {
            let d = abs(p.date.timeIntervalSince(target))
            if d < bestDelta {
                best = p
                bestDelta = d
            }
        }
        return best
    }

    private func compactCurrency(_ d: Double) -> String {
        let abs = Swift.abs(d)
        let sign = d < 0 ? "-" : ""
        if abs >= 1_000_000 {
            return "\(sign)$\(String(format: "%.1f", abs / 1_000_000))M"
        }
        if abs >= 1_000 {
            return "\(sign)$\(String(format: "%.0f", abs / 1_000))k"
        }
        return "\(sign)$\(String(format: "%.0f", abs))"
    }
}
