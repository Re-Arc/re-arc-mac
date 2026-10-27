import ComposableArchitecture
import Foundation

/// Lets reducers act on the live page behind a tab. `AppShell` provides the
/// live value, backed by its tab registry.
public struct TabEngineClient: Sendable {
    /// Navigates a tab's page. Does nothing if the page isn't loaded yet; it
    /// will load the tab's URL when it's first shown.
    public var load: @MainActor @Sendable (AppFeature.Tab.ID, URL) -> Void
    /// Tears down a tab's page, for example when the tab is closed.
    public var unload: @MainActor @Sendable (AppFeature.Tab.ID) -> Void

    public init(
        load: @escaping @MainActor @Sendable (AppFeature.Tab.ID, URL) -> Void,
        unload: @escaping @MainActor @Sendable (AppFeature.Tab.ID) -> Void
    ) {
        self.load = load
        self.unload = unload
    }
}

extension TabEngineClient: TestDependencyKey {
    public static let testValue = TabEngineClient(
        load: unimplemented("TabEngineClient.load"),
        unload: unimplemented("TabEngineClient.unload")
    )
}

extension DependencyValues {
    public var tabEngine: TabEngineClient {
        get { self[TabEngineClient.self] }
        set { self[TabEngineClient.self] = newValue }
    }
}
