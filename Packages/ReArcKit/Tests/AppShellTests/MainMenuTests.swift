import AppKit
import ReArcFoundation
import Testing

@testable import AppShell

@MainActor
struct MainMenuTests {
    @Test func menuItemsCarryTheirCommandAndShortcut() {
        let reopen = MainMenu.item(for: .reopenClosedTab)
        #expect(reopen.title == "Reopen Closed Tab")
        #expect(reopen.keyEquivalent == "t")
        #expect(reopen.keyEquivalentModifierMask == [.command, .shift])
        #expect(reopen.appCommand == .reopenClosedTab)
        #expect(reopen.action == #selector(BrowserWindowController.runAppCommand(_:)))
    }

    @Test func arrowShortcutsUseFunctionKeys() {
        let next = MainMenu.item(for: .selectNextTab)
        #expect(next.keyEquivalent == String(Character(UnicodeScalar(UInt16(NSDownArrowFunctionKey))!)))
        #expect(next.keyEquivalentModifierMask == [.command, .option])
    }

    @Test func everyCommandBuildsAMenuItem() {
        for command in AppCommand.allCases {
            #expect(MainMenu.item(for: command).appCommand == command)
        }
    }
}
