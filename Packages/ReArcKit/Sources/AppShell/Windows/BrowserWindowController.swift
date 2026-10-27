import AppFeature
import AppKit
import ComposableArchitecture
import SwiftUI

/// An AppKit window that hosts SwiftUI content. AppKit owns the window chrome
/// (title bar, traffic lights) and SwiftUI draws everything inside it.
///
/// It sits in the responder chain after its window, so menu commands for the
/// key window arrive here and are sent to the store.
@MainActor
final class BrowserWindowController: NSWindowController, NSMenuItemValidation {
    private let store: StoreOf<AppFeature>

    init(store: StoreOf<AppFeature>, tabs: TabRegistry) {
        self.store = store
        let window = BrowserWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1280, height: 800),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        // Native window tabs would compete with browser tabs for the same shortcuts.
        window.tabbingMode = .disallowed
        window.isReleasedWhenClosed = false
        window.setFrameAutosaveName("BrowserWindow")
        window.contentView = NSHostingView(rootView: BrowserWindowView(store: store, tabs: tabs))
        window.center()
        super.init(window: window)
        window.onControlTab = { [store] backwards in
            store.send(.run(backwards ? .selectPreviousTab : .selectNextTab))
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    @objc func runAppCommand(_ sender: NSMenuItem) {
        guard let command = sender.appCommand else { return }
        store.send(.run(command))
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        guard menuItem.action == #selector(runAppCommand(_:)), let command = menuItem.appCommand else {
            return true
        }
        if command == .toggleSidebar {
            menuItem.title = store.isSidebarVisible ? "Hide Sidebar" : "Show Sidebar"
        }
        return store.withState { $0.canRun(command) }
    }
}

/// Catches Ctrl+Tab before the focused view uses it to move between controls.
private final class BrowserWindow: NSWindow {
    /// Called with `true` for Ctrl+Shift+Tab.
    var onControlTab: ((_ backwards: Bool) -> Void)?

    override func sendEvent(_ event: NSEvent) {
        // Ignore Caps Lock and the like; only these modifiers change the meaning.
        let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
        if event.type == .keyDown, event.keyCode == Self.tabKeyCode,
            flags == .control || flags == [.control, .shift], let onControlTab
        {
            onControlTab(flags.contains(.shift))
            return
        }
        super.sendEvent(event)
    }

    private static let tabKeyCode: UInt16 = 48
}
