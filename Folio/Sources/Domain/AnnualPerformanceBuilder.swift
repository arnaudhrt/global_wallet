import Foundation

/// Per-year rows for the Overview Annual Performance table. Pure function over
/// a `[HistoryPoint]` series — same `@MainActor enum` posture as the other
/// builders so call sites in `OverviewScreen` don't have to switch contexts.
///
/// `portfolioPct` for a calendar year is `(last - first) / first * 100` for
/// points whose date falls within that year. Partial-year rows are allowed
/// (e.g. the current year through today). S&P 500 / Nasdaq columns are
/// intentionally omitted in MVP — `AnnualPerformanceCard` renders `—` for
/// them and the deferred follow-up is tracked in ROADMAP.
@MainActor
enum AnnualPerformanceBuilder {
    static func rows(history: [HistoryPoint]) -> [AnnualPerformanceRow] {
        guard !history.isEmpty else { return [] }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC") ?? .current

        let grouped = Dictionary(grouping: history) { cal.component(.year, from: $0.date) }
        let years = grouped.keys.sorted()

        var rows: [AnnualPerformanceRow] = []
        rows.reserveCapacity(years.count)
        for year in years {
            guard let points = grouped[year], let first = points.min(by: { $0.date < $1.date }), let last = points.max(by: { $0.date < $1.date }) else { continue }
            let startAmount = first.total.amount
            guard startAmount > 0 else {
                rows.append(AnnualPerformanceRow(year: year, portfolioPct: nil, badge: nil))
                continue
            }
            let pct = (last.total.amount - startAmount) / startAmount * 100
            rows.append(AnnualPerformanceRow(
                year: year,
                portfolioPct: Double(truncating: pct as NSDecimalNumber),
                badge: nil
            ))
        }

        // Tag the best/worst rows by portfolio % (skip nils). Only meaningful
        // when there's at least 2 rows with a real number.
        let scored = rows.enumerated().compactMap { i, r -> (Int, Double)? in
            guard let pct = r.portfolioPct else { return nil }
            return (i, pct)
        }
        if scored.count >= 2 {
            if let bestIdx = scored.max(by: { $0.1 < $1.1 })?.0 {
                rows[bestIdx] = rows[bestIdx].with(badge: .best)
            }
            if let worstIdx = scored.min(by: { $0.1 < $1.1 })?.0 {
                rows[worstIdx] = rows[worstIdx].with(badge: .worst)
            }
        }
        return rows
    }
}

struct AnnualPerformanceRow: Equatable, Sendable {
    enum Badge: Equatable, Sendable { case best, worst }

    let year: Int
    let portfolioPct: Double?
    let badge: Badge?

    func with(badge: Badge?) -> AnnualPerformanceRow {
        AnnualPerformanceRow(year: year, portfolioPct: portfolioPct, badge: badge)
    }
}
