import Foundation

/// Thin URLSession wrapper used by network providers. 8-second timeout,
/// User-Agent header set for unofficial endpoints, JSON decoder that tolerates
/// the various date formats Yahoo + CoinGecko return (we parse dates manually
/// from Unix timestamps in the response bodies, so the decoder itself stays
/// default).
struct HTTPClient: Sendable {
    let session: URLSession
    let userAgent: String

    init(session: URLSession = .shared, userAgent: String = "Folio/0.1") {
        self.session = session
        self.userAgent = userAgent
    }

    func getJSON<T: Decodable>(_ url: URL, as type: T.Type) async throws -> T {
        var request = URLRequest(url: url, timeoutInterval: 8)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw QuoteProviderError.network(error.localizedDescription)
        }

        if let http = response as? HTTPURLResponse {
            switch http.statusCode {
            case 200..<300: break
            case 429:       throw QuoteProviderError.rateLimited
            default:        throw QuoteProviderError.network("HTTP \(http.statusCode)")
            }
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw QuoteProviderError.decoding(error.localizedDescription)
        }
    }
}

/// `Decimal(JSON_double)` introduces binary-float artifacts on values like
/// `0.582`. Round-tripping through `String(describing:)` keeps the literal
/// decimal representation that came over the wire.
func decimalFromJSONNumber(_ d: Double) -> Decimal {
    Decimal(string: String(d)) ?? Decimal(d)
}
