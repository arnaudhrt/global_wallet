import SwiftUI

/// Foreground + background palette for a `TransactionType` badge, resolved
/// against the current theme. Extracted from the row view so M9's Add
/// Transaction flow can reuse the same colors when previewing the type.
enum TypeBadgeStyle {
    struct Style {
        let foreground: Color
        let background: Color
    }

    static func style(for type: TransactionType, theme: FolioTheme) -> Style {
        switch type {
        case .buy:
            return Style(foreground: theme.green, background: theme.greenBg)
        case .sell:
            return Style(foreground: theme.red, background: theme.redBg)
        case .dividend:
            return Style(foreground: theme.sp, background: theme.sp.opacity(0.12))
        case .deposit:
            return Style(foreground: theme.text2, background: theme.surface)
        case .withdraw:
            return Style(foreground: theme.red, background: theme.redBg)
        case .transfer:
            return Style(foreground: theme.text2, background: theme.surface)
        case .stake:
            return Style(foreground: theme.amber, background: theme.amberBg)
        }
    }
}
