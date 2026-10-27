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
            store.send(backwards ? .selectPreviousTab : .selectNextTab)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    @objc func newTab(_ sender: Any?) {
        store.send(.newTab(.startPage))
    }

    @objc func closeTab(_ sender: Any?) {
        guard let id = store.selectedTabID else { return }
        store.send(.closeTab(id))
    }

    @objc func reopenClosedTab(_ sender: Any?) {
        store.send(.reopenClosedTab)
    }

    // Not named toggleSidebar(_:): SwiftUI's hosting view answers that
    // selector itself and sits ahead of this controller in the responder chain.
    @objc func toggleBrowserSidebar(_ sender: Any?) {
        store.send(.toggleSidebar)
    }

    @objc func selectNextBrowserTab(_ sender: Any?) {
        store.send(.selectNextTab)
    }

    @objc func selectPreviousBrowserTab(_ sender: Any?) {
        store.send(.selectPreviousTab)
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(toggleBrowserSidebar(_:)) {
            menuItem.title = store.isSidebarVisible ? "Hide Sidebar" : "Show Sidebar"
        }
        return switch menuItem.action {
        case #selector(closeTab(_:)):
            store.selectedTabID != nil
        case #selector(reopenClosedTab(_:)):
            !store.recentlyClosed.isEmpty
        case #selector(selectNextBrowserTab(_:)), #selector(selectPreviousBrowserTab(_:)):
            store.tabs.count > 1
        default:
            true
        }
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
