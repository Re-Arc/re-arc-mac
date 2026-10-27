import AppFeature
import AppKit
import BrowserEngine
import ComposableArchitecture

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = Store(initialState: AppFeature.State()) {
        AppFeature()
    }
    private let engine: any BrowserEngine = WebKitEngine()
    private var windowController: BrowserWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = MainMenu.make()
        showBrowserWindow()
        NSApp.activate()
    }

    // Browsers stay running with no windows open, like Arc and Safari.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        if !hasVisibleWindows {
            showBrowserWindow()
        }
        return true
    }

    private func showBrowserWindow() {
        let controller = windowController ?? BrowserWindowController(store: store, engine: engine)
        windowController = controller
        controller.showWindow(nil)
    }
}
