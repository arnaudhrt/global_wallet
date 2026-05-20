import Foundation
import SwiftData

@Model
final class PriceQuote {
    var id: UUID
    var asset: Asset
    var asOf: Date
    var amount: Decimal
    var currency: String
    var source: String

    init(
        id: UUID = UUID(),
        asset: Asset,
        asOf: Date,
        amount: Decimal,
        currency: String,
        source: String
    ) {
        self.id = id
        self.asset = asset
        self.asOf = asOf
        self.amount = amount
        self.currency = currency
        self.source = source
    }

    var priceMoney: Money {
        get { Money(amount: amount, currency: currency) }
        set { amount = newValue.amount; currency = newValue.currency }
    }
}
