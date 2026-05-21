import SwiftUI

/// Compact toggle-style pill used in screen filter bars. Active pill inverts:
/// dark fill, light text. Matches `project/stocks.jsx`'s `FilterPill`.
struct FilterPill: View {
    @Environment(\.theme) private var theme

    let label: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .padding(.horizontal, 11)
                .padding(.vertical, 5)
                .background(background)
                .foregroundStyle(foreground)
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(borderColor, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 5))
                .contentShape(RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
    }

    private var background: Color {
        isActive ? theme.text : theme.cardBg
    }

    private var foreground: Color {
        isActive ? theme.cardBg : theme.text2
    }

    private var borderColor: Color {
        isActive ? theme.text : theme.border
    }
}
