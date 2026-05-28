import XCTest
import SwiftData
@testable import Folio

@MainActor
final class SettingsTests: XCTestCase {
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

    func testThemeOverrideDefaultsToSystem() {
        let settings = AppSettings()
        XCTAssertEqual(settings.themeOverrideEnum, .system)
    }

    func testThemeOverrideRoundTripsThroughRawValue() {
        let settings = AppSettings()
        context.insert(settings)
        settings.themeOverrideEnum = .dark
        try? context.save()

        let fetched = try! context.fetch(FetchDescriptor<AppSettings>()).first!
        XCTAssertEqual(fetched.themeOverride, "dark")
        XCTAssertEqual(fetched.themeOverrideEnum, .dark)
    }

    func testUnknownThemeOverrideFallsBackToSystem() {
        let settings = AppSettings()
        settings.themeOverride = "neon-cyberpunk"
        XCTAssertEqual(settings.themeOverrideEnum, .system)
    }

    func testBaseCurrencyMutationPersists() {
        let settings = AppSettings()
        context.insert(settings)
        settings.baseCurrency = "EUR"
        try? context.save()

        let fetched = try! context.fetch(FetchDescriptor<AppSettings>()).first!
        XCTAssertEqual(fetched.baseCurrency, "EUR")
    }

    func testSupportedCurrenciesCoversCuratedSet() {
        // Locked in M10 — anything outside this set isn't reachable via the
        // picker UI; the test guards against accidental list drift.
        XCTAssertEqual(
            SettingsSheet.supportedCurrencies,
            ["USD", "EUR", "GBP", "JPY", "CHF", "CAD", "AUD", "BRL"]
        )
    }
}
