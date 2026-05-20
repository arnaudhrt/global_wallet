import Foundation
import SwiftData

/// Port of the prototype's `project/data.jsx` into Swift literals. Loaded on
/// first launch into the SwiftData store so M5–M8 screens have realistic
/// fixtures before live quotes arrive in M4.
///
/// Strategy: insert one synthetic Buy per (stock row, asset) and one per
/// (crypto wallet sub-row) backdated to `syntheticBuyDate`. Then layer the 12
/// actual transactions from the mock dataset on top. HoldingsReducer output
/// may diverge slightly from the mock's displayed numbers — acceptable for
/// dev fixtures.
enum SeedDataLoader {
    /// Inserts the full seed dataset if `context` is empty (no `Account`
    /// rows). No-op otherwise.
    static func seedIfEmpty(_ context: ModelContext) throws {
        let existing = try context.fetchCount(FetchDescriptor<Account>())
        guard existing == 0 else { return }

        // 1. Accounts
        var accountsByName: [String: Account] = [:]
        for spec in seedAccounts {
            let a = Account(
                name: spec.name,
                kind: spec.kind,
                mask: spec.mask,
                currency: spec.currency,
                colorHex: spec.colorHex
            )
            context.insert(a)
            accountsByName[spec.name] = a
        }

        // 2. Assets
        var assetsBySymbol: [String: Asset] = [:]
        let allAssetSpecs = seedStocks.map { stockToAsset($0) } + seedCryptos.map { cryptoToAsset($0) }
        for spec in allAssetSpecs {
            let asset = Asset(
                symbol: spec.symbol,
                name: spec.name,
                kind: spec.kind,
                currency: spec.currency,
                colorHex: spec.colorHex
            )
            context.insert(asset)
            assetsBySymbol[spec.symbol] = asset
        }

        // 3. Price quotes (current snapshot — source = "seed")
        let now = Date()
        for spec in seedStocks {
            guard let asset = assetsBySymbol[spec.symbol] else { continue }
            let q = PriceQuote(asset: asset, asOf: now, amount: spec.price, currency: "USD", source: "seed")
            context.insert(q)
        }
        for spec in seedCryptos {
            guard let asset = assetsBySymbol[spec.symbol] else { continue }
            let q = PriceQuote(asset: asset, asOf: now, amount: spec.price, currency: "USD", source: "seed")
            context.insert(q)
        }

        // 4. Synthetic Buys (backdated) — one per stock row, one per crypto wallet
        for spec in seedStocks {
            guard let asset = assetsBySymbol[spec.symbol],
                  let account = accountsByName[spec.accountName] else { continue }
            let txn = PortfolioTransaction(
                date: syntheticBuyDate,
                type: .buy,
                asset: asset,
                account: account,
                quantity: spec.qty,
                price: spec.avgCost,
                amount: spec.qty * spec.avgCost,
                currency: "USD"
            )
            context.insert(txn)
        }
        for wallet in seedCryptoWallets {
            guard let asset = assetsBySymbol[wallet.symbol],
                  let account = accountsByName[wallet.walletAccountName] else { continue }
            let txn = PortfolioTransaction(
                date: syntheticBuyDate,
                type: .buy,
                asset: asset,
                account: account,
                quantity: wallet.qty,
                price: wallet.avgCost,
                amount: wallet.qty * wallet.avgCost,
                currency: "USD"
            )
            context.insert(txn)
        }

        // 5. Actual mock transactions (12 rows)
        for spec in seedMockTransactions {
            let asset: Asset? = spec.assetSymbol.flatMap { assetsBySymbol[$0] }
            guard let account = accountsByName[spec.accountName] else { continue }
            let txn = PortfolioTransaction(
                date: parseDate(spec.date),
                type: spec.type,
                asset: asset,
                account: account,
                quantity: spec.qty,
                price: spec.price,
                amount: spec.amount,
                currency: "USD"
            )
            context.insert(txn)
        }

        try context.save()
    }

    // MARK: - Fixed dates

