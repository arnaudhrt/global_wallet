import SwiftUI

/// Circular letter-mark logo for crypto assets. Sibling to `TickerLogo`
/// (rounded-square, used for stocks). Background color comes from a small
/// built-in palette for well-known symbols; falls back to `theme.text3`.
/// USDC renders a `$` glyph instead of the first letter, matching the JSX.
struct CryptoLogo: View {
    @Environment(\.theme) private var theme

    let symbol: String
    var size: CGFloat = 28

    var body: some View {
        ZStack {
            Circle().fill(background)
            Text(glyph)
                .font(.system(size: size * 0.39, weight: .bold))
                .foregroundStyle(.white)
                .tracking(-0.3)
        }
        .frame(width: size, height: size)
    }

    private var glyph: String {
        let upper = symbol.uppercased()
        if upper == "USDC" { return "$" }
        return upper.first.map(String.init) ?? "·"
    }

    private var background: Color {
        if let hex = Self.palette[symbol.uppercased()] {
            return Color(hex: hex)
        }
        return theme.text3
    }

    private static let palette: [String: UInt32] = [
        "BTC":   0xF7931A,
        "ETH":   0x627EEA,
        "SOL":   0x9945FF,
        "LINK":  0x2A5ADA,
        "MATIC": 0x8247E5,
        "USDC":  0x2775CA,
    ]
}
