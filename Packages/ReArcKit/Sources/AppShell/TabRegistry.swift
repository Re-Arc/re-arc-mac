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

    /// Navigates a tab's page if it's loaded. An unloaded tab loads its saved
    /// URL when it's first shown, so there's nothing to do for it here.
    func load(_ url: URL, in id: AppFeature.Tab.ID) {
        engineTabs[id]?.load(url)
    }

    /// Tears down a tab's page. It's created again if the tab is shown later.
    func unload(_ id: AppFeature.Tab.ID) {
        guard let engineTab = engineTabs.removeValue(forKey: id) else { return }
        engineTab.onEvent = nil
        engineTab.stopLoading()
        engineTab.view.removeFromSuperview()
    }
}
