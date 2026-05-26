import SwiftUI

/// Local-only asset autocomplete. Searches existing `Asset` rows by symbol
/// and name substring; the live `QuoteProvider.search()` flow is deferred to
/// v2 (M9 decision 2026-05-26).
///
/// Pre-filters by `accountKind` so brokerage accounts see stocks/ETFs and
/// exchange/wallet accounts see crypto. When `accountKind == nil` (no account
/// picked yet), everything is visible.
struct AssetPicker: View {
    @Environment(\.theme) private var theme

    let assets: [Asset]
    let accountKind: AccountKind?
    @Binding var selection: Asset?

    @State private var query: String = ""
    @State private var isShowingList: Bool = false
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            field
            if isShowingList && !filtered.isEmpty {
                list
            } else if isShowingList && filtered.isEmpty {
                emptyHint
            }
        }
    }

    private var field: some View {
        HStack(spacing: 8) {
            if let selection {
                TickerLogo(ticker: selection.symbol, size: 22)
                VStack(alignment: .leading, spacing: 1) {
                    Text(selection.symbol)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(theme.text)
                    Text(selection.name)
                        .font(.system(size: 11))
                        .foregroundStyle(theme.text3)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Button {
                    selection.symbol.isEmpty ? () : clear()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(theme.text3)
                }
                .buttonStyle(.plain)
                .help("Clear")
            } else {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundStyle(theme.text3)
                TextField("Search ticker or name…", text: $query)
                    .textFieldStyle(.plain)
                    .focused($isFocused)
                    .font(.system(size: 13))
                    .foregroundStyle(theme.text)
                    .onChange(of: isFocused) { _, focused in
                        isShowingList = focused
                    }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(theme.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .stroke(theme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 5))
    }

    private var list: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(filtered, id: \.persistentModelID) { asset in
                    Button {
                        pick(asset)
                    } label: {
                        HStack(spacing: 10) {
                            TickerLogo(ticker: asset.symbol, size: 22)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(asset.symbol)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(theme.text)
                                Text(asset.name)
                                    .font(.system(size: 11))
                                    .foregroundStyle(theme.text3)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 0)
                            Text(asset.kind.displayName)
                                .font(.system(size: 10))
                                .foregroundStyle(theme.text3)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .background(Color.clear)
                    Divider().opacity(0.4)
                }
            }
        }
        .frame(maxHeight: 180)
        .background(theme.cardBg)
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .stroke(theme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 5))
    }

    private var emptyHint: some View {
        Text(emptyHintMessage)
            .font(.system(size: 11))
            .foregroundStyle(theme.text3)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.cardBg)
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(theme.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 5))
    }

    private var emptyHintMessage: String {
        if assets.isEmpty {
            return "No assets exist yet. Seed data should populate on first launch."
        }
        if !candidatePool.isEmpty {
            return "No assets match \"\(query)\"."
        }
        // Pool itself is empty — wrong account kind for any asset.
        switch accountKind {
        case .brokerage: return "No stocks or ETFs available."
        case .exchange, .wallet: return "No crypto assets available."
        case .cash: return "Cash accounts don't hold tradeable assets."
        case .none: return "No assets available."
        }
    }

    // MARK: - Filtering

    /// Assets eligible for the current account kind, regardless of query.
    private var candidatePool: [Asset] {
        guard let accountKind else { return assets }
        switch accountKind {
        case .brokerage:
            return assets.filter { $0.kind == .stock || $0.kind == .etf }
        case .exchange, .wallet:
            return assets.filter { $0.kind == .crypto }
        case .cash:
            return []
        }
    }

    private var filtered: [Asset] {
        let pool = candidatePool
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        let matches: [Asset]
        if q.isEmpty {
            matches = pool
        } else {
            matches = pool.filter {
                $0.symbol.lowercased().contains(q) || $0.name.lowercased().contains(q)
            }
        }
        return matches.sorted { $0.symbol < $1.symbol }
    }

    // MARK: - Actions

    private func pick(_ asset: Asset) {
        selection = asset
        query = ""
        isShowingList = false
        isFocused = false
    }

    private func clear() {
        selection = nil
        query = ""
        isShowingList = true
        isFocused = true
    }
}
