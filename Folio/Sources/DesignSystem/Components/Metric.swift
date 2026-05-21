import SwiftUI

enum FolioTone {
    case neutral, positive, negative
}

struct MetricBadge {
    let text: String
    let tone: FolioTone
}

struct Metric: View {
    @Environment(\.theme) private var theme

    let label: String
    let value: String
    var sub: String? = nil
    var subTone: FolioTone = .neutral
    var badge: MetricBadge? = nil

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 0) {
                Text(label.uppercased())
                    .font(.system(size: 11, weight: .medium))
                    .tracking(0.4)
                    .foregroundStyle(theme.text3)

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(value)
                        .font(.system(size: 24, weight: .semibold, design: .monospaced))
                        .monospacedDigit()
                        .tracking(-0.3)
                        .foregroundStyle(theme.text)

                    if let badge = badge {
                        Text(badge.text)
                            .font(.system(size: 11, weight: .semibold))
                            .monospacedDigit()
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(badgeBackground(for: badge.tone))
                            .foregroundStyle(badgeForeground(for: badge.tone))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
                .padding(.top, 10)

                if let sub = sub {
                    Text(sub)
                        .font(.system(size: 12, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(subColor(for: subTone))
                        .padding(.top, 8)
                }
            }
        }
    }

    private func subColor(for tone: FolioTone) -> Color {
        switch tone {
        case .positive: return theme.green
        case .negative: return theme.red
        case .neutral:  return theme.text2
        }
    }

    private func badgeForeground(for tone: FolioTone) -> Color {
        switch tone {
        case .positive: return theme.green
        case .negative: return theme.red
        case .neutral:  return theme.text2
        }
    }

    private func badgeBackground(for tone: FolioTone) -> Color {
        switch tone {
        case .positive: return theme.greenBg
        case .negative: return theme.redBg
        case .neutral:  return theme.surface
        }
    }
}
