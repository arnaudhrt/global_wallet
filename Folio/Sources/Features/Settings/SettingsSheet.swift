import SwiftUI
import SwiftData
import AppKit

/// M10 — Themed Settings sheet (sheet-over-MacShell, not a `Settings { ... }` scene).
///
/// Three sections:
/// - **General**: base currency picker (curated 8: USD/EUR/GBP/JPY/CHF/CAD/AUD/BRL).
/// - **Appearance**: theme override (System / Light / Dark).
/// - **Data**: reveal SwiftData store folder in Finder.
///
/// Cost-basis is shown read-only ("Weighted average — FIFO/LIFO in v2") per the
/// ROADMAP's locked decision for MVP.
struct SettingsSheet: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(QuoteRefreshCoordinator.self) private var coordinator

    @Query private var settings: [AppSettings]

    static let supportedCurrencies: [String] = [
        "USD", "EUR", "GBP", "JPY", "CHF", "CAD", "AUD", "BRL",
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().opacity(0.6)
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 20) {
                    generalSection
                    appearanceSection
                    dataSection
                }
                .padding(20)
            }
            Divider().opacity(0.6)
            footer
        }
        .frame(width: 520, height: 420)
        .background(theme.bg)
    }

    // MARK: - Header / footer

    private var header: some View {
        HStack {
            Text("Settings")
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
            Button("Done") { dismiss() }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    // MARK: - Sections

    private var generalSection: some View {
        section(title: "General") {
            row(label: "Base currency") {
                Picker("", selection: baseCurrencyBinding) {
                    ForEach(Self.supportedCurrencies, id: \.self) { code in
                        Text(code).tag(code)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 120)
            }
            row(label: "Cost basis") {
                Text("Weighted average")
                    .font(.system(size: 13))
                    .foregroundStyle(theme.text)
                Text("FIFO/LIFO in v2")
                    .font(.system(size: 11))
                    .foregroundStyle(theme.text3)
            }
        }
    }

    private var appearanceSection: some View {
        section(title: "Appearance") {
            row(label: "Theme") {
                Picker("", selection: themeOverrideBinding) {
                    ForEach(ThemeOverride.allCases, id: \.self) { override in
                        Text(override.displayName).tag(override)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 220)
            }
        }
    }

    private var dataSection: some View {
        section(title: "Data") {
            row(label: "Local database") {
                Button {
                    revealDataFolder()
                } label: {
                    Text("Reveal in Finder…")
                        .font(.system(size: 12))
                }
                .buttonStyle(.bordered)
            }
        }
    }

    // MARK: - Section / row primitives

    private func section<Content: View>(
        title: String,
        @ViewBuilder _ content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(theme.text3)
                .textCase(.uppercase)
                .tracking(0.4)
            VStack(alignment: .leading, spacing: 8) {
                content()
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(theme.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }

    private func row<Content: View>(
        label: String,
        @ViewBuilder _ content: () -> Content
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(theme.text)
                .frame(width: 140, alignment: .leading)
            content()
            Spacer(minLength: 0)
        }
        .frame(minHeight: 28)
    }

    // MARK: - Bindings

    private var baseCurrencyBinding: Binding<String> {
        Binding(
            get: { settings.first?.baseCurrency ?? "USD" },
            set: { newValue in
                guard let row = settings.first else { return }
                guard row.baseCurrency != newValue else { return }
                row.baseCurrency = newValue
                try? modelContext.save()
                // Refresh quotes so any FX pairs introduced by the new base
                // currency land before the user navigates back to a screen.
                Task { await coordinator.refreshAll() }
            }
        )
    }

    private var themeOverrideBinding: Binding<ThemeOverride> {
        Binding(
            get: { settings.first?.themeOverrideEnum ?? .system },
            set: { newValue in
                guard let row = settings.first else { return }
                guard row.themeOverrideEnum != newValue else { return }
                row.themeOverrideEnum = newValue
                try? modelContext.save()
            }
        )
    }

    // MARK: - Data folder

    private func revealDataFolder() {
        // ModelContainer's configurations expose the on-disk store URL. The
        // file may not exist yet on a brand-new install, so reveal the parent
        // directory if the .store itself isn't there.
        guard let url = modelContext.container.configurations.first?.url else { return }
        if FileManager.default.fileExists(atPath: url.path) {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } else {
            NSWorkspace.shared.activateFileViewerSelecting([url.deletingLastPathComponent()])
        }
    }
}
