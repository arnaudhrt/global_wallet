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

    private func makeService(cryptoDelay: TimeInterval = 0) -> HistoricalQuoteService {
        let mock = MockQuoteProvider(seedBase: 11)
        return HistoricalQuoteService(
            container: container,
            stocks: mock,
            crypto: mock,
            fx: mock,
            cryptoDelay: cryptoDelay
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

    func testEnsureLoadedSkipsCryptoDelayWhenZero() async throws {
        // The crypto branch is serial — with delay=0 we still serialize calls,
        // but the test asserts the call completes in well under a second so
        // the per-iteration sleep is genuinely zero.
        let service = makeService(cryptoDelay: 0)
        let assets = try context.fetch(FetchDescriptor<Asset>())

        let start = Date()
        await service.ensureLoaded(assets: assets, baseCurrency: "USD", range: .m1)
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertLessThan(elapsed, 1.0, "no inter-call delay → fast completion")
    }
}