    static let syntheticBuyDate: Date = {
        var c = DateComponents()
        c.year = 2024; c.month = 5; c.day = 20; c.hour = 12
        c.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: c)!
    }()

    private static func parseDate(_ iso: String) -> Date {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        return f.date(from: iso) ?? Date()
    }

    // MARK: - Seed specs

    struct AccountSpec { let name: String; let kind: AccountKind; let mask: String; let currency: String; let colorHex: UInt32 }
    struct AssetSpec { let symbol: String; let name: String; let kind: AssetKind; let currency: String; let colorHex: UInt32; let price: Decimal }
    struct StockSpec { let symbol: String; let name: String; let kind: AssetKind; let accountName: String; let qty: Decimal; let avgCost: Decimal; let price: Decimal }
    struct CryptoSpec { let symbol: String; let name: String; let price: Decimal }
    struct CryptoWalletSpec { let symbol: String; let walletAccountName: String; let qty: Decimal; let avgCost: Decimal; let colorHex: UInt32 }
    struct MockTxnSpec { let date: String; let type: TransactionType; let assetSymbol: String?; let qty: Decimal?; let price: Decimal?; let amount: Decimal; let accountName: String }

    static let seedAccounts: [AccountSpec] = [
        .init(name: "Schwab",    kind: .brokerage, mask: "••• 4821", currency: "USD", colorHex: 0x0099A8),
        .init(name: "Fidelity",  kind: .brokerage, mask: "••• 7102", currency: "USD", colorHex: 0x7A4F9B),
        .init(name: "Vanguard",  kind: .brokerage, mask: "••• 2340", currency: "USD", colorHex: 0xC5392E),
        .init(name: "Robinhood", kind: .brokerage, mask: "••• 0064", currency: "USD", colorHex: 0x00B26A),
        .init(name: "Binance",   kind: .exchange,  mask: "@user",    currency: "USD", colorHex: 0xF0B90B),
        .init(name: "Coinbase",  kind: .exchange,  mask: "@user",    currency: "USD", colorHex: 0x1652F0),
        .init(name: "Ledger",    kind: .wallet,    mask: "0x42…ae",  currency: "USD", colorHex: 0x1D1D1F),
        .init(name: "MetaMask",  kind: .wallet,    mask: "0x8f…20",  currency: "USD", colorHex: 0xF6851B),
        .init(name: "Phantom",   kind: .wallet,    mask: "Sol…q9",   currency: "USD", colorHex: 0x9945FF),
    ]

    static let seedStocks: [StockSpec] = [
        .init(symbol: "AAPL",  name: "Apple Inc.",                kind: .stock, accountName: "Schwab",    qty: 320, avgCost: 152.40, price: 214.66),
        .init(symbol: "MSFT",  name: "Microsoft Corp.",           kind: .stock, accountName: "Schwab",    qty: 145, avgCost: 280.10, price: 432.18),
        .init(symbol: "NVDA",  name: "NVIDIA Corp.",              kind: .stock, accountName: "Fidelity",  qty: 380, avgCost:  98.40, price: 142.55),
        .init(symbol: "GOOGL", name: "Alphabet Inc. Class A",     kind: .stock, accountName: "Schwab",    qty: 210, avgCost: 124.50, price: 178.92),
        .init(symbol: "VTI",   name: "Vanguard Total Stock Mkt",  kind: .etf,   accountName: "Vanguard",  qty: 180, avgCost: 218.30, price: 276.40),
        .init(symbol: "AMZN",  name: "Amazon.com, Inc.",          kind: .stock, accountName: "Fidelity",  qty: 215, avgCost: 138.40, price: 196.55),
        .init(symbol: "COST",  name: "Costco Wholesale Corp.",    kind: .stock, accountName: "Schwab",    qty:  42, avgCost: 580.20, price: 924.10),
        .init(symbol: "TSLA",  name: "Tesla, Inc.",               kind: .stock, accountName: "Robinhood", qty:  68, avgCost: 248.00, price: 195.42),
        .init(symbol: "BRK.B", name: "Berkshire Hathaway B",      kind: .stock, accountName: "Vanguard",  qty:  72, avgCost: 348.00, price: 462.30),
        .init(symbol: "JNJ",   name: "Johnson & Johnson",         kind: .stock, accountName: "Fidelity",  qty: 110, avgCost: 168.10, price: 156.84),
    ]

    static let seedCryptos: [CryptoSpec] = [
        .init(symbol: "BTC",   name: "Bitcoin",   price: 92480.10),
        .init(symbol: "ETH",   name: "Ethereum",  price: 3284.50),
        .init(symbol: "SOL",   name: "Solana",    price: 184.20),
        .init(symbol: "LINK",  name: "Chainlink", price: 18.62),
        .init(symbol: "MATIC", name: "Polygon",   price: 0.582),
        .init(symbol: "USDC",  name: "USD Coin",  price: 1.00),
    ]

    static let seedCryptoWallets: [CryptoWalletSpec] = [
        // BTC
        .init(symbol: "BTC",  walletAccountName: "Binance",  qty: 0.620, avgCost: 41200.00, colorHex: 0xF0B90B),
        .init(symbol: "BTC",  walletAccountName: "Ledger",   qty: 0.310, avgCost: 28900.00, colorHex: 0x1D1D1F),
        .init(symbol: "BTC",  walletAccountName: "Coinbase", qty: 0.145, avgCost: 52300.00, colorHex: 0x1652F0),
        // ETH
        .init(symbol: "ETH",  walletAccountName: "MetaMask", qty: 4.20,  avgCost: 1980.00,  colorHex: 0xF6851B),
        .init(symbol: "ETH",  walletAccountName: "Ledger",   qty: 2.85,  avgCost: 1620.00,  colorHex: 0x1D1D1F),
        .init(symbol: "ETH",  walletAccountName: "Binance",  qty: 1.55,  avgCost: 2410.00,  colorHex: 0xF0B90B),
        // SOL
        .init(symbol: "SOL",  walletAccountName: "Phantom",  qty: 38.0,  avgCost: 92.40,    colorHex: 0x9945FF),
        .init(symbol: "SOL",  walletAccountName: "Binance",  qty: 16.5,  avgCost: 124.80,   colorHex: 0xF0B90B),
        // LINK
        .init(symbol: "LINK", walletAccountName: "MetaMask", qty: 240,   avgCost: 11.40,    colorHex: 0xF6851B),
        .init(symbol: "LINK", walletAccountName: "Ledger",   qty: 180,   avgCost: 7.80,     colorHex: 0x1D1D1F),
        // MATIC
        .init(symbol: "MATIC", walletAccountName: "MetaMask", qty: 1800, avgCost: 0.92,     colorHex: 0xF6851B),
        // USDC
        .init(symbol: "USDC", walletAccountName: "Coinbase", qty: 1820,  avgCost: 1.00,     colorHex: 0x1652F0),
    ]

    static let seedMockTransactions: [MockTxnSpec] = [
        .init(date: "2026-05-14", type: .buy,      assetSymbol: "NVDA",  qty: 40,    price: 142.55,   amount: 5702.00,  accountName: "Fidelity"),
        .init(date: "2026-05-08", type: .dividend, assetSymbol: "AAPL",  qty: nil,   price: nil,      amount: 76.80,    accountName: "Schwab"),
        .init(date: "2026-05-02", type: .buy,      assetSymbol: "BTC",   qty: 0.04,  price: 91200.00, amount: 3648.00,  accountName: "Binance"),
        .init(date: "2026-04-26", type: .sell,     assetSymbol: "TSLA",  qty: 20,    price: 198.40,   amount: 3968.00,  accountName: "Robinhood"),
        .init(date: "2026-04-18", type: .deposit,  assetSymbol: nil,     qty: nil,   price: nil,      amount: 10000.00, accountName: "Schwab"),
        .init(date: "2026-04-09", type: .buy,      assetSymbol: "MSFT",  qty: 15,    price: 428.10,   amount: 6421.50,  accountName: "Schwab"),
        .init(date: "2026-04-02", type: .stake,    assetSymbol: "ETH",   qty: 0.50,  price: 3210.00,  amount: 1605.00,  accountName: "MetaMask"),
        .init(date: "2026-03-28", type: .buy,      assetSymbol: "VTI",   qty: 25,    price: 272.10,   amount: 6802.50,  accountName: "Vanguard"),
        .init(date: "2026-03-21", type: .dividend, assetSymbol: "MSFT",  qty: nil,   price: nil,      amount: 108.75,   accountName: "Schwab"),
        .init(date: "2026-03-15", type: .sell,     assetSymbol: "JNJ",   qty: 18,    price: 158.20,   amount: 2847.60,  accountName: "Fidelity"),
        .init(date: "2026-03-04", type: .buy,      assetSymbol: "SOL",   qty: 12,    price: 168.40,   amount: 2020.80,  accountName: "Phantom"),
        .init(date: "2026-02-22", type: .buy,      assetSymbol: "GOOGL", qty: 30,    price: 174.55,   amount: 5236.50,  accountName: "Schwab"),
    ]

    // MARK: - Helpers

    private static func stockToAsset(_ s: StockSpec) -> AssetSpec {
        AssetSpec(symbol: s.symbol, name: s.name, kind: s.kind, currency: "USD", colorHex: 0x8E8E93, price: s.price)
    }

    private static func cryptoToAsset(_ c: CryptoSpec) -> AssetSpec {
        AssetSpec(symbol: c.symbol, name: c.name, kind: .crypto, currency: "USD", colorHex: 0xF7931A, price: c.price)
    }
}
