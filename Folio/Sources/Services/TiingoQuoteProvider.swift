import Foundation

/// Tiingo API token. Hardcoded for now — single-user local app — so this is the
/// one place to change it. Move to `AppSettings` + the Settings sheet later;
/// the provider already reads it through an injectable `token` parameter so that
/// migration is a one-liner.
///
/// NOTE: the default below is the token printed throughout Tiingo's public docs.
/// It may be shared/rate-limited — replace with your own account token if live
/// calls start returning 401/429.
enum TiingoConfig {
    static let token = "7120b311841cb7628bd840e08d191f7ed0271b34"
}

/// Single provider over Tiingo's REST API, covering stocks/ETFs
/// (`/tiingo/daily`), crypto (`/tiingo/crypto`), and FX (`/tiingo/fx`) under one
/// token. Replaces the M4 `YahooQuoteProvider` + `CoinGeckoQuoteProvider` pair.
///
/// Instantiated **twice** — once per `AssetClass` — so the coordinator's stock
/// and crypto DI slots route to the right endpoint family. FX methods are
/// asset-class-agnostic, so the `.equity` instance also serves the `fx:` slot
/// (mirroring how Yahoo used to double as the FX provider).
///
/// Auth is by `&token=` query item (keeps `HTTPClient` untouched). Stock spot
/// quotes are end-of-day (Tiingo `/daily` has no free intraday); fine for a
/// portfolio tracker. Crypto carries far deeper history than CoinGecko's free
/// 365-day ceiling — that's what closes the Overview chart's pre-coverage gap.
struct TiingoQuoteProvider: QuoteProvider, FXProvider {
    enum AssetClass: Sendable { case equity, crypto }

    let assetClass: AssetClass
    let client: HTTPClient
    let token: String

    init(
        assetClass: AssetClass,
        client: HTTPClient = HTTPClient(),
        token: String = TiingoConfig.token
    ) {
        self.assetClass = assetClass
        self.client = client
        self.token = token
    }

    // MARK: - Symbol mapping

    /// Tiingo uses `brk-b` where we store `BRK.B` (same `.`→`-` rule as Yahoo).
    /// Tickers are case-insensitive on Tiingo; we lowercase for tidy URLs.
    static func equityTicker(for symbol: String) -> String {
        symbol.replacingOccurrences(of: ".", with: "-").lowercased()
    }

    /// Crypto pairs are `<base><quote>` lowercase, e.g. `btcusd`. An override map
    /// handles rebrands/edge symbols.
    static let cryptoOverrides: [String: String] = [
        // MATIC→POL rebrand (Sep 2024). Tiingo has historically carried the pair
        // under `maticusd`; flip this to `polusd` if that ticker stops resolving.
        "MATIC": "maticusd",
    ]
    static func cryptoTicker(for symbol: String) -> String {
        if let mapped = cryptoOverrides[symbol.uppercased()] { return mapped }
        return "\(symbol.lowercased())usd"
    }

    /// FX pair ticker, `<from><to>` lowercase, e.g. EUR,USD → `eurusd`.
    static func fxTicker(from: String, to: String) -> String {
        "\(from.lowercased())\(to.lowercased())"
    }

    // MARK: - URL builders (static + pure so they're testable without a network)

    /// IEX real-time/last endpoint — the one equity endpoint that takes
    /// comma-separated `tickers`, so spot for the whole stock sleeve is a single
    /// request instead of one-per-ticker. (`/daily` has no multi-ticker form.)
    static func iexURL(tickers: [String], token: String) -> URL? {
        guard !tickers.isEmpty else { return nil }
        var c = URLComponents(string: "https://api.tiingo.com/iex/")!
        c.queryItems = [
            URLQueryItem(name: "token", value: token),
            URLQueryItem(name: "tickers", value: tickers.joined(separator: ",")),
        ]
        return c.url
    }

    static func equityPricesURL(symbol: String, startDate: Date? = nil, token: String) -> URL? {
        var c = URLComponents(string: "https://api.tiingo.com/tiingo/daily/\(equityTicker(for: symbol))/prices")!
        var items = [
            URLQueryItem(name: "token", value: token),
            URLQueryItem(name: "format", value: "json"),
        ]
        if let startDate {
            items.append(URLQueryItem(name: "startDate", value: ymd(startDate)))
            items.append(URLQueryItem(name: "resampleFreq", value: "daily"))
        }
        c.queryItems = items
        return c.url
    }

