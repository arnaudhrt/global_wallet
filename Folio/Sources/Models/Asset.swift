import Foundation
import SwiftData

@Model
final class Asset {
    var id: UUID
    @Attribute(.unique) var symbol: String
    var name: String
    var kind: AssetKind
    var currency: String
    var colorHex: UInt32

    @Relationship(deleteRule: .nullify, inverse: \PortfolioTransaction.asset)
    var transactions: [PortfolioTransaction] = []

    @Relationship(deleteRule: .cascade, inverse: \PriceQuote.asset)
    var quotes: [PriceQuote] = []

    init(
        id: UUID = UUID(),
        symbol: String,
        name: String,
        kind: AssetKind,
        currency: String,
        colorHex: UInt32 = 0x8E8E93
    ) {
        self.id = id
        self.symbol = symbol
        self.name = name
        self.kind = kind
        self.currency = currency
        self.colorHex = colorHex
    }
}
