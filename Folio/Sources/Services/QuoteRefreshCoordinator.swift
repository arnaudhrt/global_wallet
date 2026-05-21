import Foundation
import SwiftData
import Observation

/// Orchestrates quote + FX refreshes. Dispatches each asset to the right
/// provider by `AssetKind`, writes results into the SwiftData store, and
/// publishes a single `Status` value the toolbar dot reads.
///
/// Lifecycle: built once in `FolioApp.init()`, refreshed on-launch via `.task`,
/// on manual `⌘R`, and on a 15-min foreground timer (`startTimer()`). Failures
/// never crash — partial success becomes `.ok`, total failure becomes `.failed`.
///
/// Concurrency: the coordinator is `@MainActor`. We never hand `@Model` refs
/// (`Asset`) into detached tasks — only value-type `AssetSpec`s. Results come
/// back keyed by `PersistentIdentifier`, then we re-look up the model on main
/// to write the `PriceQuote` row.
@MainActor
@Observable
final class QuoteRefreshCoordinator {
    enum Status: Equatable {
        case idle
        case refreshing
        case ok(at: Date)
        case stale(at: Date)
        case failed(at: Date, message: String)
    }

    private(set) var status: Status = .idle

    private let container: ModelContainer
    private let stocks: any QuoteProvider
    private let crypto: any QuoteProvider
    private let fx: any FXProvider
    private var timer: Timer?

    init(
        container: ModelContainer,
        stocks: any QuoteProvider,
        crypto: any QuoteProvider,
        fx: any FXProvider
    ) {
        self.container = container
        self.stocks = stocks
        self.crypto = crypto
        self.fx = fx
    }

    // MARK: - Public API

    func refreshAll() async {
        guard !isRefreshing else { return }
        status = .refreshing

        let context = container.mainContext
        let assets: [Asset]
        let transactions: [PortfolioTransaction]
        let settings: AppSettings?
        do {
            assets = try context.fetch(FetchDescriptor<Asset>())
            transactions = try context.fetch(FetchDescriptor<PortfolioTransaction>())
            settings = try context.fetch(FetchDescriptor<AppSettings>()).first
        } catch {
            status = .failed(at: Date(), message: "Couldn't read store: \(error.localizedDescription)")
            return
        }

        let baseCurrency = settings?.baseCurrency ?? "USD"
        let assetSpecs = assets
            .filter { $0.kind != .cash }
            .map { AssetSpec(id: $0.persistentModelID, symbol: $0.symbol, kind: $0.kind) }
        let fxPairs = collectFXPairs(transactions: transactions, assets: assets, baseCurrency: baseCurrency, context: context)

        async let quoteResults = fetchAssetQuotes(assetSpecs)
        async let fxResults    = fetchFXRates(pairs: fxPairs)
        let (quotes, fxValues) = await (quoteResults, fxResults)

        var successes = 0
        var failures: [String] = []

        // Pre-fetch existing quotes once so we can collapse same-source/same-minute
        // refreshes in place instead of accreting rows. A 15-min timer never
        // collides with itself, but manual ⌘R spam would otherwise grow the
        // PriceQuote table by N rows per click. Different-source rows (e.g. the
        // seed's `"seed"` quotes) are left alone — they have historical value.
        let existingQuotes: [PersistentIdentifier: [PriceQuote]] = {
            do {
                let all = try context.fetch(FetchDescriptor<PriceQuote>())
                return Dictionary(grouping: all, by: { $0.asset.persistentModelID })
            } catch { return [:] }
        }()

        for (assetID, result) in quotes {
            switch result {
            case .success(let q):
                guard let asset = context.model(for: assetID) as? Asset else {
                    failures.append("\(q.symbol): asset gone")
                    continue
                }
                let source = providerSource(for: asset.kind)
                let mostRecent = (existingQuotes[assetID] ?? [])
                    .filter { $0.source == source }
                    .max(by: { $0.asOf < $1.asOf })
                if let mostRecent, abs(mostRecent.asOf.timeIntervalSince(q.asOf)) < 60 {
                    mostRecent.amount = q.price
                    mostRecent.currency = q.currency
                    mostRecent.asOf = q.asOf
                } else {
                    let row = PriceQuote(
                        asset: asset,
                        asOf: q.asOf,
                        amount: q.price,
                        currency: q.currency,
                        source: source
                    )
                    context.insert(row)
                }
                successes += 1
            case .failure(let err):
                failures.append("quote: \(err.localizedDescription)")
            }
        }

        for result in fxValues {
            switch result {
            case .success(let r):
                let row = FXRate(
                    from: r.from,
                    to: r.to,
                    asOf: r.asOf,
                    rate: r.rate,
                    source: "yahoo"
                )
                context.insert(row)
                successes += 1
            case .failure(let err):
                failures.append("fx: \(err.localizedDescription)")
            }
        }

        if successes > 0 {
            let now = Date()
            settings?.lastQuoteRefresh = now
            do {
                try context.save()
            } catch {
                // Likely a unique-key collision on FXRate when the day's row already
                // exists. Keep going — the price-quote inserts are the load-bearing
                // half of the refresh.
                print("⚠️ QuoteRefreshCoordinator save error: \(error.localizedDescription)")
            }
            status = .ok(at: now)
        } else {
            status = .failed(at: Date(), message: failures.first ?? "no quotes refreshed")
        }
    }

