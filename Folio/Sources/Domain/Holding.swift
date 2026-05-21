import Foundation
import SwiftData

/// Projected holding row produced by `HoldingsReducer`. Pure value type — does
/// not hit SwiftData on its own.
///
/// `account` is nil for the per-asset rollup view; non-nil for the per-(asset,
/// account) view used by the Crypto expand-per-wallet rows. `marketValue` /
/// `unrealizedPnL` / `unrealizedPnLPct` are nil when the price closure returns
/// nil for this asset.
///
/// `id` is derived from the (asset, account) `PersistentIdentifier`s so SwiftUI
/// `ForEach` keeps per-row state (selection, hover, expansion) stable across
/// reducer re-runs. A `UUID()` per call would discard that state on every
/// `@Query` update.
struct Holding: Identifiable, Hashable {
    struct ID: Hashable {
        let assetID: PersistentIdentifier
        let accountID: PersistentIdentifier?
    }

    let id: ID
    let asset: Asset
    let account: Account?
    let qty: Decimal
    let avgCost: Money
    let marketValue: Money?
    let unrealizedPnL: Money?
    let unrealizedPnLPct: Double?

    static func == (lhs: Holding, rhs: Holding) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
