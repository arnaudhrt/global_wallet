import Foundation
import SwiftData

@Model
final class Account {
    var id: UUID
    @Attribute(.unique) var name: String
    var kind: AccountKind
    var mask: String
    var currency: String
    var colorHex: UInt32

    @Relationship(deleteRule: .cascade, inverse: \PortfolioTransaction.account)
    var transactions: [PortfolioTransaction] = []

    init(
        id: UUID = UUID(),
        name: String,
        kind: AccountKind,
        mask: String,
        currency: String,
        colorHex: UInt32
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.mask = mask
        self.currency = currency
        self.colorHex = colorHex
    }
}
