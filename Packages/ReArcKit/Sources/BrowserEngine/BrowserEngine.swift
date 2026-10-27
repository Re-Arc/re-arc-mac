import AppKit
import ReArcFoundation

/// The web engine boundary. The UI talks only to these protocols, so the
/// WebKit engine can later sit alongside (or be replaced by) a Chromium one.
@MainActor
public protocol BrowserEngine {
    func makeTab(configuration: TabConfiguration) -> any BrowserTab
}

/// A live page. It keeps running while its view is off screen, so switching
/// tabs never reloads it.
@MainActor
public protocol BrowserTab: AnyObject {
    var view: NSView { get }
    var pageState: PageState { get }
    /// Called on the main actor whenever the page changes or asks for something.
    var onEvent: ((BrowserTabEvent) -> Void)? { get set }

    func load(_ url: URL)
    func goBack()
    func goForward()
    func reload()
    func stopLoading()
}

@MainActor
public enum BrowserTabEvent {
    case pageStateChanged(PageState)
    /// The page opened a new window (`target=_blank`, `window.open`) or the
    /// user Cmd-clicked a link. The engine has already created the new tab,
    /// so a popup keeps its link to the page that opened it. The receiver must
    /// keep the tab alive before returning, or the page closes.
    case newTabOpened(any BrowserTab, url: URL?, inBackground: Bool)
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