    static func cryptoPricesURL(tickers: [String], startDate: Date? = nil, token: String) -> URL? {
        guard !tickers.isEmpty else { return nil }
        var c = URLComponents(string: "https://api.tiingo.com/tiingo/crypto/prices")!
        var items = [
            URLQueryItem(name: "token", value: token),
            URLQueryItem(name: "tickers", value: tickers.joined(separator: ",")),
        ]
        if let startDate {
            items.append(URLQueryItem(name: "startDate", value: ymd(startDate)))
            items.append(URLQueryItem(name: "resampleFreq", value: "1day"))
        }
        c.queryItems = items
        return c.url
    }

    static func fxPricesURL(ticker: String, startDate: Date?, token: String) -> URL? {
        var c = URLComponents(string: "https://api.tiingo.com/tiingo/fx/\(ticker)/prices")!
        var items = [
            URLQueryItem(name: "token", value: token),
            URLQueryItem(name: "resampleFreq", value: "1day"),
        ]
        if let startDate {
            items.append(URLQueryItem(name: "startDate", value: ymd(startDate)))
        }
        c.queryItems = items
        return c.url
    }

    static func fxTopURL(ticker: String, token: String) -> URL? {
        var c = URLComponents(string: "https://api.tiingo.com/tiingo/fx/top")!
        c.queryItems = [
            URLQueryItem(name: "token", value: token),
            URLQueryItem(name: "tickers", value: ticker),
        ]
        return c.url
    }

    // MARK: - Date helpers

