import AppKit
import ReArcFoundation
import WebKit

/// `BrowserEngine` backed by the system WebKit (`WKWebView`).
@MainActor
public final class WebKitEngine: BrowserEngine {
    private var dataStores: [ProfileID: WKWebsiteDataStore] = [:]

    public init() {}

    public func makeTab(configuration: TabConfiguration) -> any BrowserTab {
        let webConfiguration = WKWebViewConfiguration()
        webConfiguration.websiteDataStore = dataStore(for: configuration.profileID)
        let tab = WebKitTab(configuration: webConfiguration)
        if let url = configuration.initialURL {
            tab.load(url)
        }
        return tab
    }

    /// One persistent data store per profile, so profiles never share cookies.
    private func dataStore(for profileID: ProfileID) -> WKWebsiteDataStore {
        if profileID == .default {
            return .default()
        }
        if let store = dataStores[profileID] {
            return store
        }
        let store = WKWebsiteDataStore(forIdentifier: profileID.rawValue)
        dataStores[profileID] = store
        return store
    }
}

@MainActor
final class WebKitTab: BrowserTab {
    private let webView: WKWebView

    init(configuration: WKWebViewConfiguration) {
        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.allowsBackForwardNavigationGestures = true
    }

    var view: NSView { webView }
    var url: URL? { webView.url }
    var title: String? { webView.title }

    func load(_ url: URL) {
        webView.load(URLRequest(url: url))
    }

    func goBack() {
        webView.goBack()
    }

    func goForward() {
        webView.goForward()
    }

    func reload() {
        webView.reload()
    }
}
