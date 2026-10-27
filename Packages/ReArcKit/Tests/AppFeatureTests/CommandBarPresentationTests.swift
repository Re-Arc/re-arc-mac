import CommandBarFeature
import ComposableArchitecture
import Foundation
import ReArcFoundation
import Testing

@testable import AppFeature

@MainActor
struct CommandBarPresentationTests {
    let a = AppFeature.Tab(url: URL(string: "https://a.example")!, title: "A")
    let b = AppFeature.Tab(url: URL(string: "https://b.example")!, title: "B")

    var openTabs: [CommandBarFeature.OpenTab] {
        [a, b].map { CommandBarFeature.OpenTab(id: $0.id, title: $0.title, url: $0.url) }
    }

    @Test func newTabOpensAnEmptyBar() async {
        let store = TestStore(initialState: AppFeature.State(tabs: [a, b])) {
            AppFeature()
        }
        await store.send(.run(.newTab)) {
            $0.commandBar = CommandBarFeature.State(destination: .newTab, openTabs: openTabs)
        }
    }

    @Test func openLocationEditsTheCurrentURL() async {
        let store = TestStore(initialState: AppFeature.State(tabs: [a, b], selectedTabID: b.id)) {
            AppFeature()
        }
        await store.send(.run(.openLocation)) {
            $0.commandBar = CommandBarFeature.State(
                destination: .currentTab,
                query: "https://b.example",
                openTabs: openTabs,
                currentTabID: b.id
            )
        }
    }

    @Test func openLocationWithNoTabsOpensANewTab() async {
        let store = TestStore(initialState: AppFeature.State(tabs: [])) {
            AppFeature()
        }
        await store.send(.run(.openLocation)) {
            $0.commandBar = CommandBarFeature.State(destination: .newTab)
        }
    }

    @Test func openingInANewTabAddsAndSelectsIt() async {
        let store = TestStore(initialState: AppFeature.State(tabs: [a])) {
            AppFeature()
        } withDependencies: {
            $0.uuid = .incrementing
        }
        await store.send(.run(.newTab)) {
            $0.commandBar = CommandBarFeature.State(destination: .newTab, openTabs: [openTabs[0]])
        }
        await store.send(.commandBar(.presented(.queryChanged("swift.org")))) {
            $0.commandBar?.query = "swift.org"
            $0.commandBar?.suggestions = [
                .open(URL(string: "https://swift.org")!),
                .search("swift.org", .duckDuckGo),
            ]
        }
        await store.send(.commandBar(.presented(.submitted)))
        await store.receive(.commandBar(.presented(.delegate(.open(URL(string: "https://swift.org")!, in: .newTab))))) {
            let tab = AppFeature.Tab(id: UUID(0), url: URL(string: "https://swift.org")!, title: "swift.org")
            $0.commandBar = nil
            $0.tabs = [tab, a]
            $0.selectedTabID = tab.id
            $0.previouslySelectedTabID = a.id
        }
    }

    @Test func openingInTheCurrentTabLoadsIt() async {
        let loaded = LockIsolated<[(UUID, URL)]>([])
        var state = AppFeature.State(tabs: [a, b])
        state.commandBar = CommandBarFeature.State(destination: .currentTab, currentTabID: a.id)
        let store = TestStore(initialState: state) {
            AppFeature()
        } withDependencies: {
            $0.tabEngine.load = { id, url in loaded.withValue { $0.append((id, url)) } }
        }
        let url = URL(string: "https://swift.org")!
        await store.send(.commandBar(.presented(.delegate(.open(url, in: .currentTab))))) {
            $0.commandBar = nil
            $0.tabs[id: a.id]?.url = url
        }
        #expect(loaded.value.map(\.0) == [a.id])
        #expect(loaded.value.map(\.1) == [url])
    }

    @Test func openingInTheCurrentTabTargetsTheTabTheBarWasOpenedFor() async {
        let loaded = LockIsolated<[UUID]>([])
        var state = AppFeature.State(tabs: [a, b], selectedTabID: b.id)
        state.commandBar = CommandBarFeature.State(destination: .currentTab, currentTabID: a.id)
        let store = TestStore(initialState: state) {
            AppFeature()
        } withDependencies: {
            $0.tabEngine.load = { id, _ in loaded.withValue { $0.append(id) } }
        }
        let url = URL(string: "https://swift.org")!
        await store.send(.commandBar(.presented(.delegate(.open(url, in: .currentTab))))) {
            $0.commandBar = nil
            $0.tabs[id: a.id]?.url = url
        }
        #expect(loaded.value == [a.id])
    }

