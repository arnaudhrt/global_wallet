import XCTest
import SwiftData
@testable import Folio

@MainActor
final class HoldingsReducerTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext { container.mainContext }

    override func setUp() async throws {
        container = try ModelContainer.folio(inMemory: true)
    }

    override func tearDown() async throws {
        container = nil
    }

    private func priceFromSeed(_ asset: Asset) -> Decimal? {
        asset.quotes.first?.amount
    }

    private func usdOnly(_ from: String, _ to: String, _ date: Date) -> Decimal? {
        (from == to) ? 1 : nil
    }

    func testAaplRollupHasExpectedQty() throws {
        let txns = try context.fetch(FetchDescriptor<PortfolioTransaction>())
        let holdings = HoldingsReducer.reduceByAsset(
            transactions: txns,
            priceFor: priceFromSeed,
            fxAt: usdOnly,
            baseCurrency: "USD"
        )
        let aapl = try XCTUnwrap(holdings.first { $0.asset.symbol == "AAPL" })
        // Seed has synthetic Buy of 320; no AAPL buys/sells in the mock — qty stays 320.
        // (The May-8 AAPL Dividend doesn't change qty.)
        XCTAssertEqual(aapl.qty, 320)
        XCTAssertEqual(aapl.avgCost.amount, Decimal(string: "152.40"))
        XCTAssertEqual(aapl.marketValue?.amount, Decimal(string: "68691.2"))
    }

    func testNvdaQtyAfterAdditionalBuy() throws {
        let txns = try context.fetch(FetchDescriptor<PortfolioTransaction>())
        let holdings = HoldingsReducer.reduceByAsset(
            transactions: txns,
            priceFor: priceFromSeed,
            fxAt: usdOnly,
            baseCurrency: "USD"
        )
        let nvda = try XCTUnwrap(holdings.first { $0.asset.symbol == "NVDA" })
        // Synthetic seed Buy (380) + actual May-14 Buy (40) → 420
        XCTAssertEqual(nvda.qty, 420)
    }

    func testTslaSellReducesQtyButPreservesAvgCost() throws {
        let txns = try context.fetch(FetchDescriptor<PortfolioTransaction>())
        let holdings = HoldingsReducer.reduceByAsset(
            transactions: txns,
            priceFor: priceFromSeed,
            fxAt: usdOnly,
            baseCurrency: "USD"
        )
        let tsla = try XCTUnwrap(holdings.first { $0.asset.symbol == "TSLA" })
        // 68 synthetic - 20 sell = 48
        XCTAssertEqual(tsla.qty, 48)
        // Weighted-avg basis unaffected by sells
        XCTAssertEqual(tsla.avgCost.amount, Decimal(string: "248.00"))
    }

    func testBtcByAssetAndAccountSplitsAcrossWallets() throws {
        let txns = try context.fetch(FetchDescriptor<PortfolioTransaction>())
        let holdings = HoldingsReducer.reduceByAssetAndAccount(
            transactions: txns,
            priceFor: priceFromSeed,
            fxAt: usdOnly,
            baseCurrency: "USD"
        )
        let btcRows = holdings.filter { $0.asset.symbol == "BTC" }
        // 3 wallets (Binance/Ledger/Coinbase) + 1 Binance buy from mock = still 3 distinct (account, asset) buckets
        XCTAssertEqual(Set(btcRows.compactMap { $0.account?.name }), ["Binance", "Ledger", "Coinbase"])
    }

    func testBtcAggregatedByAssetSumsAcrossWallets() throws {
        let txns = try context.fetch(FetchDescriptor<PortfolioTransaction>())
        let holdings = HoldingsReducer.reduceByAsset(
            transactions: txns,
            priceFor: priceFromSeed,
            fxAt: usdOnly,
            baseCurrency: "USD"
        )
        let btc = try XCTUnwrap(holdings.first { $0.asset.symbol == "BTC" })
        // Synthetic seed: 0.620 + 0.310 + 0.145 = 1.075. Plus May-2 Binance buy 0.04 → 1.115
        XCTAssertEqual(btc.qty, Decimal(string: "1.115"))
    }

    func testDividendDoesNotChangeQty() throws {
        let txns = try context.fetch(FetchDescriptor<PortfolioTransaction>())
        // MSFT synthetic 145 + actual Apr-09 buy 15 → 160; the Mar-21 Dividend should not alter that.
        let holdings = HoldingsReducer.reduceByAsset(
            transactions: txns,
            priceFor: priceFromSeed,
            fxAt: usdOnly,
            baseCurrency: "USD"
        )
        let msft = try XCTUnwrap(holdings.first { $0.asset.symbol == "MSFT" })
        XCTAssertEqual(msft.qty, 160)
    }

    func testCrossCurrencyCostBasisUsesFxAtTxnDate() throws {
        // Drop a clean EUR buy into a fresh store and supply an fxAt closure
        // that returns 1.1 (EUR→USD). Cost basis should land at qty * price * 1.1
        // in the base currency.
        let isoContainer = try ModelContainer.folio(inMemory: true)
        let ctx = isoContainer.mainContext
        let asset = try XCTUnwrap(try ctx.fetch(FetchDescriptor<Asset>()).first { $0.symbol == "AAPL" })
        let account = try XCTUnwrap(try ctx.fetch(FetchDescriptor<Account>()).first { $0.name == "Schwab" })

        // Delete the seed's synthetic USD AAPL buy so this test sees only the EUR txn.
        let aaplTxns = try ctx.fetch(FetchDescriptor<PortfolioTransaction>())
            .filter { $0.asset?.symbol == "AAPL" }
        for t in aaplTxns { ctx.delete(t) }

        let txn = PortfolioTransaction(
            date: Date(),
            type: .buy,
            asset: asset,
            account: account,
            quantity: 10,
            price: 100,
            amount: 1000,
            currency: "EUR"
        )
        ctx.insert(txn)
        try ctx.save()

        let txns = try ctx.fetch(FetchDescriptor<PortfolioTransaction>())
        let eurToUsd: Decimal = Decimal(string: "1.1")!
        let holdings = HoldingsReducer.reduceByAsset(
            transactions: txns,
            priceFor: { _ in nil },
            fxAt: { from, to, _ in
                if from == to { return 1 }
                if from == "EUR", to == "USD" { return eurToUsd }
                return nil
            },
            baseCurrency: "USD"
        )
        let aapl = try XCTUnwrap(holdings.first { $0.asset.symbol == "AAPL" })
        XCTAssertEqual(aapl.qty, 10)
        // avgCost = (qty * price * fx) / qty = price * fx = 100 * 1.1 = 110
        XCTAssertEqual(aapl.avgCost.amount, Decimal(string: "110"))
        XCTAssertEqual(aapl.avgCost.currency, "USD")
    }

    func testOverSellClampsToZero() throws {
        // qty 5 then sell 10: bucket should clamp at 0 and disappear from output,
        // not flip to a negative-qty row with nonsense cost basis.
        let isoContainer = try ModelContainer.folio(inMemory: true)
        let ctx = isoContainer.mainContext
        let asset = try XCTUnwrap(try ctx.fetch(FetchDescriptor<Asset>()).first { $0.symbol == "VTI" })
        let account = try XCTUnwrap(try ctx.fetch(FetchDescriptor<Account>()).first { $0.name == "Vanguard" })

        // Wipe seed VTI transactions so we control the entire ledger.
        let vtiTxns = try ctx.fetch(FetchDescriptor<PortfolioTransaction>())
            .filter { $0.asset?.symbol == "VTI" }
        for t in vtiTxns { ctx.delete(t) }

        let now = Date()
        let buy = PortfolioTransaction(date: now.addingTimeInterval(-3600),
                                       type: .buy, asset: asset, account: account,
                                       quantity: 5, price: 200, amount: 1000, currency: "USD")
        let oversell = PortfolioTransaction(date: now,
                                            type: .sell, asset: asset, account: account,
                                            quantity: 10, price: 210, amount: 2100, currency: "USD")
        ctx.insert(buy); ctx.insert(oversell)
        try ctx.save()

        let txns = try ctx.fetch(FetchDescriptor<PortfolioTransaction>())
        let holdings = HoldingsReducer.reduceByAsset(
            transactions: txns,
            priceFor: { _ in nil },
            fxAt: usdOnly,
            baseCurrency: "USD"
        )
        // Bucket clamps to qty 0 → dropped from output (the `bucket.qty > 0` guard).
        XCTAssertNil(holdings.first { $0.asset.symbol == "VTI" })
    }

    func testSellAtExactQtyBoundaryYieldsZero() throws {
        // Sell qty exactly equal to current qty: bucket clamps to 0 and is
        // filtered out of output (same `bucket.qty > 0` guard as over-sell).
        let isoContainer = try ModelContainer.folio(inMemory: true)
        let ctx = isoContainer.mainContext
        let asset = try XCTUnwrap(try ctx.fetch(FetchDescriptor<Asset>()).first { $0.symbol == "AAPL" })
        let account = try XCTUnwrap(try ctx.fetch(FetchDescriptor<Account>()).first { $0.name == "Schwab" })

        let aaplTxns = try ctx.fetch(FetchDescriptor<PortfolioTransaction>())
            .filter { $0.asset?.symbol == "AAPL" }
        for t in aaplTxns { ctx.delete(t) }

        let now = Date()
        let buy = PortfolioTransaction(date: now.addingTimeInterval(-3600),
                                       type: .buy, asset: asset, account: account,
                                       quantity: 100, price: 50, amount: 5000, currency: "USD")
        let sell = PortfolioTransaction(date: now,
                                        type: .sell, asset: asset, account: account,
                                        quantity: 100, price: 60, amount: 6000, currency: "USD")
        ctx.insert(buy); ctx.insert(sell)
        try ctx.save()

        let txns = try ctx.fetch(FetchDescriptor<PortfolioTransaction>())
        let holdings = HoldingsReducer.reduceByAsset(
            transactions: txns,
            priceFor: { _ in nil },
            fxAt: usdOnly,
            baseCurrency: "USD"
        )
        XCTAssertNil(holdings.first { $0.asset.symbol == "AAPL" })
    }

    func testMultipleBuySellCyclesPreserveAvgCost() throws {
        // buy 100 @ $50 → sell 40 → buy 60 @ $50 → sell 50.
        // After: qty = 100 - 40 + 60 - 50 = 70; avg cost stays $50 throughout
        // because both buys came in at the same price and sells don't change avg.
        let isoContainer = try ModelContainer.folio(inMemory: true)
        let ctx = isoContainer.mainContext
        let asset = try XCTUnwrap(try ctx.fetch(FetchDescriptor<Asset>()).first { $0.symbol == "AAPL" })
        let account = try XCTUnwrap(try ctx.fetch(FetchDescriptor<Account>()).first { $0.name == "Schwab" })

        let aaplTxns = try ctx.fetch(FetchDescriptor<PortfolioTransaction>())
            .filter { $0.asset?.symbol == "AAPL" }
        for t in aaplTxns { ctx.delete(t) }

        let base = Date()
        let plan: [(Int, TransactionType, Decimal, Decimal)] = [
            (-4, .buy,  100, 50),
            (-3, .sell, 40,  60),
            (-2, .buy,  60,  50),
            (-1, .sell, 50,  70),
        ]
        for (offset, type, qty, price) in plan {
            let t = PortfolioTransaction(
                date: base.addingTimeInterval(Double(offset) * 3600),
                type: type, asset: asset, account: account,
                quantity: qty, price: price, amount: qty * price, currency: "USD"
            )
            ctx.insert(t)
        }
        try ctx.save()

        let txns = try ctx.fetch(FetchDescriptor<PortfolioTransaction>())
        let holdings = HoldingsReducer.reduceByAsset(
            transactions: txns,
            priceFor: { _ in nil },
            fxAt: usdOnly,
            baseCurrency: "USD"
        )
        let aapl = try XCTUnwrap(holdings.first { $0.asset.symbol == "AAPL" })
        XCTAssertEqual(aapl.qty, 70)
        XCTAssertEqual(aapl.avgCost.amount, 50)
    }

    func testMultiCurrencyBuyUsesFxAtTxnDate() throws {
        // Two EUR buys at different historical FX rates. Cost basis is the
        // weighted average of (qty * price * fx-at-that-date), not a single
        // current rate applied to both.
        let isoContainer = try ModelContainer.folio(inMemory: true)
        let ctx = isoContainer.mainContext
        let asset = try XCTUnwrap(try ctx.fetch(FetchDescriptor<Asset>()).first { $0.symbol == "AAPL" })
        let account = try XCTUnwrap(try ctx.fetch(FetchDescriptor<Account>()).first { $0.name == "Schwab" })

        let aaplTxns = try ctx.fetch(FetchDescriptor<PortfolioTransaction>())
            .filter { $0.asset?.symbol == "AAPL" }
        for t in aaplTxns { ctx.delete(t) }

        let d1 = Date().addingTimeInterval(-7200)
        let d2 = Date().addingTimeInterval(-3600)
        // Distinct prices so we can check both FX rates land on the right txn.
        let buy1 = PortfolioTransaction(date: d1, type: .buy, asset: asset, account: account,
                                        quantity: 10, price: 100, amount: 1000, currency: "EUR")
        let buy2 = PortfolioTransaction(date: d2, type: .buy, asset: asset, account: account,
                                        quantity: 10, price: 100, amount: 1000, currency: "EUR")
        ctx.insert(buy1); ctx.insert(buy2)
        try ctx.save()

        let txns = try ctx.fetch(FetchDescriptor<PortfolioTransaction>())
        let holdings = HoldingsReducer.reduceByAsset(
            transactions: txns,
            priceFor: { _ in nil },
            fxAt: { from, to, date in
                guard from == "EUR", to == "USD" else { return from == to ? 1 : nil }
                return date == d1 ? Decimal(string: "1.1")! : Decimal(string: "1.2")!
            },
            baseCurrency: "USD"
        )
        let aapl = try XCTUnwrap(holdings.first { $0.asset.symbol == "AAPL" })
        XCTAssertEqual(aapl.qty, 20)
        // (10 * 100 * 1.1 + 10 * 100 * 1.2) / 20 = (1100 + 1200) / 20 = 115
        XCTAssertEqual(aapl.avgCost.amount, Decimal(string: "115"))
    }

    func testMissingFxSkipsTxn() throws {
        // Construct a one-off txn in a fresh in-memory store with non-USD currency.
        let isoContainer = try ModelContainer.folio(inMemory: true)
        let ctx = isoContainer.mainContext
        let asset = try XCTUnwrap(try ctx.fetch(FetchDescriptor<Asset>(predicate: nil)).first { $0.symbol == "AAPL" })
        let account = try XCTUnwrap(try ctx.fetch(FetchDescriptor<Account>(predicate: nil)).first { $0.name == "Schwab" })
        let txn = PortfolioTransaction(
            date: Date(),
            type: .buy,
            asset: asset,
            account: account,
            quantity: 10,
            price: 100,
            amount: 1000,
            currency: "EUR" // not USD; usdOnly closure returns nil → txn skipped
        )
        ctx.insert(txn)
        try ctx.save()

        let txns = try ctx.fetch(FetchDescriptor<PortfolioTransaction>())
        let holdings = HoldingsReducer.reduceByAsset(
            transactions: txns,
            priceFor: { $0.quotes.first?.amount },
            fxAt: usdOnly,
            baseCurrency: "USD"
        )
        let aapl = try XCTUnwrap(holdings.first { $0.asset.symbol == "AAPL" })
        // Skipped EUR buy → qty stays at the seeded 320 (not 330)
        XCTAssertEqual(aapl.qty, 320)
    }
}
