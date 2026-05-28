import Foundation
import SwiftData
import Observation

/// Lazily populates `HistoricalQuote` + `FXRate` rows for the Overview chart.
/// Called from `OverviewScreen.task(id: range)` — no timer, no auto-refresh.
/// Historicals are immutable so once a (asset, day) row exists we never refetch
/// it.
///
/// Stocks/ETFs (Yahoo) fan out in parallel. Crypto (CoinGecko) is rate-limited
/// to ~30 req/min on the free tier, so we walk the assets serially with a 1-
/// second gap between requests. FX pairs go through the same Yahoo endpoint as
/// stocks and fan out in parallel.
@MainActor
@Observable
final class HistoricalQuoteService {
    enum Status: Equatable {
        case idle
        case fetching
        case ready
        case partialFailure(String)
    }

    private(set) var status: Status = .idle

    private let container: ModelContainer
    private let stocks: any QuoteProvider
    private let crypto: any QuoteProvider
    private let fx: any FXProvider
    private let cryptoDelay: TimeInterval

    init(
        container: ModelContainer,
        stocks: any QuoteProvider,
        crypto: any QuoteProvider,
        fx: any FXProvider,
        cryptoDelay: TimeInterval = 1.0
    ) {
        self.container = container
        self.stocks = stocks
        self.crypto = crypto
        self.fx = fx
        self.cryptoDelay = cryptoDelay
    }

    /// Idempotent: each call only fetches the (asset, day) rows missing from
    /// the store for the requested range. Safe to call on every Overview paint.
    func ensureLoaded(assets: [Asset], baseCurrency: String, range: QuoteRange) async {
        guard !isFetching else { return }
        status = .fetching

        let context = container.mainContext
        let floor = floorDate(for: range)
        let stockSpecs = assets
            .filter { $0.kind == .stock || $0.kind == .etf }
            .map { AssetSpec(id: $0.persistentModelID, symbol: $0.symbol, currency: $0.currency) }
        let cryptoSpecs = assets
            .filter { $0.kind == .crypto }
            .map { AssetSpec(id: $0.persistentModelID, symbol: $0.symbol, currency: $0.currency) }

        // Skip assets whose existing rows already cover [floor, today]. We
        // approximate "covered" as "has at least one row on or before `floor`"
        // — the reducer's forward-fill handles the rest. Cheaper than diffing
        // every day in the range.
        let stocksToFetch = stockSpecs.filter { !hasCoverage(assetID: $0.id, source: "yahoo", at: floor, context: context) }
        let cryptoToFetch = cryptoSpecs.filter { !hasCoverage(assetID: $0.id, source: "coingecko", at: floor, context: context) }
        let fxPairs = collectFXPairs(assets: assets, baseCurrency: baseCurrency)
        let fxToFetch = fxPairs.filter { !hasFXCoverage(pair: $0, at: floor, context: context) }

        async let stockResults  = fetchStocks(stocksToFetch, range: range)
        async let fxResults     = fetchFX(pairs: fxToFetch, range: range)
        let cryptoResults       = await fetchCryptoSerially(cryptoToFetch, range: range)
        let (stocks, fx) = await (stockResults, fxResults)

        var successes = 0
        var failures: [String] = []

        for (spec, result) in stocks {
            switch result {
            case .success(let points):
                persist(points, assetID: spec.id, source: "yahoo", currency: spec.currency, context: context)
                successes += 1
            case .failure(let err):
                failures.append("\(spec.symbol): \(err.localizedDescription)")
            }
        }
        for (spec, result) in cryptoResults {
            switch result {
            case .success(let points):
                persist(points, assetID: spec.id, source: "coingecko", currency: spec.currency, context: context)
                successes += 1
            case .failure(let err):
                failures.append("\(spec.symbol): \(err.localizedDescription)")
            }
        }
        for (pair, result) in fx {
            switch result {
            case .success(let points):
                persistFX(points, pair: pair, context: context)
                successes += 1
            case .failure(let err):
                failures.append("\(pair.from)→\(pair.to): \(err.localizedDescription)")
            }
        }

        do {
            try context.save()
        } catch {
            // Likely a unique-key collision on a (asset, source, day) row that
            // a parallel call already wrote — non-fatal, partial successes are
            // already in the store.
            FolioLog.history.error("HistoricalQuoteService save error: \(error.localizedDescription, privacy: .public)")
        }

        if failures.isEmpty {
            status = .ready
        } else if successes > 0 {
            status = .partialFailure(failures.joined(separator: "; "))
        } else if !stocksToFetch.isEmpty || !cryptoToFetch.isEmpty || !fxToFetch.isEmpty {
            status = .partialFailure(failures.first ?? "no historicals fetched")
        } else {
            // Nothing to do; treat as ready so the UI doesn't sit in a loading state.
            status = .ready
        }
    }

    // MARK: - Status

    var isFetching: Bool {
        if case .fetching = status { return true }
        return false
    }

    // MARK: - Internal types

    private struct AssetSpec: Sendable {
        let id: PersistentIdentifier
        let symbol: String
        let currency: String
    }

    private struct FXPair: Hashable, Sendable {
        let from: String
        let to: String
    }

    // MARK: - Fetching

