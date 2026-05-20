import XCTest
@testable import Folio

final class MoneyTests: XCTestCase {
    func testEquality() {
        XCTAssertEqual(Money(amount: 10, currency: "USD"), Money.usd(10))
        XCTAssertNotEqual(Money.usd(10), Money(amount: 10, currency: "EUR"))
    }

    func testAddSameCurrency() {
        let a = Money.usd(100)
        let b = Money.usd(25.5)
        XCTAssertEqual((a + b).amount, Decimal(string: "125.5"))
        XCTAssertEqual((a + b).currency, "USD")
    }

    func testSubtractSameCurrency() {
        let result = Money.usd(100) - Money.usd(30)
        XCTAssertEqual(result, Money.usd(70))
    }

    func testUnaryMinus() {
        XCTAssertEqual(-Money.usd(10), Money(amount: -10, currency: "USD"))
    }

    func testScalarMultiplication() {
        let mv = Money.usd(50) * 3
        XCTAssertEqual(mv, Money.usd(150))
    }

    func testScalarDivision() {
        let avg = Money.usd(150) / 3
        XCTAssertEqual(avg, Money.usd(50))
    }

    func testZeroFactory() {
        XCTAssertEqual(Money.zero("EUR"), Money(amount: 0, currency: "EUR"))
    }

    func testFormattedUSD() {
        let formatted = Money.usd(1234.56).formatted(locale: Locale(identifier: "en_US"))
        XCTAssertEqual(formatted, "$1,234.56")
    }

    func testFormattedEUR() {
        let formatted = Money(amount: 1234.56, currency: "EUR").formatted(locale: Locale(identifier: "de_DE"))
        // de_DE puts the symbol after with comma decimal — exact form: "1.234,56 €"
        XCTAssertTrue(formatted.contains("1.234,56"), "Expected German-formatted EUR, got \(formatted)")
    }
}
