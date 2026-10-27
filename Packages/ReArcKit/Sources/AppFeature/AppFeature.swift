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
        public var selectedTabID: Tab.ID?

        public init(
            tabs: IdentifiedArrayOf<Tab> = [Tab(url: .startPage, title: "Re-Arc")],
            selectedTabID: Tab.ID? = nil
        ) {
            self.tabs = tabs
            self.selectedTabID = selectedTabID ?? tabs.first?.id
        }

        public var selectedTab: Tab? {
            selectedTabID.flatMap { tabs[id: $0] }
        }
    }

    public enum Action: Equatable {
        case tabSelected(Tab.ID)
    }

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .tabSelected(id):
                guard state.tabs[id: id] != nil else { return .none }
                state.selectedTabID = id
                return .none
            }
        }
    }
}

extension AppFeature {
    public struct Tab: Equatable, Identifiable, Sendable {
        public let id: UUID
        public var url: URL
        public var title: String

        public init(id: UUID = UUID(), url: URL, title: String) {
            self.id = id
            self.url = url
            self.title = title
        }
    }
}
