import SwiftUI

/// Compact toolbar pill: colored dot + "Updated 2m ago" / "Refreshing…" /
/// "Offline". Reads `QuoteRefreshCoordinator` from `@Environment`. Click or
/// ⌘R triggers a manual refresh.
///
/// Dot colors:
/// - `.refreshing` / `.idle` → neutral `text3`
/// - `.ok` ≤ 30 min → `theme.green`
/// - `.ok` > 30 min, `.stale`   → `theme.amber`
/// - `.failed` → `theme.red`
struct ToolbarRefreshStatus: View {
    @Environment(\.theme) private var theme
    @Environment(QuoteRefreshCoordinator.self) private var coordinator
    @State private var now = Date()

    private let staleAfter: TimeInterval = 30 * 60
    private let tick = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var body: some View {
        Button {
            Task { await coordinator.refreshAll() }
        } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(dotColor)
                    .frame(width: 8, height: 8)
                Text(label)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(theme.text2)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(theme.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(theme.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
        .help("Refresh quotes (⌘R)")
        .onReceive(tick) { now = $0 }
    }

    private var dotColor: Color {
        switch coordinator.status {
        case .idle, .refreshing:
            return theme.text3
        case .ok(let at):
            return now.timeIntervalSince(at) > staleAfter ? theme.amber : theme.green
        case .stale:
            return theme.amber
        case .failed:
            return theme.red
        }
    }

    private var label: String {
        switch coordinator.status {
        case .idle:
            return "Not refreshed"
        case .refreshing:
            return "Refreshing…"
        case .ok(let at), .stale(let at):
            return "Updated \(relative(from: at))"
        case .failed:
            return "Offline"
        }
    }

    private func relative(from date: Date) -> String {
        let seconds = Int(max(0, now.timeIntervalSince(date)))
        if seconds < 60        { return "just now" }
        if seconds < 60 * 60   { return "\(seconds / 60)m ago" }
        if seconds < 60 * 60 * 24 { return "\(seconds / 3600)h ago" }
        return "\(seconds / 86400)d ago"
    }
}
