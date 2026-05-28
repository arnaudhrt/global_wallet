import Foundation
import OSLog

/// Centralized `os.Logger` instances per subsystem. Replaces M0-M9's ad-hoc
/// `print(...)` calls — visible via Console.app filtered on
/// `subsystem == "co.bff.folio"`, and stripped from Release builds by the
/// system signpost machinery without manual #if DEBUG fences.
enum FolioLog {
    private static let subsystem = "co.bff.folio"

    static let holdings = Logger(subsystem: subsystem, category: "holdings")
    static let quotes   = Logger(subsystem: subsystem, category: "quotes")
    static let history  = Logger(subsystem: subsystem, category: "history")
    static let persist  = Logger(subsystem: subsystem, category: "persist")
}
