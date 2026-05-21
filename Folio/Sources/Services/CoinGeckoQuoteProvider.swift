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
        throw QuoteProviderError.notImplemented
    }

    func search(query: String) async throws -> [SymbolMatch] {
        throw QuoteProviderError.notImplemented
    }

    private struct CoinEntry: Decodable {
        let usd: Double?
        let last_updated_at: Int?
    }
}
