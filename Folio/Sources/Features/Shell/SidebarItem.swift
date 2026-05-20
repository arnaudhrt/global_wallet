import SwiftUI

/// A single sidebar row matching `project/shell.jsx`. Three visual states:
/// active (blue fill, white text), inactive enabled (transparent, theme.text), and
/// disabled (dimmed, no hit target — used for v2 destinations in M2).
struct SidebarItem: View {
    @Environment(\.theme) private var theme

    let destination: Destination
    let isActive: Bool
    let isHovered: Bool
    let onSelect: () -> Void

    var body: some View {
        if destination.isAvailable {
            Button(action: onSelect) {
                row
                    .background(rowBackground)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        } else {
            row
                .opacity(0.45)
                .allowsHitTesting(false)
        }
    }

    private var row: some View {
        HStack(spacing: 8) {
            Image(systemName: destination.iconName)
                .font(.system(size: 13, weight: .regular))
                .frame(width: 16, height: 16)
                .foregroundStyle(iconColor)
            Text(destination.title)
                .font(.system(size: 13, weight: isActive ? .medium : .regular))
                .foregroundStyle(textColor)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .frame(height: 26)
        .padding(.horizontal, 8)
    }

    @ViewBuilder
    private var rowBackground: some View {
        if isActive {
            RoundedRectangle(cornerRadius: 5)
                .fill(theme.blue)
                .padding(.horizontal, 8)
        } else if isHovered {
            RoundedRectangle(cornerRadius: 5)
                .fill(Color.primary.opacity(0.06))
                .padding(.horizontal, 8)
        } else {
            Color.clear
        }
    }

    private var textColor: Color {
        isActive ? .white : theme.text
    }

    private var iconColor: Color {
        isActive ? .white : theme.text2
    }
}
