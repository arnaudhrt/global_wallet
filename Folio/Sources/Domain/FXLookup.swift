import Foundation
import SwiftData

/// Builds an `fxAt(from, to, date)` closure backed by cached `[FXRate]` rows.
///
/// Lookup is forward-fill: for a given `date`, returns the rate of the latest
/// row whose `asOf <= date`. Missing pair → `nil` (caller decides whether that
/// means "skip" or "abort"). Identity pairs (`from == to`) return `1`.
///
/// Same semantics `HistoricalLookups.fxAt(rates:)` used to provide locally for
/// the M8.5 chart; extracted here so the spot-quote reducers in Stocks / Crypto
/// / Overview can consume the same FX cache once the M10 base-currency picker
/// makes non-USD a real possibility.
@MainActor
enum FXLookup {
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

    private static func latestRate(in series: [FXRate], onOrBefore target: Date) -> Decimal? {
        var lo = 0
        var hi = series.count
        while lo < hi {
            let mid = (lo + hi) / 2
            if series[mid].asOf <= target {
                lo = mid + 1
            } else {
                hi = mid
            }
        }
        return lo == 0 ? nil : series[lo - 1].rate
    }
}
