import AppFeature
import AppKit
import BrowserEngine
import ComposableArchitecture
import SwiftUI

/// An AppKit window that hosts SwiftUI content. AppKit owns the window chrome
/// (title bar, traffic lights) and SwiftUI draws everything inside it.
@MainActor
final class BrowserWindowController: NSWindowController {
    init(store: StoreOf<AppFeature>, engine: any BrowserEngine) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1280, height: 800),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isReleasedWhenClosed = false
        window.setFrameAutosaveName("BrowserWindow")
        window.contentView = NSHostingView(rootView: BrowserWindowView(store: store, engine: engine))
        window.center()
        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }
}
