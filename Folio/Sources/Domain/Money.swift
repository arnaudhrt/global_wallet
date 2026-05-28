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

    func formatted(locale: Locale = .current) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = currency
        f.locale = locale
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f.string(from: amount as NSDecimalNumber) ?? "\(currency) \(amount)"
    }
}
