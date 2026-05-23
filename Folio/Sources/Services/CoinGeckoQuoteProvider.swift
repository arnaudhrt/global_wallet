import Foundation

/// CoinGecko free `simple/price` endpoint. No API key. Crypto-only — the
/// symbol→coin-id map is hardcoded for the M3 seed assets; M9's
/// `QuoteProvider.search()` will populate new mappings interactively.
struct CoinGeckoQuoteProvider: QuoteProvider {
    let client: HTTPClient
    let symbolToId: [String: String]

    static let seedSymbolMap: [String: String] = [
        "BTC":   "bitcoin",
        "ETH":   "ethereum",
        "SOL":   "solana",
        "LINK":  "chainlink",
        // MATIC was rebranded to POL in Sep 2024; CoinGecko's old `matic-network`
        // id returns an empty object. M9's search() flow will let users remap
        // legacy tickers — for now we point this seed entry at the new id and
        // keep the ticker "MATIC" in the prototype-derived seed data.
        "MATIC": "polygon-ecosystem-token",
        "USDC":  "usd-coin",
    ]

    init(client: HTTPClient = HTTPClient(), symbolToId: [String: String] = Self.seedSymbolMap) {
        self.client = client
        self.symbolToId = symbolToId
    }

    /// Resolves a user-facing ticker to the CoinGecko coin id. Returns nil for
    /// unknown symbols. Pulled out so tests can verify the post-rebrand MATIC
    /// mapping without hitting the network.
    func coinId(for symbol: String) -> String? {
        symbolToId[symbol.uppercased()]
    }

    /// Constructs the `simple/price` URL for a batched fetch. Returns nil if
    /// `ids` is empty.
    static func priceURL(ids: [String]) -> URL? {
        guard !ids.isEmpty else { return nil }
        var components = URLComponents(string: "https://api.coingecko.com/api/v3/simple/price")!
        components.queryItems = [
            URLQueryItem(name: "ids", value: ids.joined(separator: ",")),
            URLQueryItem(name: "vs_currencies", value: "usd"),
            URLQueryItem(name: "include_last_updated_at", value: "true"),
        ]
        return components.url
    }

    func quote(symbol: String) async throws -> QuoteResult {
        let results = await batchQuotes(symbols: [symbol])
        switch results[symbol] {
        case .success(let q): return q
        case .failure(let err): throw err
        case .none: throw QuoteProviderError.unsupportedSymbol(symbol)
        }
    }

    /// Batched override: one HTTP request for the whole list. CoinGecko's free
    /// tier is ~30 req/min — fanning out per symbol burns the budget instantly.
    func batchQuotes(symbols: [String]) async -> [String: Result<QuoteResult, Error>] {
        var idToSymbol: [String: String] = [:]
        var unsupported: [String] = []
        for s in symbols {
            if let id = symbolToId[s.uppercased()] {
                idToSymbol[id] = s.uppercased()
            } else {
                unsupported.append(s)
            }
        }
        var results: [String: Result<QuoteResult, Error>] = [:]
        for s in unsupported {
            results[s] = .failure(QuoteProviderError.unsupportedSymbol(s))
        }
        guard !idToSymbol.isEmpty else { return results }

        guard let url = Self.priceURL(ids: Array(idToSymbol.keys)) else {
            for (_, sym) in idToSymbol {
                results[sym] = .failure(QuoteProviderError.unsupportedSymbol(sym))
            }
            return results
        }

        do {
            let body = try await client.getJSON(url, as: [String: CoinEntry].self)
            for (id, sym) in idToSymbol {
                if let entry = body[id], let price = entry.usd {
                    results[sym] = .success(QuoteResult(
                        symbol: sym,
                        price: decimalFromJSONNumber(price),
                        currency: "USD",
                        asOf: entry.last_updated_at.map { Date(timeIntervalSince1970: TimeInterval($0)) } ?? Date()
                    ))
                } else {
                    results[sym] = .failure(QuoteProviderError.decoding("missing price for \(sym) (\(id))"))
                }
            }
        } catch {
            for (_, sym) in idToSymbol {
                results[sym] = .failure(error)
            }
        }
        return results
    }

    func historical(symbol: String, range: QuoteRange) async throws -> [HistoricalPoint] {
        guard let id = coinId(for: symbol) else {
            throw QuoteProviderError.unsupportedSymbol(symbol)
        }
        guard let url = Self.marketChartURL(coinID: id, days: range.days()) else {
            throw QuoteProviderError.unsupportedSymbol(symbol)
        }
        let body = try await client.getJSON(url, as: MarketChart.self)
        // `prices` is a list of `[epoch_ms, price]` tuples. Granularity is
        // auto-selected by CoinGecko: hourly when days <= 90, daily otherwise.
        // We coarsen sub-daily points to UTC midnight here so the reducer's
        // forward-fill works consistently across ranges.
        var seenDays: Set<String> = []
        var points: [HistoricalPoint] = []
        let day = DateFormatter()
        day.dateFormat = "yyyy-MM-dd"
        day.timeZone = TimeZone(identifier: "UTC")
        for entry in body.prices {
            guard entry.count == 2 else { continue }
            let date = Date(timeIntervalSince1970: TimeInterval(entry[0] / 1000))
            let key = day.string(from: date)
            if seenDays.contains(key) { continue }
            seenDays.insert(key)
            points.append(HistoricalPoint(
                date: date,
                close: decimalFromJSONNumber(entry[1])
            ))
        }
        return points
    }

    /// Constructs the `market_chart` URL. `days` should match
    /// `QuoteRange.days()`; `interval=daily` keeps the response small for
    /// long ranges (free tier doesn't honor it on short ranges and returns
    /// hourly — we coarsen client-side).
    static func marketChartURL(coinID: String, days: Int) -> URL? {
        guard !coinID.isEmpty, days > 0 else { return nil }
        var components = URLComponents(string: "https://api.coingecko.com/api/v3/coins/\(coinID)/market_chart")!
        components.queryItems = [
            URLQueryItem(name: "vs_currency", value: "usd"),
            URLQueryItem(name: "days", value: String(days)),
            URLQueryItem(name: "interval", value: "daily"),
        ]
        return components.url
    }

    func search(query: String) async throws -> [SymbolMatch] {
        throw QuoteProviderError.notImplemented
    }

    private struct CoinEntry: Decodable {
        let usd: Double?
        let last_updated_at: Int?
    }

    private struct MarketChart: Decodable {
        let prices: [[Double]]
    }
}
