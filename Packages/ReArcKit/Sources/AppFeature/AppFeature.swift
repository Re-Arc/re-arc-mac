import CommandBarFeature
import ComposableArchitecture
import Foundation
import ReArcFoundation

/// Root state for a browser window. Feature reducers (sidebar, Spaces,
/// command bar) are meant to be composed in here as they are built.
@Reducer
public struct AppFeature {
    @ObservableState
    public struct State: Equatable {
        public var tabs: IdentifiedArrayOf<Tab>
        /// Change it with `select(_:)` so the previous selection is recorded.
        public internal(set) var selectedTabID: Tab.ID?
        /// Where selection goes back to when the selected tab is closed.
        public internal(set) var previouslySelectedTabID: Tab.ID?
        /// Most recently closed first, for Reopen Closed Tab.
        public var recentlyClosed: [ClosedTab] = []
        public var isSidebarVisible: Bool
        @Presents public var commandBar: CommandBarFeature.State?

        public init(
            tabs: IdentifiedArrayOf<Tab> = [Tab(url: .startPage, title: Tab.startPageTitle)],
            selectedTabID: Tab.ID? = nil,
            isSidebarVisible: Bool = true
        ) {
            self.tabs = tabs
            self.selectedTabID = selectedTabID ?? tabs.first?.id
            self.isSidebarVisible = isSidebarVisible
        }

        public var selectedTab: Tab? {
            selectedTabID.flatMap { tabs[id: $0] }
        }
    }

    public enum Action: Equatable {
        /// A command from the menu bar or the command bar.
        case run(AppCommand)
        case commandBar(PresentationAction<CommandBarFeature.Action>)
        case newTab(URL)
        case closeTab(Tab.ID)
        case reopenClosedTab
        case selectNextTab
        case selectPreviousTab
        case tabSelected(Tab.ID)
        case toggleSidebar
        /// The engine reported a change in a tab's page.
        case pageStateChanged(Tab.ID, PageState)
        /// A page opened a link in a new tab (a popup, `target=_blank` or Cmd-click).
        case tabOpenedByPage(Tab, openerID: Tab.ID, inBackground: Bool)
    }

    /// How many closed tabs Reopen Closed Tab remembers.
    static let recentlyClosedLimit = 25

    @Dependency(\.tabEngine) var tabEngine
    @Dependency(\.uuid) var uuid

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce(core)
            .ifLet(\.$commandBar, action: \.commandBar) {
                CommandBarFeature()
            }
    }

    private func core(into state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case let .run(command):
            return run(command, state: &state)

        case let .commandBar(.presented(.delegate(delegate))):
            // The bar was opened for this tab; selection may have moved since.
            let barTabID = state.commandBar?.currentTabID
            state.commandBar = nil
            switch delegate {
            case let .open(url, .newTab):
                return core(into: &state, action: .newTab(url))
            case let .open(url, .currentTab):
                guard let id = barTabID, state.tabs[id: id] != nil else {
                    return core(into: &state, action: .newTab(url))
                }
                state.tabs[id: id]?.url = url
                return .run { [tabEngine] _ in
                    await tabEngine.load(id, url)
                }
            case let .switchToTab(id):
                return core(into: &state, action: .tabSelected(id))
            case let .run(command):
                return run(command, state: &state)
            }

        case .commandBar:
            return .none

        case let .newTab(url):
            // New tabs go at the top of the list, as in Arc.
            let title = url == .startPage ? Tab.startPageTitle : url.host() ?? "New Tab"
            let tab = Tab(id: uuid(), url: url, title: title)
            state.tabs.insert(tab, at: 0)
            state.select(tab.id)
            return .none

        case let .closeTab(id):
            guard let index = state.tabs.index(id: id) else { return .none }
            let tab = state.tabs.remove(at: index)
            state.recentlyClosed.insert(ClosedTab(url: tab.url, title: tab.title, index: index), at: 0)
            state.recentlyClosed = Array(state.recentlyClosed.prefix(Self.recentlyClosedLimit))
            if state.selectedTabID == id {
                state.select(state.tabToSelect(afterClosingAt: index))
            }
            return .run { [tabEngine] _ in
                await tabEngine.unload(id)
            }

        case .reopenClosedTab:
            guard !state.recentlyClosed.isEmpty else { return .none }
            let closed = state.recentlyClosed.removeFirst()
            let tab = Tab(id: uuid(), url: closed.url, title: closed.title)
            state.tabs.insert(tab, at: min(closed.index, state.tabs.count))
            state.select(tab.id)
            return .none

        case .selectNextTab:
            state.selectTab(offsetBy: 1)
            return .none

        case .selectPreviousTab:
            state.selectTab(offsetBy: -1)
            return .none

        case let .tabSelected(id):
            guard state.tabs[id: id] != nil else { return .none }
            state.select(id)
            return .none

        case .toggleSidebar:
            state.isSidebarVisible.toggle()
            return .none

        case let .pageStateChanged(id, page):
            state.tabs[id: id]?.apply(page)
            return .none

        case let .tabOpenedByPage(tab, openerID, inBackground):
            // Opened tabs go right after the page that opened them.
            let index = state.tabs.index(id: openerID).map { $0 + 1 } ?? state.tabs.endIndex
            state.tabs.insert(tab, at: index)
            if !inBackground {
                state.select(tab.id)
            }
            return .none
        }
    }

    private func run(_ command: AppCommand, state: inout State) -> Effect<Action> {
        switch command {
        case .newTab:
            // Cmd+T asks where to go, then opens it in a new tab.
            state.commandBar = CommandBarFeature.State(
                destination: .newTab,
                openTabs: state.openTabsForCommandBar
            )
            return .none
        case .openLocation:
            guard let tab = state.selectedTab else {
                return run(.newTab, state: &state)
            }
            state.commandBar = CommandBarFeature.State(
                destination: .currentTab,
                query: tab.url.absoluteString,
                openTabs: state.openTabsForCommandBar,
                currentTabID: tab.id
            )
            return .none
        case .closeTab:
            guard let id = state.selectedTabID else { return .none }
            return core(into: &state, action: .closeTab(id))
        case .reopenClosedTab:
            return core(into: &state, action: .reopenClosedTab)
        case .selectNextTab:
            return core(into: &state, action: .selectNextTab)
        case .selectPreviousTab:
            return core(into: &state, action: .selectPreviousTab)
        case .toggleSidebar:
            return core(into: &state, action: .toggleSidebar)
        }
    }
}

