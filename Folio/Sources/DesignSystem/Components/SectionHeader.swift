import SwiftUI

struct SectionHeader<Trailing: View>: View {
    @Environment(\.theme) private var theme

    let title: String
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .center) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(theme.text)
            Spacer()
            trailing()
        }
        .padding(.bottom, 10)
    }
}

extension SectionHeader where Trailing == EmptyView {
    init(_ title: String) {
        self.init(title: title, trailing: { EmptyView() })
    }
}
