import ReArcFoundation
import Testing

struct AppCommandTests {
    @Test func shortcutsAreUnique() {
        let shortcuts = AppCommand.allCases.compactMap(\.shortcut)
        #expect(Set(shortcuts).count == shortcuts.count)
    }

    @Test func showsShortcutsTheWayMenusDo() {
        #expect(AppCommand.reopenClosedTab.shortcut?.displayString == "⇧⌘T")
        #expect(AppCommand.selectNextTab.shortcut?.displayString == "⌥⌘↓")
    }
}
