import SwiftUI

/// Generic "no data yet" placeholder for any list/screen. Centered SF Symbol
/// icon over a headline + sub line, with an optional prominent CTA button.
///
/// Sized to slot inside a screen's main `ScrollView` content — the caller
/// supplies an outer `.frame(maxWidth:maxHeight:)` if it wants the empty state
/// to fill the viewport (Overview does this; the Stocks / Crypto / Transactions
/// tables drop it in where the table would be).
struct EmptyState: View {
    @Environment(\.theme) private var theme

    let icon: String
    let headline: String
    let sub: String?
    let ctaLabel: String?
    let onCTA: (() -> Void)?

    init(
        icon: String,
        headline: String,
        sub: String? = nil,
        ctaLabel: String? = nil,
        onCTA: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.headline = headline
        self.sub = sub
        self.ctaLabel = ctaLabel
        self.onCTA = onCTA
    }

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(theme.text3)

            VStack(spacing: 4) {
                Text(headline)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(theme.text)
                if let sub {
                    Text(sub)
                        .font(.system(size: 12))
                        .foregroundStyle(theme.text3)
                        .multilineTextAlignment(.center)
                }
            }

            if let ctaLabel, let onCTA {
                Button {
                    onCTA()
                } label: {
                    Text(ctaLabel)
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 4)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.vertical, 48)
    }
}
