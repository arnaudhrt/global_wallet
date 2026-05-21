import SwiftUI
import SwiftData

/// Sidebar footer with brand avatar + account count + live portfolio total.
///
/// Total is computed on every render from `@Query` transactions + the newest
/// `PriceQuote` per asset. `fxAt` stays USD-only in M4 — once M10 ships the
/// base-currency picker the closure routes through cached `FXRate` rows.
struct SidebarFooter: View {
    @Environment(\.theme) private var theme
    @Query private var accounts: [Account]
    @Query private var transactions: [PortfolioTransaction]
    @Query private var settings: [AppSettings]

    var body: some View {
        HStack(spacing: 10) {
            avatar
            VStack(alignment: .leading, spacing: 1) {
                Text("Folio")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(theme.text)
                Text(footerLine)
                    .font(.system(size: 11))
                    .foregroundStyle(theme.text3)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(theme.border)
                .frame(height: 1)
        }
    }

    private var footerLine: String {
        let baseCurrency = settings.first?.baseCurrency ?? "USD"
        let holdings = HoldingsReducer.reduceByAsset(
            transactions: transactions,
            priceFor: { asset in
                asset.quotes.sorted(by: { $0.asOf > $1.asOf }).first?.amount
            },
            fxAt: { from, to, _ in from == to ? 1 : nil },
            baseCurrency: baseCurrency
        )
        let total = PortfolioMetrics.totalValue(holdings, baseCurrency: baseCurrency)
        let count = accounts.count
        let plural = count == 1 ? "account" : "accounts"
        return "\(count) \(plural) · \(total.formatted())"
    }

    private var avatar: some View {
        ZStack {
            Circle().fill(theme.borderStrong)
            Text("F")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(theme.text)
        }
        .frame(width: 28, height: 28)
    }
}
