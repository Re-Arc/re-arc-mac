import ComposableArchitecture
import Foundation

/// Lets reducers act on the live page behind a tab. `AppShell` provides the
/// live value, backed by its tab registry.
public struct TabEngineClient: Sendable {
    /// Tears down a tab's page, for example when the tab is closed.
    public var unload: @MainActor @Sendable (AppFeature.Tab.ID) -> Void

    public init(unload: @escaping @MainActor @Sendable (AppFeature.Tab.ID) -> Void) {
        self.unload = unload
    }
}

extension TabEngineClient: TestDependencyKey {
    public static let testValue = TabEngineClient(
        unload: unimplemented("TabEngineClient.unload")
    )
}

extension DependencyValues {
    public var tabEngine: TabEngineClient {
        get { self[TabEngineClient.self] }
        set { self[TabEngineClient.self] = newValue }
    }
}