    func startTimer(interval: TimeInterval = 900) {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.refreshAll()
            }
        }
    }

    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Status helpers

    var isRefreshing: Bool {
        if case .refreshing = status { return true }
        return false
    }

    /// Returns the most recent successful refresh time, regardless of current state.
    var lastRefresh: Date? {
        switch status {
        case .ok(let at), .stale(let at): return at
        case .failed, .idle, .refreshing: return nil
        }
    }

    // MARK: - Internal types

    private struct AssetSpec: Sendable {
        let id: PersistentIdentifier
        let symbol: String
        let kind: AssetKind
    }

    private struct FXPair: Hashable, Sendable {
        let from: String
        let to: String
    }

    // MARK: - Internal helpers

    private func providerSource(for kind: AssetKind) -> String {
        switch kind {
        case .stock, .etf: return "yahoo"
        case .crypto:      return "coingecko"
        case .cash:        return "n/a"
        }
    }

    /// Splits specs into stock/ETF and crypto, then asks each provider for a
    /// batched fetch. Yahoo's default batch implementation fans out to per-symbol
    /// requests (which it tolerates); CoinGecko's overrides to issue a single
    /// `simple/price?ids=a,b,c` request so we don't burn the free-tier rate limit.
    private func fetchAssetQuotes(_ specs: [AssetSpec]) async -> [(PersistentIdentifier, Result<QuoteResult, Error>)] {
        let stockSpecs = specs.filter { $0.kind != .crypto }
        let cryptoSpecs = specs.filter { $0.kind == .crypto }

        async let stockBatch  = stocks.batchQuotes(symbols: stockSpecs.map { $0.symbol })
        async let cryptoBatch = crypto.batchQuotes(symbols: cryptoSpecs.map { $0.symbol })
        let (stockResults, cryptoResults) = await (stockBatch, cryptoBatch)

        var out: [(PersistentIdentifier, Result<QuoteResult, Error>)] = []
        out.reserveCapacity(specs.count)
        for spec in stockSpecs {
            let r = stockResults[spec.symbol] ?? .failure(QuoteProviderError.unsupportedSymbol(spec.symbol))
            out.append((spec.id, r))
        }
        for spec in cryptoSpecs {
            let r = cryptoResults[spec.symbol] ?? .failure(QuoteProviderError.unsupportedSymbol(spec.symbol))
            out.append((spec.id, r))
        }
        return out
    }

    /// Builds the set of distinct (from, to) FX pairs needed today, skipping
    /// any pair already cached for the UTC day via `FXRate.makeKey`.
    private func collectFXPairs(
        transactions: [PortfolioTransaction],
        assets: [Asset],
        baseCurrency: String,
        context: ModelContext
    ) -> [FXPair] {
        var pairs: Set<FXPair> = []
        for txn in transactions where txn.currency != baseCurrency {
            pairs.insert(FXPair(from: txn.currency, to: baseCurrency))
        }
        for asset in assets where asset.currency != baseCurrency {
            pairs.insert(FXPair(from: asset.currency, to: baseCurrency))
        }

        // `FXRate.makeKey` encodes the UTC day, so we match purely on keys.
        // Mixing a local-TZ "same day" filter with a UTC-keyed lookup used to
        // miss matches near midnight UTC, producing silent duplicate save
        // attempts that the catch block at refreshAll() swallowed.
        let today = Date()
        let alreadyCached: Set<String> = {
            do {
                let existing = try context.fetch(FetchDescriptor<FXRate>())
                return Set(existing.map { $0.key })
            } catch { return [] }
        }()

        return pairs.filter { pair in
            !alreadyCached.contains(FXRate.makeKey(from: pair.from, to: pair.to, asOf: today))
        }
    }

    private func fetchFXRates(pairs: [FXPair]) async -> [Result<FXResult, Error>] {
        guard !pairs.isEmpty else { return [] }
        let provider = fx
        return await withTaskGroup(of: Result<FXResult, Error>.self) { group in
            for pair in pairs {
                let from = pair.from
                let to = pair.to
                group.addTask {
                    do {
                        return .success(try await provider.rate(from: from, to: to))
                    } catch {
                        return .failure(error)
                    }
                }
            }
            var out: [Result<FXResult, Error>] = []
            while let r = await group.next() { out.append(r) }
            return out
        }
    }
}
