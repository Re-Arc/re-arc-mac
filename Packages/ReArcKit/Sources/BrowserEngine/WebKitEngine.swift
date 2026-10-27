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
final class WebKitTab: NSObject, BrowserTab {
    private let webView: WKWebView
    private var observations: [NSKeyValueObservation] = []
    /// Host of the page the current favicon was found on.
    private var faviconHost: String?
    private(set) var pageState = PageState()
    var onEvent: ((BrowserTabEvent) -> Void)?

    init(configuration: WKWebViewConfiguration) {
        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.allowsBackForwardNavigationGestures = true
        super.init()
        webView.navigationDelegate = self
        webView.uiDelegate = self
        observations = [
            observe(\.url),
            observe(\.title),
            observe(\.isLoading),
            observe(\.estimatedProgress),
            observe(\.canGoBack),
            observe(\.canGoForward),
        ]
    }

    var view: NSView { webView }

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

    func stopLoading() {
        webView.stopLoading()
    }

    // WebKit posts these KVO changes on the main thread.
    private func observe<Value>(_ keyPath: KeyPath<WKWebView, Value>) -> NSKeyValueObservation {
        webView.observe(keyPath) { [weak self] _, _ in
            MainActor.assumeIsolated {
                self?.updatePageState()
            }
        }
    }

    private func updatePageState(faviconURL: URL?? = nil) {
        var state = PageState(
            url: webView.url,
            title: webView.title,
            isLoading: webView.isLoading,
            estimatedProgress: webView.estimatedProgress,
            canGoBack: webView.canGoBack,
            canGoForward: webView.canGoForward,
            faviconURL: pageState.faviconURL
        )
        if let faviconURL {
            state.faviconURL = faviconURL
        }
        guard state != pageState else { return }
        pageState = state
        onEvent?(.pageStateChanged(state))
    }

    /// Hands `child` to the app to show as a new tab.
    private func open(_ child: WebKitTab, url: URL?, inBackground: Bool) {
        onEvent?(.newTabOpened(child, url: url, inBackground: inBackground))
    }
}

extension WebKitTab: WKNavigationDelegate {
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        preferences: WKWebpagePreferences
    ) async -> (WKNavigationActionPolicy, WKWebpagePreferences) {
        // Cmd-click and middle-click open the link in a new tab, like Safari.
        let flags = navigationAction.modifierFlags
        let wantsNewTab = flags.contains(.command) || navigationAction.buttonNumber == 2
        guard navigationAction.navigationType == .linkActivated, wantsNewTab,
            let url = navigationAction.request.url
        else {
            return (.allow, preferences)
        }
        let child = WebKitTab(configuration: webView.configuration)
        child.load(url)
        open(child, url: url, inBackground: !flags.contains(.shift))
        return (.cancel, preferences)
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        // A favicon from another site would be wrong; one from the same site is
        // a better placeholder than nothing until the new page finishes.
        if faviconHost != webView.url?.host() {
            faviconHost = nil
            updatePageState(faviconURL: .some(nil))
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let pageURL = webView.url
        webView.evaluateJavaScript(Self.faviconScript) { [weak self] result, _ in
            guard let self, self.webView.url == pageURL else { return }
            let declared = (result as? String).flatMap(URL.init(string:))
            self.faviconHost = pageURL?.host()
            self.updatePageState(faviconURL: .some(declared ?? Self.defaultFaviconURL(for: pageURL)))
        }
    }

    /// WebKit doesn't expose favicons, so read the page's `<link rel=icon>`.
    private static let faviconScript = """
        (() => {
            const link = document.querySelector("link[rel~='icon'], link[rel='apple-touch-icon']");
            return link ? link.href : null;
        })()
        """

    private static func defaultFaviconURL(for pageURL: URL?) -> URL? {
        guard let pageURL, ["http", "https"].contains(pageURL.scheme) else { return nil }
        return URL(string: "/favicon.ico", relativeTo: pageURL)?.absoluteURL
    }
}

extension WebKitTab: WKUIDelegate {
    // `target=_blank` links and `window.open`. WebKit requires the returned
    // view to use the configuration it passes in.
    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        let child = WebKitTab(configuration: configuration)
        open(child, url: navigationAction.request.url, inBackground: false)
        return child.webView
    }
}
