import Foundation
import SwiftData

/// Builds the `priceOn` and `fxAt` closures `PortfolioHistoryReducer` consumes,
/// backed by `[HistoricalQuote]` / `[FXRate]` already loaded in memory by
/// `@Query`. Lookups are forward-fill: for a target `date`, return the latest
/// row where `row.date <= date`. Missing data → nil (the reducer skips that
/// asset/day combo).
///
/// Lives next to `OverviewScreen` because nothing else needs these lookups yet.
@MainActor
enum HistoricalLookups {
    static func priceOn(quotes: [HistoricalQuote]) -> (Asset, Date) -> Decimal? {
        // Group + sort once so each per-day lookup is O(log n) via binary search.
        let grouped: [PersistentIdentifier: [HistoricalQuote]] = Dictionary(
            grouping: quotes,
            by: { $0.asset.persistentModelID }
        ).mapValues { $0.sorted(by: { $0.date < $1.date }) }

        return { asset, date in
            guard let series = grouped[asset.persistentModelID], !series.isEmpty else { return nil }
            return latestClose(in: series, onOrBefore: date)
        }
    }

    static func fxAt(rates: [FXRate]) -> (String, String, Date) -> Decimal? {
        struct PairKey: Hashable { let from: String; let to: String }
        let grouped: [PairKey: [FXRate]] = Dictionary(
            grouping: rates,
            by: { PairKey(from: $0.from, to: $0.to) }
        ).mapValues { $0.sorted(by: { $0.asOf < $1.asOf }) }

        return { from, to, date in
            if from == to { return 1 }
            guard let series = grouped[PairKey(from: from, to: to)], !series.isEmpty else { return nil }
            return latestRate(in: series, onOrBefore: date)
        }
    }

    // MARK: - Forward-fill binary search

    private static func latestClose(in series: [HistoricalQuote], onOrBefore target: Date) -> Decimal? {
        guard let idx = upperBound(in: series, key: \.date, target: target) else { return nil }
        return series[idx].close
    }

    private static func latestRate(in series: [FXRate], onOrBefore target: Date) -> Decimal? {
        guard let idx = upperBound(in: series, key: \.asOf, target: target) else { return nil }
        return series[idx].rate
    }

    /// Returns the index of the last element whose `key` is `<= target`,
    /// or nil if even the first element is past the target.
    private static func upperBound<T>(in series: [T], key: (T) -> Date, target: Date) -> Int? {
        var lo = 0
        var hi = series.count
        while lo < hi {
            let mid = (lo + hi) / 2
            if key(series[mid]) <= target {
                lo = mid + 1
            } else {
                hi = mid
            }
        }
        // After loop, `lo` is the count of elements with key <= target.
        return lo == 0 ? nil : lo - 1
    }

    private static func upperBound<T>(in series: [T], key: KeyPath<T, Date>, target: Date) -> Int? {
        upperBound(in: series, key: { $0[keyPath: key] }, target: target)
    }
}
