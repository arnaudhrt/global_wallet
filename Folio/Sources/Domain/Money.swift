import Foundation

/// `Decimal`-backed money value with an ISO 4217 currency tag. Binary operators
/// trap on mixed-currency math — convert via FX first.
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