extension AppFeature.State {
    /// Whether a command does anything right now, for enabling menu items.
    public func canRun(_ command: AppCommand) -> Bool {
        switch command {
        case .newTab, .openLocation: true
        case .closeTab: selectedTabID != nil
        case .reopenClosedTab: !recentlyClosed.isEmpty
        case .selectNextTab, .selectPreviousTab: tabs.count > 1
        case .toggleSidebar: true
        }
    }

    var openTabsForCommandBar: [CommandBarFeature.OpenTab] {
        tabs.map { CommandBarFeature.OpenTab(id: $0.id, title: $0.title, url: $0.url) }
    }

    /// Selects a tab, remembering the one it replaces.
    mutating func select(_ id: AppFeature.Tab.ID?) {
        guard id != selectedTabID else { return }
        previouslySelectedTabID = selectedTabID
        selectedTabID = id
    }

    /// After closing the selected tab: the previously selected tab if it's
    /// still open, else the tab that took the closed one's place (the one
    /// below), else the one above. Nil when no tabs are left.
    func tabToSelect(afterClosingAt index: Int) -> AppFeature.Tab.ID? {
        if let previous = previouslySelectedTabID, tabs[id: previous] != nil {
            return previous
        }
        if tabs.indices.contains(index) {
            return tabs[index].id
        }
        return tabs.last?.id
    }

    /// Moves selection through the list, wrapping around at either end.
    mutating func selectTab(offsetBy offset: Int) {
        guard !tabs.isEmpty else { return }
        guard let id = selectedTabID, let index = tabs.index(id: id) else {
            select(offset > 0 ? tabs.first?.id : tabs.last?.id)
            return
        }
        let count = tabs.count
        select(tabs[((index + offset) % count + count) % count].id)
    }
}

extension AppFeature {
    /// What's needed to bring a closed tab back.
    public struct ClosedTab: Equatable, Sendable {
        public var url: URL
        public var title: String
        /// Position in the tab list when it was closed.
        public var index: Int

        public init(url: URL, title: String, index: Int) {
            self.url = url
            self.title = title
            self.index = index
        }
    }

    public struct Tab: Equatable, Identifiable, Sendable {
        /// Sidebar title for the start page until it reports its own.
        public static let startPageTitle = "Re-Arc"

        public let id: UUID
        public var url: URL
        public var title: String
        public var isLoading: Bool
        public var estimatedProgress: Double
        public var canGoBack: Bool
        public var canGoForward: Bool
        public var faviconURL: URL?

        public init(
            id: UUID = UUID(),
            url: URL,
            title: String,
            isLoading: Bool = false,
            estimatedProgress: Double = 0,
            canGoBack: Bool = false,
            canGoForward: Bool = false,
            faviconURL: URL? = nil
        ) {
            self.id = id
            self.url = url
            self.title = title
            self.isLoading = isLoading
            self.estimatedProgress = estimatedProgress
            self.canGoBack = canGoBack
            self.canGoForward = canGoForward
            self.faviconURL = faviconURL
        }

        mutating func apply(_ page: PageState) {
            if let url = page.url {
                self.url = url
            }
            if let title = page.title, !title.isEmpty {
                self.title = title
            } else if page.url != nil {
                // Untitled pages show their host, not the previous page's title.
                title = url.host() ?? url.absoluteString
            }
            isLoading = page.isLoading
            estimatedProgress = page.estimatedProgress
            canGoBack = page.canGoBack
            canGoForward = page.canGoForward
            faviconURL = page.faviconURL
        }
    }
}
