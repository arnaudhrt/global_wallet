import Foundation

/// Unofficial Yahoo Finance v8 chart endpoint. No API key, best-effort —
/// failures bubble up to `QuoteRefreshCoordinator` which surfaces them as a
/// red dot in the toolbar. Used for stocks, ETFs, and FX (the same endpoint
/// returns FX pairs via the `EURUSD=X` symbol form).
struct YahooQuoteProvider: QuoteProvider, FXProvider {
    let client: HTTPClient

    init(client: HTTPClient = HTTPClient()) {
        self.client = client
    }

    // MARK: - QuoteProvider

    func quote(symbol: String) async throws -> QuoteResult {
        let meta = try await fetchMeta(symbol: symbol)
        guard let price = meta.regularMarketPrice else {
            throw QuoteProviderError.decoding("missing regularMarketPrice for \(symbol)")
        }
        return QuoteResult(
            symbol: symbol,
            price: decimalFromJSONNumber(price),
            currency: meta.currency ?? "USD",
            asOf: meta.regularMarketTime.map { Date(timeIntervalSince1970: TimeInterval($0)) } ?? Date()
        )
    }

    func historical(symbol: String, range: QuoteRange) async throws -> [HistoricalPoint] {
        throw QuoteProviderError.notImplemented
    }

    func search(query: String) async throws -> [SymbolMatch] {
        throw QuoteProviderError.notImplemented
    }

    // MARK: - FXProvider

    func rate(from: String, to: String) async throws -> FXResult {
        if from == to {
            return FXResult(from: from, to: to, rate: 1, asOf: Date())
        }
        let symbol = "\(from)\(to)=X"
        let meta = try await fetchMeta(symbol: symbol)
        guard let price = meta.regularMarketPrice else {
            throw FXProviderError.unsupportedPair(from, to)
        }
        return FXResult(
            from: from,
            to: to,
            rate: decimalFromJSONNumber(price),
            asOf: meta.regularMarketTime.map { Date(timeIntervalSince1970: TimeInterval($0)) } ?? Date()
        )
    }

    // MARK: - Internal

    /// Yahoo uses `BRK-B` for what we (and most data sources) call `BRK.B`.
    /// Lifted out as a static helper so URL construction is testable without
    /// hitting the network.
    static func yahooSymbol(for symbol: String) -> String {
        symbol.replacingOccurrences(of: ".", with: "-")
    }

    static func chartURL(symbol: String) -> URL? {
        var components = URLComponents(string: "https://query1.finance.yahoo.com/v8/finance/chart/\(yahooSymbol(for: symbol))")!
        components.queryItems = [
            URLQueryItem(name: "interval", value: "1d"),
            URLQueryItem(name: "range", value: "1d"),
        ]
        return components.url
    }

    private func fetchMeta(symbol: String) async throws -> ChartMeta {
        guard let url = Self.chartURL(symbol: symbol) else {
            throw QuoteProviderError.unsupportedSymbol(symbol)
        }
        let envelope = try await client.getJSON(url, as: ChartEnvelope.self)
        guard let meta = envelope.chart.result?.first?.meta else {
            if let err = envelope.chart.error {
                throw QuoteProviderError.network(err.description ?? err.code ?? "yahoo error")
            }
            throw QuoteProviderError.unsupportedSymbol(symbol)
        }
        return meta
    }

    // MARK: - Wire shape

    private struct ChartEnvelope: Decodable {
        let chart: Chart
    }
    private struct Chart: Decodable {
        let result: [ChartResult]?
        let error: ChartError?
    }
    private struct ChartResult: Decodable {
        let meta: ChartMeta
    }
    private struct ChartMeta: Decodable {
        let regularMarketPrice: Double?
        let currency: String?
        let regularMarketTime: Int?
    }
    private struct ChartError: Decodable {
        let code: String?
        let description: String?
    }
}
