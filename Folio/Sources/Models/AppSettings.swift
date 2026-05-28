import Foundation
import SwiftData

/// Singleton-by-convention: exactly one row, ensured by `ModelContainer.folio()`.
@Model
final class AppSettings {
    var id: UUID
    var baseCurrency: String
    var lastQuoteRefresh: Date?
    /// Persisted as the raw value of `ThemeOverride`. `themeOverrideEnum` is the
    /// safe accessor — unknown values fall back to `.system` rather than crashing.
    var themeOverride: String

    init(
        id: UUID = UUID(),
        baseCurrency: String = "USD",
        lastQuoteRefresh: Date? = nil,
        themeOverride: String = ThemeOverride.system.rawValue
    ) {
        self.id = id
        self.baseCurrency = baseCurrency
        self.lastQuoteRefresh = lastQuoteRefresh
        self.themeOverride = themeOverride
    }

    var themeOverrideEnum: ThemeOverride {
        get { ThemeOverride(rawValue: themeOverride) ?? .system }
        set { themeOverride = newValue.rawValue }
    }
}
