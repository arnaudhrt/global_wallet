import SwiftUI

/// Thin alias retained so SwiftUI previews keep working while the design system
/// is exercised in isolation. `FolioApp` no longer renders this — it renders
/// `MacShell` directly.
struct ContentView: View {
    var body: some View {
        DesignSystemPreview()
            .folioTheme()
    }
}

#Preview("Light") {
    ContentView()
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    ContentView()
        .preferredColorScheme(.dark)
}
