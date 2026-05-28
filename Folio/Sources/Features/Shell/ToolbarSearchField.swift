import SwiftUI
import SwiftData

/// ⌘K-driven asset finder. Renders a focusable `TextField` styled to match the
/// previous stub; when the query is non-empty, a popover anchors below listing
/// up to 8 matches by ticker or asset name. Enter on a match routes to Stocks
/// or Crypto (whichever owns the asset's kind) and clears the field.
///
/// Focus is driven by `router.searchFocused`: ⌘K flips that to `true` and the
/// `@FocusState` here syncs both ways so clicking the field also exposes the
/// focus state to the rest of the app (currently unused but harmless).
struct ToolbarSearchField: View {
    @Environment(\.theme) private var theme
    @Environment(AppRouter.self) private var router

    @Query(sort: \Asset.symbol) private var assets: [Asset]

    @State private var search = AssetSearch()
    @FocusState private var focused: Bool

    var body: some View {
        @Bindable var router = router

        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(theme.text3)
            TextField("Search", text: $search.query)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(theme.text)
                .focused($focused)
                .onSubmit(submitTopMatch)
            if !search.query.isEmpty {
                Button {
                    search.reset()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(theme.text3)
                }
                .buttonStyle(.plain)
            } else {
                Text("⌘K")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(theme.text3)
            }
        }
        .padding(.horizontal, 10)
        .frame(width: 240, height: 28)
        .background(theme.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(focused ? theme.borderStrong : theme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .onChange(of: router.searchFocused) { _, newValue in
            if newValue {
                focused = true
                router.searchFocused = false
            }
        }
        .popover(isPresented: matchPopoverBinding, attachmentAnchor: .point(.bottom), arrowEdge: .top) {
            matchList
        }
    }

    private var matches: [Asset] { search.matches(in: assets) }

    /// Drive the popover via a Binding so it auto-dismisses when the query
    /// goes empty (instead of leaving an empty popover open).
    private var matchPopoverBinding: Binding<Bool> {
        Binding(
            get: { !matches.isEmpty && focused },
            set: { isShown in
                if !isShown { search.reset() }
            }
        )
    }

    private var matchList: some View {
        VStack(spacing: 0) {
            ForEach(matches, id: \.persistentModelID) { asset in
                Button {
                    activate(asset)
                } label: {
                    matchRow(asset: asset)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(width: 280)
        .padding(6)
    }

    private func matchRow(asset: Asset) -> some View {
        HStack(spacing: 10) {
            Text(asset.symbol)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(theme.text)
                .frame(width: 56, alignment: .leading)
            Text(asset.name)
                .font(.system(size: 12))
                .foregroundStyle(theme.text2)
                .lineLimit(1)
            Spacer(minLength: 0)
            Text(asset.kind.displayName)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(theme.text3)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private func submitTopMatch() {
        guard let first = matches.first else { return }
        activate(first)
    }

    private func activate(_ asset: Asset) {
        switch asset.kind {
        case .stock, .etf:
            router.selection = .stocks
        case .crypto:
            router.selection = .crypto
        case .cash:
            // No screen for cash holdings; bail without changing selection.
            break
        }
        search.reset()
        focused = false
    }
}
