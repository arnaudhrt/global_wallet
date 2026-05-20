import SwiftUI
import SwiftData

/// Sidebar footer with brand avatar + portfolio total + account count.
///
/// Account count is live (`@Query` on `Account`). Portfolio total stays at
/// $0.00 until M4 wires live `PriceQuote` data into `HoldingsReducer`; the
/// `Money` value is formatted with the user's base currency from `AppSettings`.
struct SidebarFooter: View {
    @Environment(\.theme) private var theme
    @Query private var accounts: [Account]
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
        let count = accounts.count
        let plural = count == 1 ? "account" : "accounts"
        let baseCurrency = settings.first?.baseCurrency ?? "USD"
        let total = Money.zero(baseCurrency).formatted()
        return "\(count) \(plural) · \(total)"
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
