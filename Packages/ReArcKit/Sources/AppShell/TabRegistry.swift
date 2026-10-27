import AppFeature
import BrowserEngine
import Foundation

/// Owns the engine tab behind each `AppFeature.Tab`, so pages outlive the
/// views that show them. A tab's page is created the first time it's shown.
@MainActor
final class TabRegistry {
    private let engine: any BrowserEngine
    private var engineTabs: [AppFeature.Tab.ID: any BrowserTab] = [:]
    /// Receives every engine event, tagged with the tab it came from.
    var onEvent: ((AppFeature.Tab.ID, BrowserTabEvent) -> Void)?

    init(engine: any BrowserEngine) {
        self.engine = engine
    }

    func engineTab(for tab: AppFeature.Tab) -> any BrowserTab {
        if let engineTab = engineTabs[tab.id] {
            return engineTab
        }
        let engineTab = engine.makeTab(configuration: TabConfiguration(initialURL: tab.url))
        register(engineTab, for: tab.id)
        return engineTab
    }

    /// Takes over a page the engine already created, such as a popup.
    func register(_ engineTab: any BrowserTab, for id: AppFeature.Tab.ID) {
        engineTab.onEvent = { [weak self] event in
            self?.onEvent?(id, event)
        }
        engineTabs[id] = engineTab
    }
}