    private func fetchStocks(_ specs: [AssetSpec], range: QuoteRange) async -> [(AssetSpec, Result<[HistoricalPoint], Error>)] {
        guard !specs.isEmpty else { return [] }
        let provider = stocks
        return await withTaskGroup(of: (AssetSpec, Result<[HistoricalPoint], Error>).self) { group in
            for spec in specs {
                group.addTask {
                    do {
                        let points = try await provider.historical(symbol: spec.symbol, range: range)
                        return (spec, .success(points))
                    } catch {
                        return (spec, .failure(error))
                    }
                }
            }
            var out: [(AssetSpec, Result<[HistoricalPoint], Error>)] = []
            while let r = await group.next() { out.append(r) }
            return out
        }
    }

    private func fetchCryptoSerially(_ specs: [AssetSpec], range: QuoteRange) async -> [(AssetSpec, Result<[HistoricalPoint], Error>)] {
        var out: [(AssetSpec, Result<[HistoricalPoint], Error>)] = []
        out.reserveCapacity(specs.count)
        for (i, spec) in specs.enumerated() {
            do {
                let points = try await crypto.historical(symbol: spec.symbol, range: range)
                out.append((spec, .success(points)))
            } catch {
                out.append((spec, .failure(error)))
            }
            // Space requests out so the free-tier limit doesn't bite. Skip the
            // sleep after the last call.
            if i < specs.count - 1, cryptoDelay > 0 {
                try? await Task.sleep(nanoseconds: UInt64(cryptoDelay * 1_000_000_000))
            }
        }
        return out
    }

    private func fetchFX(pairs: [FXPair], range: QuoteRange) async -> [(FXPair, Result<[HistoricalFXPoint], Error>)] {
        guard !pairs.isEmpty else { return [] }
        let provider = fx
        return await withTaskGroup(of: (FXPair, Result<[HistoricalFXPoint], Error>).self) { group in
            for pair in pairs {
                group.addTask {
                    do {
                        let points = try await provider.historical(from: pair.from, to: pair.to, range: range)
                        return (pair, .success(points))
                    } catch {
                        return (pair, .failure(error))
                    }
                }
            }
            var out: [(FXPair, Result<[HistoricalFXPoint], Error>)] = []
            while let r = await group.next() { out.append(r) }
            return out
        }
    }

    // MARK: - Persistence

    private func persist(
        _ points: [HistoricalPoint],
        assetID: PersistentIdentifier,
        source: String,
        currency: String,
        context: ModelContext
    ) {
        guard let asset = context.model(for: assetID) as? Asset else { return }
        // Look up existing keys once to avoid one fetch per point.
        let existing: Set<String> = {
            let prefix = "\(asset.symbol)/\(source)/"
            return Set(asset.historicalQuotes
                .filter { $0.source == source }
                .map { $0.key }
                .filter { $0.hasPrefix(prefix) })
        }()
        for point in points {
            let key = HistoricalQuote.makeKey(assetSymbol: asset.symbol, source: source, date: point.date)
            if existing.contains(key) { continue }
            let row = HistoricalQuote(
                asset: asset,
                date: point.date,
                close: point.close,
                currency: currency,
                source: source
            )
            context.insert(row)
        }
    }

    private func persistFX(_ points: [HistoricalFXPoint], pair: FXPair, context: ModelContext) {
        // Reuse the existing FXRate model — its unique key already covers
        // (from, to, day) so re-fetches of the same day are a no-op insert
        // (SwiftData ignores the duplicate at save time).
        for point in points {
            let row = FXRate(
                from: pair.from,
                to: pair.to,
                asOf: point.date,
                rate: point.rate,
                source: "yahoo"
            )
            context.insert(row)
        }
    }

    // MARK: - Coverage checks

    private func hasCoverage(
        assetID: PersistentIdentifier,
        source: String,
        at floor: Date,
        context: ModelContext
    ) -> Bool {
        guard let asset = context.model(for: assetID) as? Asset else { return true }
        // "Covered" = at least one row on or before the floor for this source.
        // The reducer's forward-fill carries it from there.
        return asset.historicalQuotes.contains { $0.source == source && $0.date <= floor }
    }

    private func hasFXCoverage(pair: FXPair, at floor: Date, context: ModelContext) -> Bool {
        if pair.from == pair.to { return true }
        do {
            let from = pair.from
            let to = pair.to
            let descriptor = FetchDescriptor<FXRate>(
                predicate: #Predicate { $0.from == from && $0.to == to }
            )
            let rows = try context.fetch(descriptor)
            return rows.contains { $0.asOf <= floor }
        } catch {
            return false
        }
    }

    // MARK: - Helpers

    private func collectFXPairs(assets: [Asset], baseCurrency: String) -> [FXPair] {
        var pairs: Set<FXPair> = []
        for asset in assets where asset.currency != baseCurrency {
            pairs.insert(FXPair(from: asset.currency, to: baseCurrency))
        }
        return Array(pairs)
    }

    private func floorDate(for range: QuoteRange) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC") ?? .current
        let days = range.days()
        return cal.date(byAdding: .day, value: -days, to: cal.startOfDay(for: Date())) ?? Date()
    }
}
