import XCTest
import SwiftData
@testable import Folio

@MainActor
final class TransactionsRowsBuilderTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext { container.mainContext }

    override func setUp() async throws {
        // Empty in-memory container — these tests build their own fixtures
        // so YTD assertions don't drift with the calendar.
        container = try ModelContainer(
            for: Account.self, Asset.self, PortfolioTransaction.self,
                 PriceQuote.self, FXRate.self, AppSettings.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    override func tearDown() async throws {
        container = nil
    }

    // MARK: - Fixture helpers

    /// Fixed reference date inside 2026 used to anchor every YTD test.
    private let nowIn2026 = makeDate("2026-05-21")

    private static func makeDate(_ iso: String) -> Date {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        return f.date(from: iso)!
    }

    private func account(_ name: String) -> Account {
        let a = Account(name: name, kind: .brokerage, mask: "•", currency: "USD", colorHex: 0)
        context.insert(a)
        return a
    }

    private func asset(_ symbol: String, kind: AssetKind = .stock) -> Asset {
        let a = Asset(symbol: symbol, name: symbol, kind: kind, currency: "USD", colorHex: 0)
        context.insert(a)
        return a
    }

    private func txn(
        _ type: TransactionType,
        amount: Decimal,
        date: String = "2026-05-14",
        asset: Asset? = nil,
        account: Account? = nil,
        quantity: Decimal? = nil,
        price: Decimal? = nil
    ) -> PortfolioTransaction {
        let acc = account ?? self.account("Schwab")
        let t = PortfolioTransaction(
            date: Self.makeDate(date),
            type: type,
            asset: asset,
            account: acc,
            quantity: quantity,
            price: price,
            amount: amount,
            currency: "USD"
        )
        context.insert(t)
        return t
    }

    // MARK: - Sort

    func testDefaultSortReturnsNewestFirst() throws {
        let older = txn(.buy, amount: 100, date: "2026-03-15")
        let newer = txn(.buy, amount: 100, date: "2026-05-14")
        let rows = TransactionsRowsBuilder.filterAndSort([older, newer], type: nil, sort: .default)
        XCTAssertEqual(rows.first?.date, newer.date)
        XCTAssertEqual(rows.last?.date, older.date)
    }

    func testSortByTypeAscendingUsesRawValueOrder() throws {
        // Raw values: buy, deposit, dividend, sell, stake, transfer, withdraw
        let s = txn(.sell, amount: 1)
        let b = txn(.buy, amount: 1)
        let d = txn(.dividend, amount: 1)
        let rows = TransactionsRowsBuilder.filterAndSort(
            [s, b, d], type: nil,
            sort: TxnSort(column: .type, ascending: true)
        )
        XCTAssertEqual(rows.map { $0.type }, [.buy, .dividend, .sell])
    }

    func testSortByTotalDescendingPutsBiggestFirst() throws {
        let small = txn(.buy, amount: 100)
        let big = txn(.buy, amount: 10000)
        let mid = txn(.buy, amount: 500)
        let rows = TransactionsRowsBuilder.filterAndSort(
            [small, big, mid], type: nil,
            sort: TxnSort(column: .total, ascending: false)
        )
        XCTAssertEqual(rows.map { $0.amount }, [10000, 500, 100])
    }

    // MARK: - Filter

    func testFilterByBuyDropsOtherTypes() throws {
        let b1 = txn(.buy, amount: 100)
        let s1 = txn(.sell, amount: 50)
        let d1 = txn(.dividend, amount: 10)
        let b2 = txn(.buy, amount: 200)
        let rows = TransactionsRowsBuilder.filterAndSort(
            [b1, s1, d1, b2], type: .buy, sort: .default
        )
        XCTAssertEqual(rows.count, 2)
        XCTAssertTrue(rows.allSatisfy { $0.type == .buy })
    }

    // MARK: - YTD aggregates

    func testTransactionsYTDKeepsOnlyCurrentYear() throws {
        let in2024 = txn(.buy, amount: 100, date: "2024-12-30")
        let in2025 = txn(.buy, amount: 100, date: "2025-06-15")
        let early2026 = txn(.buy, amount: 100, date: "2026-01-02")
        let may2026 = txn(.buy, amount: 100, date: "2026-05-14")
        let ytd = TransactionsRowsBuilder.transactionsYTD(
            from: [in2024, in2025, early2026, may2026],
            now: nowIn2026
        )
        XCTAssertEqual(Set(ytd.map { $0.date }), [early2026.date, may2026.date])
    }

    func testNetInflowsYTDSumsInflowsMinusOutflows() throws {
        // Inflows: sell 500 + dividend 100 + deposit 1000 = 1600
        // Outflows: buy 300 + withdraw 200 = 500
        // Stake and transfer must be ignored.
        let sell = txn(.sell, amount: 500)
        let dividend = txn(.dividend, amount: 100)
        let deposit = txn(.deposit, amount: 1000)
        let buy = txn(.buy, amount: 300)
        let withdraw = txn(.withdraw, amount: 200)
        let stake = txn(.stake, amount: 999)
        let transfer = txn(.transfer, amount: 999)

        let net = TransactionsRowsBuilder.netInflowsYTD(
            from: [sell, dividend, deposit, buy, withdraw, stake, transfer],
            now: nowIn2026
        )
        XCTAssertEqual(net, Decimal(1100))
    }

    func testIncomeYTDOnlyDividendAndStake() throws {
        let dividend = txn(.dividend, amount: 75, date: "2026-03-21")
        let stake = txn(.stake, amount: 25, date: "2026-04-02")
        let buy = txn(.buy, amount: 9999) // should be ignored
        let lastYear = txn(.dividend, amount: 50, date: "2025-12-30") // ignored

        let income = TransactionsRowsBuilder.incomeYTD(
            from: [dividend, stake, buy, lastYear],
            now: nowIn2026
        )
        XCTAssertEqual(income, Decimal(100))
    }

    func testAccountsCountUsesDistinctNames() throws {
        let schwab = account("Schwab")
        let fidelity = account("Fidelity")
        let txns: [PortfolioTransaction] = [
            txn(.buy, amount: 1, account: schwab),
            txn(.buy, amount: 1, account: schwab),
            txn(.sell, amount: 1, account: fidelity),
        ]
        XCTAssertEqual(TransactionsRowsBuilder.accountsCount(in: txns), 2)
    }
}
