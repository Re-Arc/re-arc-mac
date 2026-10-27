import AppFeature
import ComposableArchitecture
import Foundation
import ReArcFoundation
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

    @Test func pageStateUpdatesTab() async {
        let store = TestStore(initialState: AppFeature.State(tabs: [first, second])) {
            AppFeature()
        }
        let page = PageState(
            url: URL(string: "https://example.com/docs")!,
            title: "Docs",
            isLoading: true,
            estimatedProgress: 0.4,
            canGoBack: true,
            canGoForward: false,
            faviconURL: URL(string: "https://example.com/icon.png")!
        )
        await store.send(.pageStateChanged(first.id, page)) {
            $0.tabs[id: first.id]?.url = page.url!
            $0.tabs[id: first.id]?.title = "Docs"
            $0.tabs[id: first.id]?.isLoading = true
            $0.tabs[id: first.id]?.estimatedProgress = 0.4
            $0.tabs[id: first.id]?.canGoBack = true
            $0.tabs[id: first.id]?.faviconURL = page.faviconURL
        }
    }

    @Test func untitledPageShowsHost() async {
        let store = TestStore(initialState: AppFeature.State(tabs: [first])) {
            AppFeature()
        }
        let page = PageState(url: URL(string: "https://swift.org/blog")!, title: "")
        await store.send(.pageStateChanged(first.id, page)) {
            $0.tabs[id: first.id]?.url = page.url!
            $0.tabs[id: first.id]?.title = "swift.org"
        }
    }

    @Test func pageStateKeepsURLWhenEngineHasNone() async {
        let store = TestStore(initialState: AppFeature.State(tabs: [first])) {
            AppFeature()
        }
        await store.send(.pageStateChanged(first.id, PageState(isLoading: true))) {
            $0.tabs[id: first.id]?.isLoading = true
        }
    }

    @Test func pageStateForUnknownTabIsIgnored() async {
        let store = TestStore(initialState: AppFeature.State(tabs: [first])) {
            AppFeature()
        }
        await store.send(.pageStateChanged(UUID(), PageState(title: "Lost")))
    }
}
