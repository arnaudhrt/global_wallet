import Foundation
import SwiftData

@Model
final class FXRate {
    var id: UUID
    /// Composite natural key: `"\(from)/\(to)/\(yyyy-MM-dd)"`. Enforces one row
    /// per (pair, day, source) — duplicate-day refreshes are idempotent.
    @Attribute(.unique) var key: String
    var from: String
    var to: String
    var asOf: Date
    var rate: Decimal
    var source: String

    init(
        id: UUID = UUID(),
        from: String,
        to: String,
        asOf: Date,
        rate: Decimal,
        source: String
    ) {
        self.id = id
        self.from = from
        self.to = to
        self.asOf = asOf
        self.rate = rate
        self.source = source
        self.key = Self.makeKey(from: from, to: to, asOf: asOf)
    }

    static func makeKey(from: String, to: String, asOf: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        return "\(from)/\(to)/\(f.string(from: asOf))"
    }
}
