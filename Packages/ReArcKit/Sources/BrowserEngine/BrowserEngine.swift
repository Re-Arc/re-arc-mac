import AppKit
import ReArcFoundation

/// The web engine boundary. The UI talks only to these protocols, so the
/// WebKit engine can later sit alongside (or be replaced by) a Chromium one.
@MainActor
public protocol BrowserEngine {
    func makeTab(configuration: TabConfiguration) -> any BrowserTab
}

@MainActor
public protocol BrowserTab: AnyObject {
    var view: NSView { get }
    var url: URL? { get }
    var title: String? { get }

    func load(_ url: URL)
    func goBack()
    func goForward()
    func reload()
}

public struct TabConfiguration: Sendable {
    public var initialURL: URL?
    /// Tabs with different profiles keep separate cookies, storage and logins.
    public var profileID: ProfileID

    public init(initialURL: URL? = nil, profileID: ProfileID = .default) {
        self.initialURL = initialURL
        self.profileID = profileID
    }
}