    @Test func openingInAClosedTabOpensANewOne() async {
        var state = AppFeature.State(tabs: [b])
        state.commandBar = CommandBarFeature.State(destination: .currentTab, currentTabID: a.id)
        let store = TestStore(initialState: state) {
            AppFeature()
        } withDependencies: {
            $0.uuid = .incrementing
        }
        let url = URL(string: "https://swift.org")!
        await store.send(.commandBar(.presented(.delegate(.open(url, in: .currentTab))))) {
            let tab = AppFeature.Tab(id: UUID(0), url: url, title: "swift.org")
            $0.commandBar = nil
            $0.tabs = [tab, b]
            $0.selectedTabID = tab.id
            $0.previouslySelectedTabID = b.id
        }
    }

    @Test func escapeDismissesThroughTheParent() async {
        let store = TestStore(initialState: AppFeature.State(tabs: [a])) {
            AppFeature()
        }
        await store.send(.run(.newTab)) {
            $0.commandBar = CommandBarFeature.State(destination: .newTab, openTabs: [openTabs[0]])
        }
        await store.send(.commandBar(.presented(.cancelled)))
        await store.receive(.commandBar(.dismiss)) {
            $0.commandBar = nil
        }
    }

    @Test func choosingASearchEngineThroughTheParentClosesTheBar() async {
        let store = TestStore(initialState: AppFeature.State(tabs: [a])) {
            AppFeature()
        }
        await store.send(.run(.newTab)) {
            $0.commandBar = CommandBarFeature.State(destination: .newTab, openTabs: [openTabs[0]])
        }
        await store.send(.commandBar(.presented(.suggestionClicked(.useSearchEngine(.kagi))))) {
            $0.commandBar?.$searchEngine.withLock { $0 = .kagi }
        }
        await store.receive(.commandBar(.dismiss)) {
            $0.commandBar = nil
        }
        #expect(CommandBarFeature.State(destination: .newTab).searchEngine == .kagi)
    }

    @Test func switchingToATabSelectsIt() async {
        var state = AppFeature.State(tabs: [a, b])
        state.commandBar = CommandBarFeature.State(destination: .newTab, query: "b", openTabs: openTabs)
        let store = TestStore(initialState: state) {
            AppFeature()
        }
        await store.send(.commandBar(.presented(.delegate(.switchToTab(b.id))))) {
            $0.commandBar = nil
            $0.selectedTabID = b.id
            $0.previouslySelectedTabID = a.id
        }
    }

    @Test func runningACommandFromTheBarClosesItFirst() async {
        var state = AppFeature.State(tabs: [a, b])
        state.commandBar = CommandBarFeature.State(destination: .newTab, query: "next")
        let store = TestStore(initialState: state) {
            AppFeature()
        }
        await store.send(.commandBar(.presented(.delegate(.run(.selectNextTab))))) {
            $0.commandBar = nil
            $0.selectedTabID = b.id
            $0.previouslySelectedTabID = a.id
        }
    }

    @Test func menuCommandsRunTabActions() async {
        let store = TestStore(initialState: AppFeature.State(tabs: [a, b])) {
            AppFeature()
        } withDependencies: {
            $0.tabEngine.unload = { _ in }
        }
        await store.send(.run(.closeTab)) {
            $0.tabs = [b]
            $0.recentlyClosed = [AppFeature.ClosedTab(url: a.url, title: "A", index: 0)]
            $0.selectedTabID = b.id
            $0.previouslySelectedTabID = a.id
        }
    }

    @Test func commandsMapToTabActions() async {
        let store = TestStore(initialState: AppFeature.State(tabs: [a, b])) {
            AppFeature()
        } withDependencies: {
            $0.uuid = .incrementing
            $0.tabEngine.unload = { _ in }
        }
        await store.send(.run(.selectPreviousTab)) {
            $0.selectedTabID = b.id
            $0.previouslySelectedTabID = a.id
        }
        await store.send(.run(.closeTab)) {
            $0.tabs = [a]
            $0.recentlyClosed = [AppFeature.ClosedTab(url: b.url, title: "B", index: 1)]
            $0.selectedTabID = a.id
            $0.previouslySelectedTabID = b.id
        }
        await store.send(.run(.reopenClosedTab)) {
            let reopened = AppFeature.Tab(id: UUID(0), url: b.url, title: "B")
            $0.tabs = [a, reopened]
            $0.recentlyClosed = []
            $0.selectedTabID = reopened.id
            $0.previouslySelectedTabID = a.id
        }
        await store.send(.run(.toggleSidebar)) {
            $0.isSidebarVisible = false
        }
    }

    @Test func canRunReflectsState() {
        var state = AppFeature.State(tabs: [a])
        #expect(state.canRun(.newTab))
        #expect(state.canRun(.closeTab))
        #expect(!state.canRun(.reopenClosedTab))
        #expect(!state.canRun(.selectNextTab))
        state.recentlyClosed = [AppFeature.ClosedTab(url: b.url, title: "B", index: 1)]
        #expect(state.canRun(.reopenClosedTab))
        state.tabs = []
        state.selectedTabID = nil
        #expect(!state.canRun(.closeTab))
        #expect(state.canRun(.openLocation))
    }
}
