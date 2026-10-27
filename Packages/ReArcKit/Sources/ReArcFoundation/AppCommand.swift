import Foundation

/// Commands the user can run from the menu bar or the command bar. Both read
/// this list, so a command's title and shortcut are defined once.
public enum AppCommand: String, CaseIterable, Sendable {
    case newTab
    case openLocation
    case closeTab
    case reopenClosedTab
    case selectNextTab
    case selectPreviousTab
    case toggleSidebar

    public var title: String {
        switch self {
        case .newTab: "New Tab"
        case .openLocation: "Open Location"
        case .closeTab: "Close Tab"
        case .reopenClosedTab: "Reopen Closed Tab"
        case .selectNextTab: "Next Tab"
        case .selectPreviousTab: "Previous Tab"
        case .toggleSidebar: "Toggle Sidebar"
        }
    }

    public var shortcut: KeyShortcut? {
        switch self {
        case .newTab: KeyShortcut(.character("t"), [.command])
        case .openLocation: KeyShortcut(.character("l"), [.command])
        case .closeTab: KeyShortcut(.character("w"), [.command])
        case .reopenClosedTab: KeyShortcut(.character("t"), [.command, .shift])
        case .selectNextTab: KeyShortcut(.downArrow, [.command, .option])
        case .selectPreviousTab: KeyShortcut(.upArrow, [.command, .option])
        case .toggleSidebar: KeyShortcut(.character("s"), [.command])
        }
    }

    /// Commands that only reopen the command bar aren't offered inside it.
    public var showsInCommandBar: Bool {
        switch self {
        case .newTab, .openLocation: false
        default: true
        }
    }
}
