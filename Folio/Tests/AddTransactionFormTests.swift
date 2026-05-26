import XCTest
import SwiftData
@testable import Folio

@MainActor
final class AddTransactionFormTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext { container.mainContext }

    override func setUp() async throws {
        container = try ModelContainer(
            for: Account.self, Asset.self, PortfolioTransaction.self,
                 PriceQuote.self, FXRate.self, AppSettings.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    override func tearDown() async throws {
        container = nil
    }

    // MARK: - Fixture helpers

    private func account(_ name: String, kind: AccountKind = .brokerage, currency: String = "USD") -> Account {
        let a = Account(name: name, kind: kind, mask: "•", currency: currency, colorHex: 0)
        context.insert(a)
        return a
    }

    private func asset(_ symbol: String, kind: AssetKind = .stock, currency: String = "USD") -> Asset {
        let a = Asset(symbol: symbol, name: symbol, kind: kind, currency: currency, colorHex: 0)
        context.insert(a)
        return a
    }

    // MARK: - Decimal parsing

    func testParseDecimalAcceptsPlainDigits() {
        XCTAssertEqual(AddTransactionForm.parseDecimal("1234.56"), Decimal(string: "1234.56"))
    }

    func testParseDecimalAcceptsUSGroupingSeparator() {
        XCTAssertEqual(AddTransactionForm.parseDecimal("1,234.56"), Decimal(string: "1234.56"))
    }

    func testParseDecimalAcceptsEUDecimalComma() {
        XCTAssertEqual(AddTransactionForm.parseDecimal("1234,56"), Decimal(string: "1234.56"))
    }

    func testParseDecimalRejectsEmpty() {
        XCTAssertNil(AddTransactionForm.parseDecimal(""))
        XCTAssertNil(AddTransactionForm.parseDecimal("   "))
    }

    // MARK: - Validation

    func testValidationFailsWhenAccountMissing() {
        let form = AddTransactionForm()
        XCTAssertEqual(form.validate(), .missingAccount)
    }

    func testValidationFailsForBuyWithoutAsset() {
        let form = AddTransactionForm()
        form.account = account("Schwab")
        form.quantityText = "10"
        form.priceText = "150"
        XCTAssertEqual(form.validate(), .missingAsset)
    }

    func testValidationFailsForBuyWithZeroQty() {
        let form = AddTransactionForm()
        form.account = account("Schwab")
        form.asset = asset("AAPL")
        form.quantityText = "0"
        form.priceText = "150"
        XCTAssertEqual(form.validate(), .nonPositiveQuantity)
    }

    func testValidationFailsForBuyWithNegativePrice() {
        let form = AddTransactionForm()
        form.account = account("Schwab")
        form.asset = asset("AAPL")
        form.quantityText = "10"
        form.priceText = "-1"
        XCTAssertEqual(form.validate(), .negativePrice)
    }

    func testValidationFailsForDepositWithZeroAmount() {
        let form = AddTransactionForm()
        form.type = .deposit
        form.account = account("Schwab")
        form.amountText = "0"
        XCTAssertEqual(form.validate(), .nonPositiveAmount)
    }

    func testValidationFailsForTransferWithSameSourceAndDest() {
        let form = AddTransactionForm()
        form.type = .transfer
        let acc = account("Schwab")
        form.account = acc
        form.transferDestination = acc
        form.amountText = "100"
        XCTAssertEqual(form.validate(), .sameSourceAndDestination)
    }

    // MARK: - Build outputs

    func testBuildProducesBuyTxn() {
        let form = AddTransactionForm()
        let acc = account("Schwab")
        let aapl = asset("AAPL")
        form.type = .buy
        form.account = acc
        form.asset = aapl
        form.quantityText = "10"
        form.priceText = "150.50"
        let txn = form.build()
        XCTAssertNotNil(txn)
        XCTAssertEqual(txn?.type, .buy)
        XCTAssertEqual(txn?.asset?.symbol, "AAPL")
        XCTAssertEqual(txn?.quantity, Decimal(10))
        XCTAssertEqual(txn?.price, Decimal(string: "150.50"))
        XCTAssertEqual(txn?.amount, Decimal(string: "1505.0"))
        XCTAssertEqual(txn?.currency, "USD")
    }

    func testBuildProducesDividendTxnWithNoQtyOrPrice() {
        let form = AddTransactionForm()
        form.type = .dividend
        form.account = account("Schwab")
        form.asset = asset("MSFT")
        form.amountText = "108.75"
        let txn = form.build()
        XCTAssertNotNil(txn)
        XCTAssertEqual(txn?.type, .dividend)
        XCTAssertNil(txn?.quantity)
        XCTAssertNil(txn?.price)
        XCTAssertEqual(txn?.amount, Decimal(string: "108.75"))
    }

    func testBuildProducesDepositWithNoAsset() {
        let form = AddTransactionForm()
        form.type = .deposit
        form.account = account("Schwab")
        form.amountText = "10000"
        let txn = form.build()
        XCTAssertNotNil(txn)
        XCTAssertNil(txn?.asset)
        XCTAssertEqual(txn?.amount, Decimal(10000))
    }

    func testBuildProducesTransferWithDestination() {
        let form = AddTransactionForm()
        form.type = .transfer
        let src = account("Schwab")
        let dst = account("Fidelity")
        form.account = src
        form.transferDestination = dst
        form.amountText = "5000"
        let txn = form.build()
        XCTAssertNotNil(txn)
        XCTAssertEqual(txn?.transferDestination?.name, "Fidelity")
        XCTAssertEqual(txn?.account.name, "Schwab")
        XCTAssertEqual(txn?.amount, Decimal(5000))
    }

    // MARK: - Currency derivation

    func testEffectiveCurrencyFollowsAssetForTrades() {
        let form = AddTransactionForm()
        form.type = .buy
        form.account = account("Brk", kind: .brokerage, currency: "USD")
        form.asset = asset("ASML", currency: "EUR")
        XCTAssertEqual(form.effectiveCurrency, "EUR")
        XCTAssertTrue(form.needsFXPreview)
    }

    func testEffectiveCurrencyFollowsAccountForCashEvents() {
        let form = AddTransactionForm()
        form.type = .deposit
        form.account = account("EU", currency: "EUR")
        XCTAssertEqual(form.effectiveCurrency, "EUR")
        XCTAssertFalse(form.needsFXPreview)
    }

    // MARK: - Type adaptivity

    func testNeedsFlagsForEachType() {
        let form = AddTransactionForm()

        form.type = .buy
        XCTAssertTrue(form.needsAsset)
        XCTAssertTrue(form.needsQtyPrice)
        XCTAssertFalse(form.needsAmount)
        XCTAssertFalse(form.needsDestination)

        form.type = .dividend
        XCTAssertTrue(form.needsAsset)
        XCTAssertFalse(form.needsQtyPrice)
        XCTAssertTrue(form.needsAmount)

        form.type = .deposit
        XCTAssertFalse(form.needsAsset)
        XCTAssertFalse(form.needsQtyPrice)
        XCTAssertTrue(form.needsAmount)

        form.type = .transfer
        XCTAssertFalse(form.needsAsset)
        XCTAssertTrue(form.needsAmount)
        XCTAssertTrue(form.needsDestination)
    }
}
