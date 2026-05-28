import XCTest
import SwiftData
@testable import Folio

@MainActor
final class AssetSearchTests: XCTestCase {
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

    private func asset(_ symbol: String, _ name: String, kind: AssetKind = .stock) -> Asset {
        let a = Asset(symbol: symbol, name: name, kind: kind, currency: "USD", colorHex: 0)
        context.insert(a)
        return a
    }

    private func sampleAssets() -> [Asset] {
        let btc = asset("BTC", "Bitcoin", kind: .crypto)
        let eth = asset("ETH", "Ethereum", kind: .crypto)
        let aapl = asset("AAPL", "Apple Inc.")
        let msft = asset("MSFT", "Microsoft Corporation")
        return [btc, eth, aapl, msft]
    }

    func testEmptyQueryReturnsNothing() {
        let s = AssetSearch()
        s.query = ""
        XCTAssertTrue(s.matches(in: sampleAssets()).isEmpty)
    }

    func testWhitespaceOnlyQueryReturnsNothing() {
        let s = AssetSearch()
        s.query = "   "
        XCTAssertTrue(s.matches(in: sampleAssets()).isEmpty)
    }

    func testTickerCaseInsensitive() {
        let s = AssetSearch()
        let assets = sampleAssets()
        s.query = "btc"
        XCTAssertEqual(s.matches(in: assets).map(\.symbol), ["BTC"])
        s.query = "BTC"
        XCTAssertEqual(s.matches(in: assets).map(\.symbol), ["BTC"])
    }

    func testMatchesByName() {
        let s = AssetSearch()
        s.query = "microsoft"
        XCTAssertEqual(s.matches(in: sampleAssets()).map(\.symbol), ["MSFT"])
    }

    func testSubstringMatch() {
        let s = AssetSearch()
        s.query = "eth"
        let symbols = s.matches(in: sampleAssets()).map(\.symbol)
        XCTAssertTrue(symbols.contains("ETH"))
    }

    func testLimitCapsResults() {
        let s = AssetSearch()
        let many = (0..<20).map { asset("SYM\($0)", "Asset \($0)") }
        s.query = "asset"
        XCTAssertEqual(s.matches(in: many, limit: 5).count, 5)
    }

    func testResetClearsQuery() {
        let s = AssetSearch()
        s.query = "btc"
        s.reset()
        XCTAssertEqual(s.query, "")
        XCTAssertTrue(s.matches(in: sampleAssets()).isEmpty)
    }
}
