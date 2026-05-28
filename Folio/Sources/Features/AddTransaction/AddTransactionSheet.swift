import SwiftUI
import SwiftData

/// Themed Add-Transaction sheet (M9). Replaces `AddTransactionStubSheet`.
///
/// Type-adaptive: buy/sell/stake show asset+qty+price (total auto-computed);
/// dividend shows asset+amount; deposit/withdraw show amount only; transfer
/// shows source+destination accounts. FX preview row appears when the txn
/// currency differs from the source account's currency.
///
/// Symbol autocomplete is **local-only** in M9 — searches existing `Asset`
/// rows. Live `QuoteProvider.search()` is v2 backlog.
struct AddTransactionSheet: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Account.name) private var accounts: [Account]
    @Query(sort: \Asset.symbol) private var assets: [Asset]
    @Query private var fxRates: [FXRate]

    @State private var form = AddTransactionForm()
    @State private var attemptedSave: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().opacity(0.6)
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 16) {
                    typeSection
                    dateAndAccountSection
                    if form.needsDestination {
                        destinationSection
                    }
                    if form.needsAsset {
                        assetSection
                    }
                    if form.needsQtyPrice {
                        qtyPriceSection
                    }
                    if form.needsAmount {
                        amountSection
                    }
                    feeNotesSection
                    if form.needsFXPreview {
                        fxPreviewRow
                    }
                    if attemptedSave, let err = form.validate() {
                        errorRow(err)
                    }
                }
                .padding(20)
            }
            Divider().opacity(0.6)
            footer
        }
        .frame(width: 520, height: 640)
        .background(theme.bg)
        .onAppear { form.reset() }
        .onChange(of: form.type) { _, _ in
            // Switching type can invalidate previously-required fields. Clear
            // attempted-save so users don't see stale errors.
            attemptedSave = false
        }
    }

    // MARK: - Header / footer

    private var header: some View {
        HStack {
            Text("Add Transaction")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(theme.text)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button("Cancel") { dismiss() }
                .keyboardShortcut(.cancelAction)
            Button("Save") { save() }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    // MARK: - Sections

    private var typeSection: some View {
        sectionContainer(label: "Type") {
            HStack(spacing: 6) {
                ForEach(TransactionType.allCases, id: \.self) { type in
                    FilterPill(
                        label: type.displayName,
                        isActive: form.type == type
                    ) { form.type = type }
                }
            }
        }
    }

    private var dateAndAccountSection: some View {
        HStack(alignment: .top, spacing: 14) {
            sectionContainer(label: "Date") {
                DatePicker("", selection: $form.date, displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.compact)
            }
            sectionContainer(label: form.needsDestination ? "From account" : "Account") {
                accountMenu(selection: Binding(
                    get: { form.account },
                    set: { form.account = $0 }
                ), excluding: nil)
            }
        }
    }

    private var destinationSection: some View {
        sectionContainer(label: "To account") {
            accountMenu(selection: Binding(
                get: { form.transferDestination },
                set: { form.transferDestination = $0 }
            ), excluding: form.account)
        }
    }

    private var assetSection: some View {
        sectionContainer(label: "Asset") {
            AssetPicker(
                assets: assets,
                accountKind: form.account?.kind,
                selection: $form.asset
            )
        }
    }

    private var qtyPriceSection: some View {
        HStack(alignment: .top, spacing: 14) {
            sectionContainer(label: "Quantity") {
                inputField(text: $form.quantityText, placeholder: "0", trailing: nil)
            }
            sectionContainer(label: "Price") {
                inputField(text: $form.priceText, placeholder: "0.00", trailing: form.effectiveCurrency)
            }
            sectionContainer(label: "Total") {
                totalReadout
            }
        }
    }

    private var amountSection: some View {
        sectionContainer(label: "Amount") {
            inputField(text: $form.amountText, placeholder: "0.00", trailing: form.effectiveCurrency)
        }
    }

    private var feeNotesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionContainer(label: "Fee (optional)") {
                inputField(text: $form.feeText, placeholder: "0.00", trailing: form.effectiveCurrency)
            }
            sectionContainer(label: "Notes (optional)") {
                TextField("", text: $form.notes, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(2...4)
                    .font(.system(size: 13))
                    .foregroundStyle(theme.text)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(theme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(theme.border, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 5))
            }
        }
    }

    private var fxPreviewRow: some View {
        let totalAmount = form.effectiveAmount ?? 0
        let rate = latestFXRate(from: form.effectiveCurrency, to: form.accountCurrency)
        return HStack(spacing: 8) {
            Image(systemName: "arrow.left.arrow.right")
                .font(.system(size: 11))
                .foregroundStyle(theme.text3)
            if let rate {
                let converted = totalAmount * rate
                Text("\(Money(amount: totalAmount, currency: form.effectiveCurrency).formatted()) ≈ \(Money(amount: converted, currency: form.accountCurrency).formatted())")
                    .font(.system(size: 12))
                    .foregroundStyle(theme.text2)
            } else {
                Text("FX rate \(form.effectiveCurrency)→\(form.accountCurrency) not cached yet — will resolve after next refresh.")
                    .font(.system(size: 12))
                    .foregroundStyle(theme.text3)
            }
            Spacer()
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

    // MARK: - Atoms

    private func sectionContainer<Content: View>(
        label: String,
        @ViewBuilder _ content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(theme.text3)
                .textCase(.uppercase)
                .tracking(0.4)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func accountMenu(
        selection: Binding<Account?>,
        excluding: Account?
    ) -> some View {
        Menu {
            ForEach(accounts.filter { $0.persistentModelID != excluding?.persistentModelID }, id: \.persistentModelID) { account in
                Button {
                    selection.wrappedValue = account
                } label: {
                    Text("\(account.name) · \(account.kind.displayName)")
                }
            }
        } label: {
            HStack(spacing: 8) {
                if let picked = selection.wrappedValue {
                    Dot(color: Color(hex: picked.colorHex), size: 8)
                    Text(picked.name)
                        .font(.system(size: 13))
                        .foregroundStyle(theme.text)
                    Text(picked.kind.displayName)
                        .font(.system(size: 11))
                        .foregroundStyle(theme.text3)
                } else {
                    Text("Pick an account…")
                        .font(.system(size: 13))
                        .foregroundStyle(theme.text3)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10))
                    .foregroundStyle(theme.text3)
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
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
    }

    private func inputField(text: Binding<String>, placeholder: String, trailing: String?) -> some View {
        HStack(spacing: 6) {
            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(theme.text)
                .multilineTextAlignment(.trailing)
            if let trailing {
                Text(trailing)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(theme.text3)
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

    private var totalReadout: some View {
        HStack(spacing: 6) {
            Text(totalReadoutText)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(theme.text2)
                .frame(maxWidth: .infinity, alignment: .trailing)
            Text(form.effectiveCurrency)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(theme.text3)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(theme.surface.opacity(0.6))
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .stroke(theme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 5))
    }

    private var totalReadoutText: String {
        guard let total = form.computedTotal else { return "—" }
        return Money(amount: total, currency: form.effectiveCurrency).formatted()
    }

    private func errorRow(_ err: AddTransactionForm.ValidationError) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12))
                .foregroundStyle(theme.red)
            Text(err.message)
                .font(.system(size: 12))
                .foregroundStyle(theme.red)
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(theme.redBg)
        .clipShape(RoundedRectangle(cornerRadius: 5))
    }

    // MARK: - FX lookup

    /// Latest cached rate for the pair, or nil if none yet. We don't go to
    /// the network — refresh is the coordinator's job. If the user picks a
    /// pair before the first refresh, the preview row says so and the save
    /// still works (only the visual estimate is missing).
    private func latestFXRate(from: String, to: String) -> Decimal? {
        if from == to { return 1 }
        let match = fxRates
            .filter { $0.from == from && $0.to == to }
            .max(by: { $0.asOf < $1.asOf })
        return match?.rate
    }

    // MARK: - Save

    private func save() {
        attemptedSave = true
        guard let txn = form.build() else { return }
        modelContext.insert(txn)
        do {
            try modelContext.save()
            dismiss()
        } catch {
            // Save errors are exceptionally rare for a single-row insert
            // (disk full, schema mismatch). Print for now; M11 will wire
            // a proper user-facing error path.
            FolioLog.persist.error("AddTransactionSheet save error: \(error.localizedDescription, privacy: .public)")
        }
    }
}
