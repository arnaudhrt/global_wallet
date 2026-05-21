import SwiftUI

/// Letter-mark logo for a ticker. Background color comes from a small built-in
/// palette for well-known symbols, otherwise falls back to `theme.text3`.
/// First character of the symbol is rendered in white at semibold weight.
struct TickerLogo: View {
    @Environment(\.theme) private var theme

    let ticker: String
    var size: CGFloat = 28

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(background)
            Text(letter)
                .font(.system(size: size * 0.43, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
    }

    private var letter: String {
        ticker.first.map(String.init)?.uppercased() ?? "·"
    }

    private var background: Color {
        if let hex = Self.palette[ticker.uppercased()] {
            return Color(hex: hex)
        }
        return theme.text3
    }

    /// Ported from `project/stocks.jsx`. Extend as new symbols ship.
    private static let palette: [String: UInt32] = [
        "AAPL":  0x1D1D1F,
        "MSFT":  0x0078D4,
        "NVDA":  0x76B900,
        "GOOGL": 0x4285F4,
        "VTI":   0x9D2235,
        "AMZN":  0xFF9900,
        "COST":  0xE31837,
        "TSLA":  0xCC0000,
        "BRK.B": 0x1B365D,
        "JNJ":   0xCA001B,
    ]
}
