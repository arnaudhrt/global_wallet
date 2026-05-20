import Foundation

/// USD-only formatters for M1. Multi-currency arrives in M3 via `Money.formatted(...)`.
enum FolioFormat {
    static func usd(_ value: Double, decimals: Int = 2) -> String {
        let f = currencyFormatter(decimals: decimals)
        return f.string(from: NSNumber(value: value)) ?? "$\(value)"
    }

    static func usdNoCents(_ value: Double) -> String {
        usd(value, decimals: 0)
    }

    static func pct(_ value: Double, decimals: Int = 2) -> String {
        let sign = value > 0 ? "+" : ""
        return "\(sign)\(String(format: "%.\(decimals)f", value))%"
    }

    static func num(_ value: Double, decimals: Int = 2) -> String {
        let f = numberFormatter(decimals: decimals)
        return f.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    // MARK: - Private

    private static func currencyFormatter(decimals: Int) -> NumberFormatter {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        f.locale = Locale(identifier: "en_US")
        f.minimumFractionDigits = decimals
        f.maximumFractionDigits = decimals
        return f
    }

    private static func numberFormatter(decimals: Int) -> NumberFormatter {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: "en_US")
        f.minimumFractionDigits = decimals
        f.maximumFractionDigits = decimals
        return f
    }
}
