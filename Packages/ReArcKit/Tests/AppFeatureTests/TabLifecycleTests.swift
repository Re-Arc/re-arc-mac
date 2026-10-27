import ComposableArchitecture
import Foundation
import Testing

@testable import AppFeature

@MainActor
struct TabLifecycleTests {
    let a = AppFeature.Tab(url: URL(string: "https://a.example")!, title: "A")
    let b = AppFeature.Tab(url: URL(string: "https://b.example")!, title: "B")
    let c = AppFeature.Tab(url: URL(string: "https://c.example")!, title: "C")

    @Test func newTabGoesOnTopAndIsSelected() async {
        let store = TestStore(initialState: AppFeature.State(tabs: [a, b])) {
            AppFeature()
        } withDependencies: {
            $0.uuid = .incrementing
        }
        let url = URL(string: "https://swift.org")!
        await store.send(.newTab(url)) {
            let tab = AppFeature.Tab(id: UUID(0), url: url, title: "swift.org")
            $0.tabs = [tab, a, b]
            $0.selectedTabID = tab.id
            $0.previouslySelectedTabID = a.id
        }
    }

    @Test func closingSelectedTabReturnsToPreviousSelection() async {
        let unloaded = LockIsolated<[UUID]>([])
        let store = TestStore(initialState: AppFeature.State(tabs: [a, b, c], selectedTabID: c.id)) {
            AppFeature()
        } withDependencies: {
            $0.tabEngine.unload = { id in unloaded.withValue { $0.append(id) } }
        }
        await store.send(.tabSelected(a.id)) {
            $0.selectedTabID = a.id
            $0.previouslySelectedTabID = c.id
        }
        await store.send(.closeTab(a.id)) {
            $0.tabs = [b, c]
            $0.recentlyClosed = [AppFeature.ClosedTab(url: a.url, title: "A", index: 0)]
            $0.selectedTabID = c.id
            $0.previouslySelectedTabID = a.id
        }
        #expect(unloaded.value == [a.id])
    }

    @Test func closingSelectedTabSelectsTheTabBelowThenAbove() async {
        let store = TestStore(initialState: AppFeature.State(tabs: [a, b, c], selectedTabID: b.id)) {
            AppFeature()
        } withDependencies: {
            $0.tabEngine.unload = { _ in }
        }
        await store.send(.closeTab(b.id)) {
            $0.tabs = [a, c]
            $0.recentlyClosed = [AppFeature.ClosedTab(url: b.url, title: "B", index: 1)]
            $0.selectedTabID = c.id
            $0.previouslySelectedTabID = b.id
        }
        // b is gone, so the previous selection doesn't apply; c was last, so go up.
        await store.send(.closeTab(c.id)) {
            $0.tabs = [a]
            $0.recentlyClosed.insert(AppFeature.ClosedTab(url: c.url, title: "C", index: 1), at: 0)
            $0.selectedTabID = a.id
            $0.previouslySelectedTabID = c.id
        }
    }

    @Test func closingUnselectedTabKeepsSelection() async {
        let store = TestStore(initialState: AppFeature.State(tabs: [a, b])) {
            AppFeature()
        } withDependencies: {
            $0.tabEngine.unload = { _ in }
        }
        await store.send(.closeTab(b.id)) {
            $0.tabs = [a]
            $0.recentlyClosed = [AppFeature.ClosedTab(url: b.url, title: "B", index: 1)]
        }
    }

    @Test func closingLastTabLeavesNoSelection() async {
        let store = TestStore(initialState: AppFeature.State(tabs: [a])) {
            AppFeature()
        } withDependencies: {
            $0.tabEngine.unload = { _ in }
        }
        await store.send(.closeTab(a.id)) {
            $0.tabs = []
            $0.recentlyClosed = [AppFeature.ClosedTab(url: a.url, title: "A", index: 0)]
            $0.selectedTabID = nil
            $0.previouslySelectedTabID = a.id
        }
    }

    @Test func reopenRestoresMostRecentAtItsPosition() async {
        let store = TestStore(initialState: AppFeature.State(tabs: [a, b, c])) {
            AppFeature()
        } withDependencies: {
            $0.uuid = .incrementing
            $0.tabEngine.unload = { _ in }
        }
        store.exhaustivity = .off
        await store.send(.closeTab(b.id))
        await store.send(.closeTab(c.id))
        store.exhaustivity = .on
        await store.send(.reopenClosedTab) {
            let reopened = AppFeature.Tab(id: UUID(0), url: c.url, title: "C")
            $0.tabs = [a, reopened]
            $0.recentlyClosed = [AppFeature.ClosedTab(url: b.url, title: "B", index: 1)]
            $0.selectedTabID = reopened.id
            $0.previouslySelectedTabID = a.id
        }
        await store.send(.reopenClosedTab) {
            let reopened = AppFeature.Tab(id: UUID(1), url: b.url, title: "B")
            $0.tabs = [a, reopened, AppFeature.Tab(id: UUID(0), url: c.url, title: "C")]
            $0.recentlyClosed = []
            $0.selectedTabID = reopened.id
            $0.previouslySelectedTabID = UUID(0)
        }
        await store.send(.reopenClosedTab)
    }

