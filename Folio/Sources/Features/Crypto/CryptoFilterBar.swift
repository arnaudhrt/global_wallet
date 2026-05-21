import SwiftUI

/// Wallet/exchange filter pills, expand/collapse-all controls, and a sort
/// menu. Pills carry a small leading colored Dot derived from the account's
/// `colorHex` so users can map the pill to the colored dot on each sub-row.
struct CryptoFilterBar: View {
    @Environment(\.theme) private var theme

    let wallets: [WalletPill]
    @Binding var selectedWallet: String?
    @Binding var sort: CryptoSort
    let onExpandAll: () -> Void
    let onCollapseAll: () -> Void
    let expandControlsEnabled: Bool

    struct WalletPill: Identifiable, Hashable {
        let name: String
        let colorHex: UInt32
        var id: String { name }
    }

    var body: some View {
        HStack(alignment: .center) {
            HStack(spacing: 8) {
                FilterPill(
                    label: "All wallets",
                    isActive: selectedWallet == nil
                ) { selectedWallet = nil }

                ForEach(wallets) { wallet in
                    walletPill(wallet)
                }
            }

            Spacer()

            HStack(spacing: 8) {
                expandCollapseButton(label: "Collapse all", action: onCollapseAll)
                expandCollapseButton(label: "Expand all", action: onExpandAll)
                sortMenu
            }
        }
    }

    @ViewBuilder
    private func walletPill(_ wallet: WalletPill) -> some View {
        let active = selectedWallet == wallet.name
        Button {
            selectedWallet = active ? nil : wallet.name
        } label: {
            HStack(spacing: 6) {
                Dot(color: Color(hex: wallet.colorHex), size: 8)
                Text(wallet.name)
                    .font(.system(size: 12, weight: .medium))
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 5)
            .background(active ? theme.text : theme.cardBg)
            .foregroundStyle(active ? theme.cardBg : theme.text2)
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(active ? theme.text : theme.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .contentShape(RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func expandCollapseButton(label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(expandControlsEnabled ? theme.text2 : theme.text3)
                .padding(.horizontal, 11)
                .padding(.vertical, 5)
                .background(theme.cardBg)
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(theme.border, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
        .disabled(!expandControlsEnabled)
    }

    private var sortMenu: some View {
        HStack(spacing: 8) {
            Text("Sort by")
                .font(.system(size: 12))
                .foregroundStyle(theme.text2)

            Menu {
                ForEach(CryptoSortColumn.allCases, id: \.self) { col in
                    Button {
                        if sort.column == col {
                            sort.ascending.toggle()
                        } else {
                            sort = CryptoSort(column: col, ascending: false)
                        }
                    } label: {
                        HStack {
                            Text(col.label)
                            if sort.column == col {
                                Image(systemName: sort.ascending ? "arrow.up" : "arrow.down")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(sort.column.label)
                        .font(.system(size: 12))
                        .foregroundStyle(theme.text)
                    Image(systemName: sort.ascending ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(theme.text2)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(theme.border, lineWidth: 1)
                )
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
    }
}
