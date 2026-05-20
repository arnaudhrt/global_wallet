import SwiftUI

/// Generic empty-state body rendered in the detail slot for each MVP destination
/// until M5–M8 fill them in with real content.
struct PlaceholderScreen: View {
    @Environment(\.theme) private var theme
    let destination: Destination

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: destination.iconName)
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(theme.text3)
            Text(destination.title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(theme.text)
            Text(comingNote)
                .font(.system(size: 12))
                .foregroundStyle(theme.text2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.bg)
    }

    private var comingNote: String {
        switch destination {
        case .overview:     return "Coming in M8"
        case .stocks:       return "Coming in M5"
        case .crypto:       return "Coming in M6"
        case .transactions: return "Coming in M7"
        default:            return "Coming in v2"
        }
    }
}
