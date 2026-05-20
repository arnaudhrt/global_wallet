import Foundation
import SwiftData

/// Ledger entry. Named `PortfolioTransaction` to avoid colliding with SwiftUI's
/// `Transaction` type — UI labels still say "Transactions".
@Model
final class PortfolioTransaction {
    var id: UUID
    var date: Date
    var type: TransactionType

    /// Nil for cash events (deposit / withdraw / cash-only transfer).
    var asset: Asset?
    var account: Account
    /// Only set when `type == .transfer`. No declared inverse — SwiftData
    /// would otherwise ambiguate against `account`.
    var transferDestination: Account?

    /// Unit quantity of `asset`. Nil for cash events.
    var quantity: Decimal?
    /// Per-unit price at txn time, in `currency`. Nil for cash events.
    var price: Decimal?

    /// Gross transaction amount (qty × price, or cash amount). Always set.
    var amount: Decimal
    var currency: String

    var fee: Decimal
    var feeCurrency: String

    var notes: String

    init(
        id: UUID = UUID(),
        date: Date,
        type: TransactionType,
        asset: Asset?,
        account: Account,
        transferDestination: Account? = nil,
        quantity: Decimal? = nil,
        price: Decimal? = nil,
        amount: Decimal,
        currency: String,
        fee: Decimal = 0,
        feeCurrency: String? = nil,
        notes: String = ""
    ) {
        self.id = id
        self.date = date
        self.type = type
        self.asset = asset
        self.account = account
        self.transferDestination = transferDestination
        self.quantity = quantity
        self.price = price
        self.amount = amount
        self.currency = currency
        self.fee = fee
        self.feeCurrency = feeCurrency ?? currency
        self.notes = notes
    }

    var totalMoney: Money {
        get { Money(amount: amount, currency: currency) }
        set { amount = newValue.amount; currency = newValue.currency }
    }

    var feeMoney: Money {
        get { Money(amount: fee, currency: feeCurrency) }
        set { fee = newValue.amount; feeCurrency = newValue.currency }
    }
}
