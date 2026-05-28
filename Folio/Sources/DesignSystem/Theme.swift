import SwiftUI
import SwiftData

struct FolioTheme: Equatable {
    let bg: Color
    let sidebarBg: Color
    let surface: Color
    let border: Color
    let borderStrong: Color
    let text: Color
    let text2: Color
    let text3: Color
    let blue: Color
    let green: Color
    let greenBg: Color
    let red: Color
    let redBg: Color
    let amber: Color
    let amberBg: Color
    let sp: Color
    let desktop: Color
    let rowHover: Color
    let cardBg: Color
    let sidebarSelectionBg: Color

    static let light = FolioTheme(
        bg:           Color(hex: 0xFFFFFF),
        sidebarBg:    Color(hex: 0xF5F5F7),
        surface:      Color(hex: 0xFAFAFB),
        border:       Color(hex: 0xE5E5EA),
        borderStrong: Color(hex: 0xD1D1D6),
        text:         Color(hex: 0x1D1D1F),
        text2:        Color(hex: 0x6E6E73),
        text3:        Color(hex: 0x8E8E93),
        blue:         Color(hex: 0x0066CC),
        green:        Color(hex: 0x00875A),
        greenBg:      Color(hex: 0xE6F4EE),
        red:          Color(hex: 0xC5392E),
        redBg:        Color(hex: 0xFBEAE8),
        amber:        Color(hex: 0xD97706),
        amberBg:      Color(hex: 0xFDF1E1),
        sp:           Color(hex: 0x2563EB),
        desktop:      Color(hex: 0xE4E4E7),
        rowHover:     Color(hex: 0xFAFAFB),
        cardBg:       Color(hex: 0xFFFFFF),
        sidebarSelectionBg: Color(hex: 0xD6D6D8)
    )

    static let dark = FolioTheme(
        bg:           Color(hex: 0x1C1C1E),
        sidebarBg:    Color(hex: 0x242427),
        surface:      Color(hex: 0x2C2C2F),
        border:       Color(hex: 0x3A3A3D),
        borderStrong: Color(hex: 0x48484B),
        text:         Color(hex: 0xF2F2F7),
        text2:        Color(hex: 0xAEAEB2),
        text3:        Color(hex: 0x8E8E93),
        blue:         Color(hex: 0x0A84FF),
        green:        Color(hex: 0x30D158),
        greenBg:      Color(hex: 0x30D158, opacity: 0.16),
        red:          Color(hex: 0xFF453A),
        redBg:        Color(hex: 0xFF453A, opacity: 0.16),
        amber:        Color(hex: 0xFF9F0A),
        amberBg:      Color(hex: 0xFF9F0A, opacity: 0.16),
        sp:           Color(hex: 0x5E9CFF),
        desktop:      Color(hex: 0x0F0F10),
        rowHover:     Color(hex: 0x2C2C2F),
        cardBg:       Color(hex: 0x242427),
        sidebarSelectionBg: Color(hex: 0x323132)
    )

    static func resolve(_ scheme: ColorScheme) -> FolioTheme {
        scheme == .dark ? .dark : .light
    }
}

// MARK: - Environment

private struct FolioThemeKey: EnvironmentKey {
    static let defaultValue: FolioTheme = .light
}

extension EnvironmentValues {
    var theme: FolioTheme {
        get { self[FolioThemeKey.self] }
        set { self[FolioThemeKey.self] = newValue }
    }
}

// MARK: - Provider

/// Resolves the active `FolioTheme` from system color scheme + `AppSettings.themeOverride`,
/// and applies `.preferredColorScheme` so macOS chrome (traffic lights, menus,
/// pickers) flips alongside our theme tokens when the user picks Light/Dark.
private struct FolioThemeProvider<Content: View>: View {
    @Environment(\.colorScheme) private var systemScheme
    @Query private var settings: [AppSettings]
    let content: Content

    private var override: ThemeOverride {
        settings.first?.themeOverrideEnum ?? .system
    }

    private var resolvedScheme: ColorScheme {
        switch override {
        case .system: return systemScheme
        case .light:  return .light
        case .dark:   return .dark
        }
    }

    /// `nil` = follow system. Passed to `.preferredColorScheme`.
    private var preferred: ColorScheme? {
        switch override {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }

    var body: some View {
        content
            .environment(\.theme, FolioTheme.resolve(resolvedScheme))
            .preferredColorScheme(preferred)
    }
}

extension View {
    /// Resolves `\.theme` from the current `\.colorScheme` and any
    /// `AppSettings.themeOverride`. Apply once near the root.
    func folioTheme() -> some View {
        FolioThemeProvider(content: self)
    }
}
