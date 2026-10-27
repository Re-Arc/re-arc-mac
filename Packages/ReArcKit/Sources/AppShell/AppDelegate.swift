import AppFeature
import AppKit
import BrowserEngine
import ComposableArchitecture

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = Store(initialState: AppFeature.State()) {
        AppFeature()
    }
    private let tabs = TabRegistry(engine: WebKitEngine())
    private var windowController: BrowserWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        tabs.onEvent = { [store, tabs] id, event in
            switch event {
            case let .pageStateChanged(page):
                store.send(.pageStateChanged(id, page))
            case let .newTabOpened(engineTab, url, inBackground):
                let tab = AppFeature.Tab(url: url ?? .blankPage, title: url?.host() ?? "New Tab")
                tabs.register(engineTab, for: tab.id)
                store.send(.tabOpenedByPage(tab, openerID: id, inBackground: inBackground))
            }
        }
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
        let controller = windowController ?? BrowserWindowController(store: store, tabs: tabs)
        windowController = controller
        controller.showWindow(nil)
    }
}
