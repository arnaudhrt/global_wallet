import Foundation
import SwiftData

/// Singleton-by-convention: exactly one row, ensured by `ModelContainer.folio()`.
@Model
final class AppSettings {
    var id: UUID
    var baseCurrency: String
    var lastQuoteRefresh: Date?

    init(
        id: UUID = UUID(),
        baseCurrency: String = "USD",
        lastQuoteRefresh: Date? = nil
    ) {
        self.id = id
        self.baseCurrency = baseCurrency
        self.lastQuoteRefresh = lastQuoteRefresh
    }
}
