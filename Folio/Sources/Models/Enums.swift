import Foundation

enum AccountKind: String, Codable, CaseIterable, Sendable {
    case brokerage
    case exchange
    case wallet
    case cash

    var displayName: String {
        switch self {
        case .brokerage: return "Brokerage"
        case .exchange:  return "Exchange"
        case .wallet:    return "Wallet"
        case .cash:      return "Cash"
        }
    }
}

enum AssetKind: String, Codable, CaseIterable, Sendable {
    case stock
    case etf
    case crypto
    case cash

    var displayName: String {
        switch self {
        case .stock:  return "Stock"
        case .etf:    return "ETF"
        case .crypto: return "Crypto"
        case .cash:   return "Cash"
        }
    }
}

enum ThemeOverride: String, Codable, CaseIterable, Sendable {
    case system
    case light
    case dark

    var displayName: String {
        switch self {
        case .system: return "System"
        case .light:  return "Light"
        case .dark:   return "Dark"
        }
    }
}

enum TransactionType: String, Codable, CaseIterable, Sendable {
    case buy
    case sell
    case dividend
    case deposit
    case withdraw
    case transfer
    case stake

    var displayName: String {
        switch self {
        case .buy:      return "Buy"
        case .sell:     return "Sell"
        case .dividend: return "Dividend"
        case .deposit:  return "Deposit"
        case .withdraw: return "Withdraw"
        case .transfer: return "Transfer"
        case .stake:    return "Stake"
        }
    }
}
