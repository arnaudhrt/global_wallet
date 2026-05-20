import SwiftUI

/// Temporary placeholder shown by the toolbar "+ Add holding" button. Replaced
/// by the real Add Transaction form in M9.
struct AddTransactionStubSheet: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Add Transaction")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(theme.text)
            Text("The full Add Transaction form ships in M9. This stub confirms the toolbar wiring works.")
                .font(.system(size: 13))
                .foregroundStyle(theme.text2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            HStack {
                Spacer()
                Button("Close") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(24)
        .frame(width: 480, height: 220)
        .background(theme.bg)
    }
}
