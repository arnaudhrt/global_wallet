import SwiftUI

/// Filter pills + sort menu above the stocks table.
struct StocksFilterBar: View {
    @Environment(\.theme) private var theme

    let accountNames: [String]
    @Binding var selectedAccount: String?
    @Binding var sort: StocksSort

    var body: some View {
        HStack(alignment: .center) {
            HStack(spacing: 8) {
                FilterPill(
                    label: "All accounts",
                    isActive: selectedAccount == nil
                ) { selectedAccount = nil }

                ForEach(accountNames, id: \.self) { name in
                    FilterPill(
                        label: name,
                        isActive: selectedAccount == name
                    ) { selectedAccount = name }
                }
            }

            Spacer()

            sortMenu
        }
    }

    private var sortMenu: some View {
        HStack(spacing: 8) {
            Text("Sort by")
                .font(.system(size: 12))
                .foregroundStyle(theme.text2)

            Menu {
                ForEach(StocksSortColumn.allCases, id: \.self) { col in
                    Button {
                        if sort.column == col {
                            sort.ascending.toggle()
                        } else {
                            sort = StocksSort(column: col, ascending: false)
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