    /// UTC `yyyy-MM-dd`, the format every Tiingo `startDate`/`endDate` expects.
    static func ymd(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: date)
    }

    /// Parses Tiingo's ISO timestamps. EOD/FX use `…Z` with fractional seconds;
    /// crypto uses `…+00:00`. `ISO8601DateFormatter` handles both, but fractional
    /// seconds need their own pass.
    static func parseDate(_ s: String) -> Date? {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: s) { return d }
        iso.formatOptions = [.withInternetDateTime]
        return iso.date(from: s)
    }

    /// Start of the requested range, UTC midnight `days` before `now`.
    static func startDate(for range: QuoteRange, now: Date = Date()) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC") ?? .current
        return cal.date(byAdding: .day, value: -range.days(now: now), to: cal.startOfDay(for: now)) ?? now
    }

    // MARK: - QuoteProvider

    func quote(symbol: String) async throws -> QuoteResult {
        let results = await batchQuotes(symbols: [symbol])
        switch results[symbol] {
        case .success(let q): return q
        case .failure(let err): throw err
        case .none: throw QuoteProviderError.unsupportedSymbol(symbol)
        }
    }

    /// Both classes issue a single batched call: equity via `/iex?tickers=…`,
    /// crypto via `/crypto/prices?tickers=…`. So a spot refresh is two requests
    /// total regardless of how many positions you hold.
    func batchQuotes(symbols: [String]) async -> [String: Result<QuoteResult, Error>] {
        switch assetClass {
        case .crypto: return await batchCrypto(symbols)
        case .equity: return await batchEquity(symbols)
        }
    }

    func historical(symbol: String, range: QuoteRange) async throws -> [HistoricalPoint] {
        let start = Self.startDate(for: range)
        switch assetClass {
        case .equity:
            guard let url = Self.equityPricesURL(symbol: symbol, startDate: start, token: token) else {
                throw QuoteProviderError.unsupportedSymbol(symbol)
            }
            let bars = try await client.getJSON(url, as: [EODBar].self)
            return bars.compactMap { bar in
                guard let d = Self.parseDate(bar.date) else { return nil }
                return HistoricalPoint(date: d, close: decimalFromJSONNumber(bar.close))
            }
        case .crypto:
            guard let url = Self.cryptoPricesURL(tickers: [Self.cryptoTicker(for: symbol)], startDate: start, token: token) else {
                throw QuoteProviderError.unsupportedSymbol(symbol)
            }
            let envelopes = try await client.getJSON(url, as: [CryptoEnvelope].self)
            guard let env = envelopes.first else { return [] }
            return env.priceData.compactMap { bar in
                guard let d = Self.parseDate(bar.date) else { return nil }
                return HistoricalPoint(date: d, close: decimalFromJSONNumber(bar.close))
            }
        }
    }

    /// Crypto collapses the whole sleeve into one `/crypto/prices?tickers=…`
    /// call; equity fans out (one `/daily` call per ticker — no multi-ticker
    /// history endpoint). All assets in the crypto batch share the range's
    /// `startDate`; SwiftData's unique key drops any overlap on insert.
    func historicalBatch(symbols: [String], range: QuoteRange) async -> [String: Result<[HistoricalPoint], Error>] {
        switch assetClass {
        case .crypto:
            return await batchCryptoHistorical(symbols, range: range)
        case .equity:
            return await withTaskGroup(of: (String, Result<[HistoricalPoint], Error>).self) { group in
                for symbol in symbols {
                    group.addTask {
                        do { return (symbol, .success(try await self.historical(symbol: symbol, range: range))) }
                        catch { return (symbol, .failure(error)) }
                    }
                }
                var out: [String: Result<[HistoricalPoint], Error>] = [:]
                while let (s, r) = await group.next() { out[s] = r }
                return out
            }
        }
    }

    func search(query: String) async throws -> [SymbolMatch] {
        throw QuoteProviderError.notImplemented
    }

    // MARK: - FXProvider

    func rate(from: String, to: String) async throws -> FXResult {
        if from == to { return FXResult(from: from, to: to, rate: 1, asOf: Date()) }
        // Try the direct pair; fall back to the inverse ticker and reciprocate.
        if let direct = try? await fxTop(ticker: Self.fxTicker(from: from, to: to)) {
            return FXResult(from: from, to: to, rate: direct.rate, asOf: direct.asOf)
        }
        let inv = try await fxTop(ticker: Self.fxTicker(from: to, to: from))
        guard inv.rate != 0 else { throw FXProviderError.unsupportedPair(from, to) }
        return FXResult(from: from, to: to, rate: 1 / inv.rate, asOf: inv.asOf)
    }

    func historical(from: String, to: String, range: QuoteRange) async throws -> [HistoricalFXPoint] {
        if from == to { return [] }
        let start = Self.startDate(for: range)
        if let direct = try? await fxHistorical(ticker: Self.fxTicker(from: from, to: to), startDate: start), !direct.isEmpty {
            return direct
        }
        let inv = try await fxHistorical(ticker: Self.fxTicker(from: to, to: from), startDate: start)
        return inv.map { HistoricalFXPoint(date: $0.date, rate: $0.rate == 0 ? 0 : 1 / $0.rate) }
    }

    // MARK: - Internal fetch helpers

    /// One `/iex?tickers=a,b,c` call for the whole equity sleeve. Results are
    /// keyed by the *original* symbol string so the coordinator's
    /// `stockResults[spec.symbol]` lookup matches. Price falls back
    /// `last → tngoLast → prevClose` (any can be null outside market hours).
    private func batchEquity(_ symbols: [String]) async -> [String: Result<QuoteResult, Error>] {
        var tickerToSymbol: [String: String] = [:]
        for s in symbols { tickerToSymbol[Self.equityTicker(for: s)] = s }

        var out: [String: Result<QuoteResult, Error>] = [:]
        guard let url = Self.iexURL(tickers: Array(tickerToSymbol.keys), token: token) else {
            for (_, s) in tickerToSymbol { out[s] = .failure(QuoteProviderError.unsupportedSymbol(s)) }
            return out
        }

        do {
            let rows = try await client.getJSON(url, as: [IEXRow].self)
            var seen: Set<String> = []
            for row in rows {
                guard let sym = tickerToSymbol[row.ticker.lowercased()] else { continue }
                seen.insert(sym)
                if let price = row.last ?? row.tngoLast ?? row.prevClose {
                    out[sym] = .success(QuoteResult(
                        symbol: sym,
                        price: decimalFromJSONNumber(price),
                        currency: "USD",
                        asOf: row.timestamp.flatMap { Self.parseDate($0) } ?? Date()
                    ))
                } else {
                    out[sym] = .failure(QuoteProviderError.decoding("no IEX price for \(sym)"))
                }
            }
            for (_, s) in tickerToSymbol where !seen.contains(s) {
                out[s] = .failure(QuoteProviderError.unsupportedSymbol(s))
            }
        } catch {
            for (_, s) in tickerToSymbol { out[s] = .failure(error) }
        }
        return out
    }

    /// One `/crypto/prices?tickers=a,b,c` call for the whole list. Results are
    /// keyed by the *original* symbol string (as passed in) so the coordinator's
    /// `cryptoResults[spec.symbol]` lookup matches.
    private func batchCrypto(_ symbols: [String]) async -> [String: Result<QuoteResult, Error>] {
        var tickerToSymbol: [String: String] = [:]
        for s in symbols { tickerToSymbol[Self.cryptoTicker(for: s)] = s }

        var out: [String: Result<QuoteResult, Error>] = [:]
        guard let url = Self.cryptoPricesURL(tickers: Array(tickerToSymbol.keys), token: token) else {
            for (_, s) in tickerToSymbol { out[s] = .failure(QuoteProviderError.unsupportedSymbol(s)) }
            return out
        }

        do {
            let envelopes = try await client.getJSON(url, as: [CryptoEnvelope].self)
            var seen: Set<String> = []
            for env in envelopes {
                guard let sym = tickerToSymbol[env.ticker.lowercased()] else { continue }
                seen.insert(sym)
                if let latest = env.priceData.last {
                    out[sym] = .success(QuoteResult(
                        symbol: sym,
                        price: decimalFromJSONNumber(latest.close),
                        currency: env.quoteCurrency.uppercased(),
                        asOf: Self.parseDate(latest.date) ?? Date()
                    ))
                } else {
                    out[sym] = .failure(QuoteProviderError.decoding("no priceData for \(sym)"))
                }
            }
            for (_, s) in tickerToSymbol where !seen.contains(s) {
                out[s] = .failure(QuoteProviderError.unsupportedSymbol(s))
            }
        } catch {
            for (_, s) in tickerToSymbol { out[s] = .failure(error) }
        }
        return out
    }

    /// One multi-ticker `/crypto/prices` call covering the range. Keyed by the
    /// original symbol string so the service's per-spec lookup matches.
    private func batchCryptoHistorical(_ symbols: [String], range: QuoteRange) async -> [String: Result<[HistoricalPoint], Error>] {
        var tickerToSymbol: [String: String] = [:]
        for s in symbols { tickerToSymbol[Self.cryptoTicker(for: s)] = s }

        var out: [String: Result<[HistoricalPoint], Error>] = [:]
        let start = Self.startDate(for: range)
        guard let url = Self.cryptoPricesURL(tickers: Array(tickerToSymbol.keys), startDate: start, token: token) else {
            for (_, s) in tickerToSymbol { out[s] = .failure(QuoteProviderError.unsupportedSymbol(s)) }
            return out
        }

        do {
            let envelopes = try await client.getJSON(url, as: [CryptoEnvelope].self)
            var seen: Set<String> = []
            for env in envelopes {
                guard let sym = tickerToSymbol[env.ticker.lowercased()] else { continue }
                seen.insert(sym)
                let points = env.priceData.compactMap { bar -> HistoricalPoint? in
                    guard let d = Self.parseDate(bar.date) else { return nil }
                    return HistoricalPoint(date: d, close: decimalFromJSONNumber(bar.close))
                }
                out[sym] = .success(points)
            }
            for (_, s) in tickerToSymbol where !seen.contains(s) {
                out[s] = .failure(QuoteProviderError.unsupportedSymbol(s))
            }
        } catch {
            for (_, s) in tickerToSymbol { out[s] = .failure(error) }
        }
        return out
    }

    private func fxTop(ticker: String) async throws -> (rate: Decimal, asOf: Date) {
        guard let url = Self.fxTopURL(ticker: ticker, token: token) else {
            throw FXProviderError.unsupportedPair(ticker, "")
        }
        let rows = try await client.getJSON(url, as: [FXTopRow].self)
        guard let row = rows.first(where: { $0.ticker.lowercased() == ticker.lowercased() }) ?? rows.first else {
            throw FXProviderError.unsupportedPair(ticker, "")
        }
        guard let mid = row.midPrice ?? row.impliedMid else {
            throw FXProviderError.unsupportedPair(ticker, "")
        }
        let asOf = row.quoteTimestamp.flatMap { Self.parseDate($0) } ?? Date()
        return (decimalFromJSONNumber(mid), asOf)
    }

    private func fxHistorical(ticker: String, startDate: Date) async throws -> [HistoricalFXPoint] {
        guard let url = Self.fxPricesURL(ticker: ticker, startDate: startDate, token: token) else {
            throw FXProviderError.unsupportedPair(ticker, "")
        }
        let bars = try await client.getJSON(url, as: [FXBar].self)
        return bars.compactMap { bar in
            guard let d = Self.parseDate(bar.date) else { return nil }
            return HistoricalFXPoint(date: d, rate: decimalFromJSONNumber(bar.close))
        }
    }

    // MARK: - Wire shapes

    private struct IEXRow: Decodable {
        let ticker: String
        let last: Double?
        let tngoLast: Double?
        let prevClose: Double?
        let timestamp: String?
    }

    private struct EODBar: Decodable {
        let date: String
        let close: Double
    }

    private struct CryptoEnvelope: Decodable {
        let ticker: String
        let quoteCurrency: String
        let priceData: [CryptoBar]
    }
    private struct CryptoBar: Decodable {
        let date: String
        let close: Double
    }

    private struct FXBar: Decodable {
        let date: String
        let close: Double
    }

    private struct FXTopRow: Decodable {
        let ticker: String
        let quoteTimestamp: String?
        let midPrice: Double?
        let bidPrice: Double?
        let askPrice: Double?

        /// Tiingo populates `midPrice` only when both bid and ask are non-null;
        /// derive it ourselves otherwise.
        var impliedMid: Double? {
            guard let bid = bidPrice, let ask = askPrice else { return nil }
            return (bid + ask) / 2.0
        }
    }
}
