import XCTest
import SwiftData
@testable import Folio

@MainActor
final class HistoricalQuoteServiceTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext { container.mainContext }

    override func setUp() async throws {
        container = try ModelContainer.folio(inMemory: true)
    }

    override func tearDown() async throws {
        container = nil
    }

    private func makeService() -> HistoricalQuoteService {
        let mock = MockQuoteProvider(seedBase: 11)
        return HistoricalQuoteService(
            container: container,
            stocks: mock,
            crypto: mock,
            fx: mock
        )
    }

    func testInitialStatusIsIdle() {
        XCTAssertEqual(makeService().status, .idle)
    }

    func testEnsureLoadedInsertsHistoricalRowsAndMovesToReady() async throws {
        let service = makeService()
        let assets = try context.fetch(FetchDescriptor<Asset>())
        XCTAssertGreaterThan(assets.count, 0)

        let before = try context.fetchCount(FetchDescriptor<HistoricalQuote>())
        await service.ensureLoaded(assets: assets, baseCurrency: "USD", range: .m1)
        let after = try context.fetchCount(FetchDescriptor<HistoricalQuote>())

        XCTAssertGreaterThan(after, before, "service should have inserted historical rows")
        XCTAssertEqual(service.status, .ready)
    }

    func testEnsureLoadedIsIdempotentWithinSameRange() async throws {
        let service = makeService()
        let assets = try context.fetch(FetchDescriptor<Asset>())

        await service.ensureLoaded(assets: assets, baseCurrency: "USD", range: .m1)
        let mid = try context.fetchCount(FetchDescriptor<HistoricalQuote>())

        await service.ensureLoaded(assets: assets, baseCurrency: "USD", range: .m1)
        let final = try context.fetchCount(FetchDescriptor<HistoricalQuote>())

        XCTAssertEqual(mid, final, "second call inside same range must not re-insert")
    }

    func testEnsureLoadedCompletesQuickly() async throws {
        // Both sleeves now go through batched concurrent fetches (no serial
        // inter-call delay), so a full load should finish well under a second
        // against the in-process mock.
        let service = makeService()
        let assets = try context.fetch(FetchDescriptor<Asset>())

        let start = Date()
        await service.ensureLoaded(assets: assets, baseCurrency: "USD", range: .m1)
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertLessThan(elapsed, 1.0, "batched fetch → fast completion")
    }
}
