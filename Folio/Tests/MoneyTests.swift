import XCTest
@testable import Folio

final class MoneyTests: XCTestCase {
    private let oneTwentyFive: Decimal = Decimal(string: "125.5")!
    private let twelveThirtyFour: Decimal = Decimal(string: "1234.56")!

    func testEquality() {
        XCTAssertEqual(Money(amount: 10, currency: "USD"), Money.usd(10))
        XCTAssertNotEqual(Money.usd(10), Money(amount: 10, currency: "EUR"))
    }

    func testAddSameCurrency() {
        let a = Money.usd(100)
        let b = Money.usd(Decimal(string: "25.5")!)
        XCTAssertEqual((a + b).amount, oneTwentyFive)
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
        let formatted = Money.usd(twelveThirtyFour).formatted(locale: Locale(identifier: "en_US"))
        XCTAssertEqual(formatted, "$1,234.56")
    }

    func testFormattedEUR() {
        let formatted = Money(amount: twelveThirtyFour, currency: "EUR").formatted(locale: Locale(identifier: "de_DE"))
        // de_DE puts the symbol after with comma decimal — exact form: "1.234,56 €"
        XCTAssertTrue(formatted.contains("1.234,56"), "Expected German-formatted EUR, got \(formatted)")
    }

    // MARK: - Decimal correctness (the reason Money exists, not Double)

    func testAddsAvoidBinaryFloatArtifacts() {
        // 0.1 + 0.2 = 0.3 exactly under Decimal arithmetic; Double gives 0.30000000000000004.
        let result = Money.usd(Decimal(string: "0.1")!) + Money.usd(Decimal(string: "0.2")!)
        XCTAssertEqual(result.amount, Decimal(string: "0.3"))
    }

    func testHighPrecisionCrypto() {
        // 1 satoshi == 0.00000001 BTC. Decimal preserves that exactly.
        let oneSat = Decimal(string: "0.00000001")!
        let m = Money(amount: oneSat, currency: "BTC")
        XCTAssertEqual(m.amount, oneSat)
        let hundred = m * 100
        XCTAssertEqual(hundred.amount, Decimal(string: "0.000001"))
    }

    func testNegativeAmounts() {
        let m = Money.usd(-50)
        XCTAssertEqual(m.amount, -50)
        XCTAssertEqual((m + Money.usd(30)).amount, -20)
    }

    func testZeroEqualsZeroAcrossInits() {
        XCTAssertEqual(Money.zero("USD"), Money.usd(0))
        XCTAssertEqual(Money.zero("USD").amount, Decimal(0))
    }

    func testVeryLargeAmount() {
        let trillion = Decimal(string: "1000000000000.99")!
        let m = Money(amount: trillion, currency: "USD")
        XCTAssertEqual(m.amount, trillion)
        XCTAssertEqual((m + Money.usd(Decimal(string: "0.01")!)).amount, Decimal(string: "1000000000001.00"))
    }
}
