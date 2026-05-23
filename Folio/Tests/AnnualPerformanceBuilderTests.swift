import XCTest
@testable import Folio

@MainActor
final class AnnualPerformanceBuilderTests: XCTestCase {
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC") ?? .current
        return cal
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? Date()
    }

    private func point(_ year: Int, _ month: Int, _ day: Int, _ amount: Decimal) -> HistoryPoint {
        HistoryPoint(date: date(year, month, day), total: Money(amount: amount, currency: "USD"))
    }

    func testEmptyHistoryYieldsNoRows() {
        XCTAssertEqual(AnnualPerformanceBuilder.rows(history: []), [])
    }

    func testSingleYearProducesOneRowNoBadge() {
        let history = [
            point(2025, 1, 5, 100),
            point(2025, 6, 5, 110),
            point(2025, 12, 30, 120),
        ]
        let rows = AnnualPerformanceBuilder.rows(history: history)
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows.first?.year, 2025)
        // (120 - 100) / 100 = 20.0
        XCTAssertEqual(rows.first?.portfolioPct ?? 0, 20.0, accuracy: 0.0001)
        XCTAssertNil(rows.first?.badge, "single-row table has no BEST/WORST")
    }

    func testMultiYearTagsBestAndWorst() {
        let history = [
            // 2023: 100 → 90 (worst, -10%)
            point(2023, 1, 1, 100),
            point(2023, 12, 31, 90),
            // 2024: 90 → 108 (mid, +20%)
            point(2024, 1, 1, 90),
            point(2024, 12, 31, 108),
            // 2025: 108 → 162 (best, +50%)
            point(2025, 1, 1, 108),
            point(2025, 12, 31, 162),
        ]
        let rows = AnnualPerformanceBuilder.rows(history: history)
        XCTAssertEqual(rows.count, 3)
        XCTAssertEqual(rows.map(\.year), [2023, 2024, 2025])
        XCTAssertEqual(rows[0].badge, .worst)
        XCTAssertNil(rows[1].badge)
        XCTAssertEqual(rows[2].badge, .best)
    }

    func testZeroStartingAmountYieldsNilPctButRowStillPresent() {
        let history = [
            point(2024, 1, 1, 0),
            point(2024, 12, 31, 100),
            point(2025, 1, 1, 100),
            point(2025, 12, 31, 110),
        ]
        let rows = AnnualPerformanceBuilder.rows(history: history)
        XCTAssertEqual(rows.count, 2)
        XCTAssertNil(rows[0].portfolioPct, "no baseline → undefined pct")
        XCTAssertEqual(rows[1].portfolioPct ?? 0, 10.0, accuracy: 0.0001)
    }

    func testPartialYearAllowed() {
        // 2026 has only one point — pct based on first/last (same value) is 0.
        let history = [
            point(2025, 1, 1, 100),
            point(2025, 12, 31, 120),
            point(2026, 3, 15, 130),
        ]
        let rows = AnnualPerformanceBuilder.rows(history: history)
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows[1].year, 2026)
        // Single point per year: first == last → 0% (acceptable partial-year)
        XCTAssertEqual(rows[1].portfolioPct ?? 1, 0.0, accuracy: 0.0001)
    }
}
