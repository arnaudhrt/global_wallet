import Foundation
import Observation

/// Tiny model behind the ⌘K toolbar search field. Holds the live `query` and
/// the most recent set of matches. Filtering is case-insensitive substring on
/// `symbol` + `name` — minimal for MVP; fuzzy ranking is v2 work.
@MainActor
@Observable
final class AssetSearch {
    var query: String = ""

    /// Returns up to `limit` matches from `assets`, preserving the input order.
    /// Empty / whitespace-only queries return no matches (we don't dump the
    /// full asset list into the popover by default).
    func matches(in assets: [Asset], limit: Int = 8) -> [Asset] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let needle = trimmed.lowercased()
        return assets
            .filter { asset in
                asset.symbol.lowercased().contains(needle)
                    || asset.name.lowercased().contains(needle)
            }
            .prefix(limit)
            .map { $0 }
    }

    func reset() {
        query = ""
    }
}
