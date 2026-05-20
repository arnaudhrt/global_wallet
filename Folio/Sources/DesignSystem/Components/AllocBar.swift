import SwiftUI

struct AllocBar: View {
    @Environment(\.theme) private var theme

    let pct: Double
    var color: Color? = nil
    var width: CGFloat = 80

    var body: some View {
        HStack(spacing: 8) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(theme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(theme.border, lineWidth: 1)
                    )

                RoundedRectangle(cornerRadius: 3)
                    .fill(color ?? theme.green)
                    .frame(width: width * min(1, max(0, pct / 100)))
            }
            .frame(width: width, height: 6)

            Text(String(format: "%.1f%%", pct))
                .font(.system(size: 11, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(theme.text2)
                .frame(width: 36, alignment: .trailing)
        }
    }
}
