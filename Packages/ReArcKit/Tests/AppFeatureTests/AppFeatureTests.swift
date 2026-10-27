import AppFeature
import ComposableArchitecture
import Foundation
import Testing

@MainActor
struct AppFeatureTests {
    let first = AppFeature.Tab(url: URL(string: "https://example.com")!, title: "First")
    let second = AppFeature.Tab(url: URL(string: "https://example.org")!, title: "Second")

    @Test func selectsFirstTabByDefault() {
        let state = AppFeature.State(tabs: [first, second])
        #expect(state.selectedTabID == first.id)
    }

    @Test func selectingTabUpdatesSelection() async {
        let store = TestStore(initialState: AppFeature.State(tabs: [first, second])) {
            AppFeature()
        }
        await store.send(.tabSelected(second.id)) {
            $0.selectedTabID = second.id
        }
    }

    @Test func selectingUnknownTabIsIgnored() async {
        let store = TestStore(initialState: AppFeature.State(tabs: [first])) {
            AppFeature()
        }
        await store.send(.tabSelected(UUID()))
    }
}
