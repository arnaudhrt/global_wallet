import Foundation

/// `Decimal`-backed money value with an ISO 4217 currency tag.
///
/// **Mixed-currency math traps.** `+`, `-`, and `<` `precondition` that both
/// operands share a `currency`. The trap is intentional — silent currency
/// coercion would lose information at the lowest level of the stack. Callers
/// must convert to a common currency (via `FXLookup` or an FX provider) before
/// any cross-currency arithmetic.
///
/// All user-input paths in the app go through `AddTransactionForm`, which
/// builds `Money` values internally from validated `Decimal` strings. The
/// trap therefore only fires on programmer error (e.g. summing a EUR `Money`
/// with a USD `Money`). If non-base-currency user input ever ships through
/// untrusted paths, switch to a `throws` variant at that boundary.
struct Money: Equatable, Hashable, Sendable {
    let amount: Decimal
    let currency: String

    init(amount: Decimal, currency: String) {
        self.amount = amount
        self.currency = currency
    }

    init(_ amount: Decimal, _ currency: String) {
        self.init(amount: amount, currency: currency)
    }

    static func zero(_ currency: String) -> Money {
        Money(amount: 0, currency: currency)
    }

    static func usd(_ amount: Decimal) -> Money {
        Money(amount: amount, currency: "USD")
    }

    static func + (lhs: Money, rhs: Money) -> Money {
        precondition(lhs.currency == rhs.currency, "Cannot add \(lhs.currency) + \(rhs.currency); convert via FX first")
        return Money(amount: lhs.amount + rhs.amount, currency: lhs.currency)
    }

    static func - (lhs: Money, rhs: Money) -> Money {
        precondition(lhs.currency == rhs.currency, "Cannot subtract \(rhs.currency) from \(lhs.currency); convert via FX first")
        return Money(amount: lhs.amount - rhs.amount, currency: lhs.currency)
    }

    static prefix func - (m: Money) -> Money {
        Money(amount: -m.amount, currency: m.currency)
    }

    static func * (lhs: Money, scalar: Decimal) -> Money {
        Money(amount: lhs.amount * scalar, currency: lhs.currency)
    }

    static func / (lhs: Money, scalar: Decimal) -> Money {
        Money(amount: lhs.amount / scalar, currency: lhs.currency)
    }

    static func < (lhs: Money, rhs: Money) -> Bool {
        precondition(lhs.currency == rhs.currency, "Cannot compare \(lhs.currency) vs \(rhs.currency)")
        return lhs.amount < rhs.amount
    }

    func formatted(locale: Locale? = nil) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = currency
        f.locale = locale ?? Money.formattingLocale(for: currency)
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f.string(from: amount as NSDecimalNumber) ?? "\(currency) \(amount)"
    }

    /// Locale chosen so each ISO code renders its bare symbol (e.g. `$`, not `US$`).
    private static func formattingLocale(for currency: String) -> Locale {
        switch currency {
        case "USD": return Locale(identifier: "en_US")
        case "EUR": return Locale(identifier: "de_DE")
        case "GBP": return Locale(identifier: "en_GB")
        case "JPY": return Locale(identifier: "ja_JP")
        case "CHF": return Locale(identifier: "de_CH")
        case "CAD": return Locale(identifier: "en_CA")
        case "AUD": return Locale(identifier: "en_AU")
        case "BRL": return Locale(identifier: "pt_BR")
        default: return .current
        }
    }
}
