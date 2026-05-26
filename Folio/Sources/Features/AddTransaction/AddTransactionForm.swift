import Foundation
import Observation

/// Form state for the Add Transaction sheet. Type-adaptive — `needsAsset`,
/// `needsQtyPrice`, `needsAmount`, `needsDestination` derive from `type` and
/// drive which fields the sheet shows.
///
/// Numeric inputs are stored as `String` (rather than `Decimal`) so the
/// `TextField` source-of-truth stays in sync with user keystrokes including
/// trailing dots and partial entries. Conversion to `Decimal` happens in
/// `parsedQty` / `parsedPrice` / `parsedAmount` / `parsedFee` with `.` and `,`
/// tolerance.
@MainActor
@Observable
final class AddTransactionForm {
    // MARK: - Inputs

    var type: TransactionType = .buy
    var date: Date = .init()
    var account: Account?
    var transferDestination: Account?
    var asset: Asset?

    var quantityText: String = ""
    var priceText: String = ""
    /// Holds the user-entered cash amount for dividend/deposit/withdraw/transfer.
    /// For buy/sell/stake the displayed total is computed via `computedTotal`.
    var amountText: String = ""
    var feeText: String = ""
    var notes: String = ""

    // MARK: - Type-driven affordances

    var needsAsset: Bool {
        switch type {
        case .buy, .sell, .dividend, .stake: return true
        case .deposit, .withdraw, .transfer: return false
        }
    }

    var needsQtyPrice: Bool {
        switch type {
        case .buy, .sell, .stake: return true
        case .dividend, .deposit, .withdraw, .transfer: return false
        }
    }

    var needsAmount: Bool {
        switch type {
        case .dividend, .deposit, .withdraw, .transfer: return true
        case .buy, .sell, .stake: return false
        }
    }

    var needsDestination: Bool { type == .transfer }

    // MARK: - Currency derivation

    /// Currency the transaction is denominated in. Trades follow the asset's
    /// native currency (e.g. ASML in EUR); cash events follow the source
    /// account's currency. Read-only in M9 — the M10 base-currency picker is
    /// where users will pick alternate denominations.
    var effectiveCurrency: String {
        if needsQtyPrice || type == .dividend {
            return asset?.currency ?? account?.currency ?? "USD"
        }
        return account?.currency ?? "USD"
    }

    var accountCurrency: String { account?.currency ?? "USD" }

    /// True when txn-currency differs from the source account's currency. The
    /// sheet renders an FX preview row when this is true.
    var needsFXPreview: Bool {
        effectiveCurrency != accountCurrency
    }

    // MARK: - Parsed numerics

    var parsedQty: Decimal? { Self.parseDecimal(quantityText) }
    var parsedPrice: Decimal? { Self.parseDecimal(priceText) }
    var parsedAmount: Decimal? { Self.parseDecimal(amountText) }
    var parsedFee: Decimal {
        // Blank fee defaults to 0 — that's the dominant case so we don't
        // force users to type it.
        let trimmed = feeText.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return 0 }
        return Self.parseDecimal(trimmed) ?? 0
    }

    /// Computed total for buy/sell/stake: qty × price. Nil if either side is
    /// missing or unparseable.
    var computedTotal: Decimal? {
        guard let q = parsedQty, let p = parsedPrice else { return nil }
        return q * p
    }

    /// The amount that lands on `PortfolioTransaction.amount` at save time.
    /// Routes by type: trades use computedTotal, cash events use the
    /// user-entered amount field.
    var effectiveAmount: Decimal? {
        needsAmount ? parsedAmount : computedTotal
    }

    // MARK: - Validation

    enum ValidationError: Equatable {
        case missingAccount
        case missingAsset
        case missingDestination
        case sameSourceAndDestination
        case missingQuantity
        case nonPositiveQuantity
        case missingPrice
        case negativePrice
        case missingAmount
        case nonPositiveAmount
        case negativeFee

        var message: String {
            switch self {
            case .missingAccount:           return "Pick an account."
            case .missingAsset:             return "Pick an asset."
            case .missingDestination:       return "Pick a destination account."
            case .sameSourceAndDestination: return "Source and destination must differ."
            case .missingQuantity:          return "Enter a quantity."
            case .nonPositiveQuantity:      return "Quantity must be greater than zero."
            case .missingPrice:             return "Enter a price."
            case .negativePrice:            return "Price can't be negative."
            case .missingAmount:            return "Enter an amount."
            case .nonPositiveAmount:        return "Amount must be greater than zero."
            case .negativeFee:              return "Fee can't be negative."
            }
        }
    }

    func validate() -> ValidationError? {
        guard account != nil else { return .missingAccount }

        if needsDestination {
            guard let dest = transferDestination else { return .missingDestination }
            if dest.persistentModelID == account?.persistentModelID {
                return .sameSourceAndDestination
            }
        }

        if needsAsset && asset == nil { return .missingAsset }

        if needsQtyPrice {
            guard let q = parsedQty else { return .missingQuantity }
            if q <= 0 { return .nonPositiveQuantity }
            guard let p = parsedPrice else { return .missingPrice }
            if p < 0 { return .negativePrice }
        }

        if needsAmount {
            guard let a = parsedAmount else { return .missingAmount }
            if a <= 0 { return .nonPositiveAmount }
        }

        if parsedFee < 0 { return .negativeFee }

        return nil
    }

    var isValid: Bool { validate() == nil }

    // MARK: - Build

    /// Constructs a fresh `PortfolioTransaction`. Caller is responsible for
    /// `context.insert(...)` + `context.save()`. Precondition: `validate()`
    /// must return nil first.
    func build() -> PortfolioTransaction? {
        guard validate() == nil, let account, let amount = effectiveAmount else { return nil }

        let txnAsset: Asset? = needsAsset ? asset : nil
        let qty: Decimal? = needsQtyPrice ? parsedQty : nil
        let price: Decimal? = needsQtyPrice ? parsedPrice : nil
        let dest: Account? = needsDestination ? transferDestination : nil

        return PortfolioTransaction(
            date: date,
            type: type,
            asset: txnAsset,
            account: account,
            transferDestination: dest,
            quantity: qty,
            price: price,
            amount: amount,
            currency: effectiveCurrency,
            fee: parsedFee,
            feeCurrency: effectiveCurrency,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    // MARK: - Reset

    /// Called when the sheet opens so a previously-cancelled draft doesn't
    /// linger.
    func reset() {
        type = .buy
        date = Date()
        account = nil
        transferDestination = nil
        asset = nil
        quantityText = ""
        priceText = ""
        amountText = ""
        feeText = ""
        notes = ""
    }

    // MARK: - Parsing

    /// Lenient Decimal parser: accepts "1234.56", "1,234.56", "1234,56" (EU),
    /// ignores surrounding whitespace and currency symbols. Returns nil for
    /// empty or unparseable input.
    static func parseDecimal(_ raw: String) -> Decimal? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        // Strip thousands separators heuristically — if the string contains
        // both `,` and `.`, treat `,` as thousands. Otherwise treat the lone
        // separator as a decimal point.
        var s = trimmed
        s.removeAll { $0 == " " || $0 == "\u{00A0}" }
        let hasDot = s.contains(".")
        let hasComma = s.contains(",")
        if hasDot && hasComma {
            s.removeAll { $0 == "," }
        } else if hasComma && !hasDot {
            s = s.replacingOccurrences(of: ",", with: ".")
        }
        return Decimal(string: s, locale: Locale(identifier: "en_US_POSIX"))
    }
}
