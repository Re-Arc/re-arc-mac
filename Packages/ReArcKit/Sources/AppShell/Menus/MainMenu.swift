import AppKit
import ReArcFoundation

/// Builds the menu bar in code, since the app has no MainMenu nib.
@MainActor
enum MainMenu {
    static func make() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(submenuItem(appMenu()))
        menu.addItem(submenuItem(editMenu()))
        menu.addItem(submenuItem(viewMenu()))
        menu.addItem(submenuItem(tabsMenu()))
        menu.addItem(submenuItem(windowMenu()))
        return menu
    }

    private static func appMenu() -> NSMenu {
        let name = ProcessInfo.processInfo.processName
        let menu = NSMenu(title: name)
        menu.addItem(withTitle: "About \(name)", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Hide \(name)", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        menu.addItem(withTitle: "Quit \(name)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        return menu
    }

    // Web views need these responder actions for copy and paste to work.
    private static func editMenu() -> NSMenu {
        let menu = NSMenu(title: "Edit")
        menu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        menu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        menu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        menu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        menu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        return menu
    }

    // BrowserWindowController retitles the item to Show or Hide Sidebar.
    private static func viewMenu() -> NSMenu {
        let menu = NSMenu(title: "View")
        menu.addItem(item(for: .toggleSidebar))
        return menu
    }

    // Handled by the key window's BrowserWindowController, or by AppDelegate
    // when no browser window is open.
    private static func tabsMenu() -> NSMenu {
        let menu = NSMenu(title: "Tabs")
        for command in [AppCommand.newTab, .openLocation, .closeTab, .reopenClosedTab] {
            menu.addItem(item(for: command))
        }
        menu.addItem(.separator())
        for command in [AppCommand.selectNextTab, .selectPreviousTab] {
            menu.addItem(item(for: command))
        }
        return menu
    }

    static func item(for command: AppCommand) -> NSMenuItem {
        let item = NSMenuItem(
            title: command.title,
            action: #selector(BrowserWindowController.runAppCommand(_:)),
            keyEquivalent: command.shortcut?.keyEquivalent ?? ""
        )
        item.keyEquivalentModifierMask = command.shortcut?.modifierMask ?? []
        item.representedObject = command.rawValue
        return item
    }

    private static func windowMenu() -> NSMenu {
        let menu = NSMenu(title: "Window")
        menu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        // Cmd+W closes the tab, so closing the window takes Shift, as in Arc.
        menu.addItem(withTitle: "Close Window", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "W")
        NSApp.windowsMenu = menu
        return menu
    }

    private static func submenuItem(_ submenu: NSMenu) -> NSMenuItem {
        let item = NSMenuItem()
        item.submenu = submenu
        return item
    }
}
