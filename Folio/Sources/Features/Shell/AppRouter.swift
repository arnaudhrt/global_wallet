import Foundation
import Observation

/// App-wide navigation + sheet state. Created once at the `App` scene, injected via
/// `.environment(router)` (`@Observable`) so the `Commands` block can mutate
/// `selection` without going through NotificationCenter.
@Observable
final class AppRouter {
    var selection: Destination = .overview
    var showAddSheet: Bool = false
    var showSettingsSheet: Bool = false
    /// Set to `true` by the ⌘K shortcut to focus the toolbar search field.
    /// `ToolbarSearchField` reads + resets this via `@FocusState` syncing.
    var searchFocused: Bool = false
}
