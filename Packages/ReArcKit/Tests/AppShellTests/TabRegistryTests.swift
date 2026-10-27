import AppFeature
import AppKit
import BrowserEngine
import Foundation
import ReArcFoundation
import Testing

@testable import AppShell

@MainActor
struct TabRegistryTests {
    let tab = AppFeature.Tab(url: URL(string: "https://example.com")!, title: "Example")

    @Test func reusesThePageForATab() {
        let engine = FakeEngine()
        let registry = TabRegistry(engine: engine)
        let first = registry.engineTab(for: tab)
        let second = registry.engineTab(for: tab)
        #expect(first === second)
        #expect(engine.madeTabs.count == 1)
        #expect(engine.madeTabs.first?.loadedURLs == [tab.url])
    }

    @Test func tagsEventsWithTheirTab() {
        let registry = TabRegistry(engine: FakeEngine())
        var received: [(AppFeature.Tab.ID, PageState)] = []
        registry.onEvent = { id, event in
            if case let .pageStateChanged(page) = event {
                received.append((id, page))
            }
        }
        let engineTab = registry.engineTab(for: tab) as! FakeTab
        engineTab.onEvent?(.pageStateChanged(PageState(title: "Hello")))
        #expect(received.map(\.0) == [tab.id])
        #expect(received.map(\.1.title) == ["Hello"])
    }

    @Test func registersPagesTheEngineAlreadyMade() {
        let engine = FakeEngine()
        let registry = TabRegistry(engine: engine)
        let popup = FakeTab()
        registry.register(popup, for: tab.id)
        #expect(registry.engineTab(for: tab) === popup)
        #expect(engine.madeTabs.isEmpty)
    }

    @Test func unloadForgetsThePageAndRecreatesItLater() {
        let engine = FakeEngine()
        let registry = TabRegistry(engine: engine)
        let first = registry.engineTab(for: tab) as! FakeTab
        registry.unload(tab.id)
        #expect(first.onEvent == nil)
        #expect(first.stopLoadingCount == 1)
        let second = registry.engineTab(for: tab)
        #expect(second !== first)
        #expect(engine.madeTabs.count == 2)
    }

    @Test func pagesDoNotKeepTheRegistryAlive() {
        let engineTab = FakeTab()
        weak var weakRegistry: TabRegistry?
        do {
            let registry = TabRegistry(engine: FakeEngine())
            registry.register(engineTab, for: tab.id)
            weakRegistry = registry
        }
        #expect(weakRegistry == nil)
    }
}

@MainActor
final class FakeEngine: BrowserEngine {
    var madeTabs: [FakeTab] = []

    func makeTab(configuration: TabConfiguration) -> any BrowserTab {
        let tab = FakeTab()
        if let url = configuration.initialURL {
            tab.load(url)
        }
        madeTabs.append(tab)
        return tab
    }
}

@MainActor
final class FakeTab: BrowserTab {
    let view = NSView()
    var pageState = PageState()
    var onEvent: ((BrowserTabEvent) -> Void)?
    var loadedURLs: [URL] = []

    func load(_ url: URL) {
        loadedURLs.append(url)
    }

    func goBack() {}
    func goForward() {}
    func reload() {}
    var stopLoadingCount = 0

    func stopLoading() {
        stopLoadingCount += 1
    }
}
