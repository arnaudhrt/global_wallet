import SwiftUI

struct PeriodPills: View {
    @Environment(\.theme) private var theme

    @Binding var selection: String
    var options: [String] = ["1M", "3M", "YTD", "1Y", "All"]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.self) { opt in
                let active = opt == selection
                Button {
                    selection = opt
                } label: {
                    Text(opt)
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .foregroundStyle(active ? theme.text : theme.text2)
                        .background(
                            Group {
                                if active {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(theme.cardBg)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 4)
                                                .stroke(theme.border, lineWidth: 1)
                                        )
                                } else {
                                    Color.clear
                                }
                            }
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(theme.border, lineWidth: 1)
        )
    }
}