    @Test func recentlyClosedIsBounded() async {
        let tabs = (0..<30).map { AppFeature.Tab(url: URL(string: "https://\($0).example")!, title: "\($0)") }
        let store = TestStore(initialState: AppFeature.State(tabs: IdentifiedArray(uniqueElements: tabs))) {
            AppFeature()
        } withDependencies: {
            $0.tabEngine.unload = { _ in }
        }
        store.exhaustivity = .off
        for tab in tabs {
            await store.send(.closeTab(tab.id))
        }
        #expect(store.state.recentlyClosed.count == 25)
        #expect(store.state.recentlyClosed.first?.title == "29")
    }

    @Test func nextAndPreviousWrapAround() async {
        let store = TestStore(initialState: AppFeature.State(tabs: [a, b, c], selectedTabID: c.id)) {
            AppFeature()
        }
        await store.send(.selectNextTab) {
            $0.selectedTabID = a.id
            $0.previouslySelectedTabID = c.id
        }
        await store.send(.selectPreviousTab) {
            $0.selectedTabID = c.id
            $0.previouslySelectedTabID = a.id
        }
        await store.send(.selectPreviousTab) {
            $0.selectedTabID = b.id
            $0.previouslySelectedTabID = c.id
        }
    }

    @Test func nextTabWithNoTabsDoesNothing() async {
        let store = TestStore(initialState: AppFeature.State(tabs: [])) {
            AppFeature()
        }
        await store.send(.selectNextTab)
    }

    @Test func reopenClampsPositionToTheEndOfTheList() async {
        let store = TestStore(initialState: AppFeature.State(tabs: [a, b, c])) {
            AppFeature()
        } withDependencies: {
            $0.uuid = .incrementing
            $0.tabEngine.unload = { _ in }
        }
        store.exhaustivity = .off
        await store.send(.closeTab(c.id))
        await store.send(.closeTab(a.id))
        await store.send(.reopenClosedTab)
        store.exhaustivity = .on
        // c was at index 2, but only two tabs are open now, so it goes last.
        await store.send(.reopenClosedTab) {
            let reopenedA = AppFeature.Tab(id: UUID(0), url: a.url, title: "A")
            let reopenedC = AppFeature.Tab(id: UUID(1), url: c.url, title: "C")
            $0.tabs = [reopenedA, b, reopenedC]
            $0.recentlyClosed = []
            $0.selectedTabID = reopenedC.id
            $0.previouslySelectedTabID = reopenedA.id
        }
    }

    @Test func closingUnknownTabDoesNothing() async {
        // The default unload is unimplemented, so calling it would fail the test.
        let store = TestStore(initialState: AppFeature.State(tabs: [a])) {
            AppFeature()
        }
        await store.send(.closeTab(UUID()))
    }

    @Test func nextAndPreviousWithNoSelectionPickFirstAndLast() async {
        var state = AppFeature.State(tabs: [a, b, c])
        state.selectedTabID = nil
        let store = TestStore(initialState: state) {
            AppFeature()
        }
        await store.send(.selectNextTab) {
            $0.selectedTabID = a.id
        }
        state.selectedTabID = nil
        let backwards = TestStore(initialState: state) {
            AppFeature()
        }
        await backwards.send(.selectPreviousTab) {
            $0.selectedTabID = c.id
        }
    }

    @Test func closingAPopupReturnsToItsOpener() async {
        let store = TestStore(initialState: AppFeature.State(tabs: [a, b])) {
            AppFeature()
        } withDependencies: {
            $0.tabEngine.unload = { _ in }
        }
        await store.send(.tabSelected(b.id)) {
            $0.selectedTabID = b.id
            $0.previouslySelectedTabID = a.id
        }
        let popup = AppFeature.Tab(url: URL(string: "https://login.example")!, title: "Login")
        await store.send(.tabOpenedByPage(popup, openerID: b.id, inBackground: false)) {
            $0.tabs = [a, b, popup]
            $0.selectedTabID = popup.id
            $0.previouslySelectedTabID = b.id
        }
        await store.send(.closeTab(popup.id)) {
            $0.tabs = [a, b]
            $0.recentlyClosed = [AppFeature.ClosedTab(url: popup.url, title: "Login", index: 2)]
            $0.selectedTabID = b.id
            $0.previouslySelectedTabID = popup.id
        }
    }

    @Test func startPageTabsShareOneTitle() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.uuid = .incrementing
        }
        store.exhaustivity = .off
        await store.send(.newTab(.startPage))
        #expect(store.state.tabs.map(\.title) == [AppFeature.Tab.startPageTitle, AppFeature.Tab.startPageTitle])
    }
}
