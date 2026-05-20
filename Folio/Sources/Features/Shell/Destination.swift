import Foundation

/// The eight sidebar destinations. MVP rows (`isAvailable == true`) drive the detail view;
/// v2 rows are rendered dimmed and non-tappable in M2 — they become real screens in v2.
enum Destination: String, Identifiable, Hashable, CaseIterable {
    case overview
    case stocks
    case crypto
    case transactions
    case dividends
    case fees
    case accounts
    case importCSV

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview:     return "Overview"
        case .stocks:       return "Stocks & ETFs"
        case .crypto:       return "Crypto"
        case .transactions: return "Transactions"
        case .dividends:    return "Dividends"
        case .fees:         return "Fees"
        case .accounts:     return "Accounts"
        case .importCSV:    return "Import CSV"
        }
    }

    var subtitle: String {
        switch self {
        case .overview:     return "Portfolio summary"
        case .stocks:       return "Equity & ETF holdings"
        case .crypto:       return "Wallet & exchange balances"
        case .transactions: return "Buys, sells, transfers"
        case .dividends:    return "Coming in v2"
        case .fees:         return "Coming in v2"
        case .accounts:     return "Coming in v2"
        case .importCSV:    return "Coming in v2"
        }
    }

    /// SF Symbol name used in the sidebar row.
    var iconName: String {
        switch self {
        case .overview:     return "square.grid.2x2"
        case .stocks:       return "chart.line.uptrend.xyaxis"
        case .crypto:       return "bitcoinsign.circle"
        case .transactions: return "arrow.left.arrow.right"
        case .dividends:    return "dollarsign.circle"
        case .fees:         return "doc.text"
        case .accounts:     return "creditcard"
        case .importCSV:    return "square.and.arrow.down"
        }
    }

    /// True for the 4 MVP destinations, false for v2 stubs.
    var isAvailable: Bool {
        switch self {
        case .overview, .stocks, .crypto, .transactions: return true
        default: return false
        }
    }
}

/// Sidebar groups in the order they appear, matching `project/shell.jsx`.
enum SidebarGroup: CaseIterable {
    case mvp
    case incomeCosts
    case settings

    var header: String? {
        switch self {
        case .mvp:         return nil
        case .incomeCosts: return "Income & Costs"
        case .settings:    return "Settings"
        }
    }

    var destinations: [Destination] {
        switch self {
        case .mvp:         return [.overview, .stocks, .crypto, .transactions]
        case .incomeCosts: return [.dividends, .fees]
        case .settings:    return [.accounts, .importCSV]
        }
    }
}
