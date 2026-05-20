import SwiftUI

/// Debug-only screen that exercises every primitive at the current colorScheme.
/// Used in M1 to verify the design system; will be replaced by `MacShell` in M2.
struct DesignSystemPreview: View {
    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @State private var period: String = "YTD"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header

                section("Metrics") {
                    HStack(alignment: .top, spacing: 12) {
                        Metric(
                            label: "Total Value",
                            value: FolioFormat.usd(487234.18),
                            sub: "+\(FolioFormat.usd(8420.50)) today",
                            subTone: .positive
                        )
                        Metric(
                            label: "All-time Gain",
                            value: FolioFormat.usd(142891.44),
                            badge: MetricBadge(text: FolioFormat.pct(41.5, decimals: 1), tone: .positive)
                        )
                        Metric(
                            label: "YTD Performance",
                            value: FolioFormat.pct(18.7, decimals: 1),
                            sub: "vs S&P \(FolioFormat.pct(9.2, decimals: 1))",
                            subTone: .neutral
                        )
                        Metric(
                            label: "Invested Capital",
                            value: FolioFormat.usd(344342.74)
                        )
                    }
                }

                section("Section Header") {
                    Card {
                        VStack(alignment: .leading) {
                            SectionHeader(title: "Portfolio vs indexes") {
                                PeriodPills(selection: $period)
                            }
                            Text("Headers carry an optional trailing slot — used here for the period pills.")
                                .font(.system(size: 12))
                                .foregroundStyle(theme.text2)
                        }
                    }
                }

                section("Allocation Bars") {
                    Card {
                        VStack(alignment: .leading, spacing: 12) {
                            allocRow(label: "Stocks", pct: 68, color: theme.green)
                            allocRow(label: "Crypto", pct: 22, color: theme.amber)
                            allocRow(label: "Cash",   pct: 10, color: theme.text3)
                        }
                    }
                }

                section("Account Badges") {
                    HStack(spacing: 8) {
                        AccountBadge(name: "Schwab")
                        AccountBadge(name: "Fidelity")
                        AccountBadge(name: "Vanguard")
                        AccountBadge(name: "Binance")
                        AccountBadge(name: "MetaMask")
                    }
                }

                section("Wallet Dots") {
                    HStack(spacing: 16) {
                        dotRow(color: Color(hex: 0xF0B90B), name: "Binance")
                        dotRow(color: Color(hex: 0x1D1D1F), name: "Ledger")
                        dotRow(color: Color(hex: 0xF6851B), name: "MetaMask")
                        dotRow(color: Color(hex: 0x1652F0), name: "Coinbase")
                        dotRow(color: Color(hex: 0x9945FF), name: "Phantom")
                    }
                }

                section("P&L Tones") {
                    Card {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 12) {
                                Text("Gain").foregroundStyle(theme.green)
                                Text(FolioFormat.usd(12450.30))
                                    .foregroundStyle(theme.green)
                                    .font(.system(.body, design: .monospaced))
                                Text(FolioFormat.pct(18.7))
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(theme.greenBg)
                                    .foregroundStyle(theme.green)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            HStack(spacing: 12) {
                                Text("Loss").foregroundStyle(theme.red)
                                Text("-\(FolioFormat.usd(4230.18))")
                                    .foregroundStyle(theme.red)
                                    .font(.system(.body, design: .monospaced))
                                Text(FolioFormat.pct(-12.4))
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(theme.redBg)
                                    .foregroundStyle(theme.red)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                                    .font(.system(size: 12, weight: .semibold))
                            }
                        }
                    }
                }

                section("Formatters") {
                    Card {
                        VStack(alignment: .leading, spacing: 6) {
                            formatRow("FolioFormat.usd(487234.18)", FolioFormat.usd(487234.18))
                            formatRow("FolioFormat.usdNoCents(344342.74)", FolioFormat.usdNoCents(344342.74))
                            formatRow("FolioFormat.pct(18.7)", FolioFormat.pct(18.7))
                            formatRow("FolioFormat.pct(-12.4)", FolioFormat.pct(-12.4))
                            formatRow("FolioFormat.num(1234567.8901, decimals: 4)", FolioFormat.num(1234567.8901, decimals: 4))
                        }
                    }
                }
            }
            .padding(28)
            .frame(maxWidth: 980, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(theme.bg)
    }

    // MARK: - Helpers

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Folio · Design System")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(theme.text)
            Text("M1 preview — currently in \(colorScheme == .dark ? "dark" : "light") mode (follows system appearance).")
                .font(.system(size: 12))
                .foregroundStyle(theme.text2)
        }
    }

    @ViewBuilder
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(theme.text3)
            content()
        }
    }

    private func allocRow(label: String, pct: Double, color: Color) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(theme.text)
                .frame(width: 60, alignment: .leading)
            AllocBar(pct: pct, color: color, width: 220)
            Spacer()
        }
    }

    private func dotRow(color: Color, name: String) -> some View {
        HStack(spacing: 6) {
            Dot(color: color)
            Text(name)
                .font(.system(size: 12))
                .foregroundStyle(theme.text2)
        }
    }

    private func formatRow(_ left: String, _ right: String) -> some View {
        HStack {
            Text(left)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(theme.text2)
            Spacer()
            Text(right)
                .font(.system(size: 12, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(theme.text)
        }
    }
}
