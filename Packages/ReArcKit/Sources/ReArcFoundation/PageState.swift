import Foundation

/// A snapshot of what a page is doing. The engine reports a new one whenever
/// any of these change, and the app state copies it onto the tab.
public struct PageState: Equatable, Sendable {
    public var url: URL?
    public var title: String?
    public var isLoading: Bool
    /// From 0 to 1 while loading.
    public var estimatedProgress: Double
    public var canGoBack: Bool
    public var canGoForward: Bool
    public var faviconURL: URL?

    public init(
        url: URL? = nil,
        title: String? = nil,
        isLoading: Bool = false,
        estimatedProgress: Double = 0,
        canGoBack: Bool = false,
        canGoForward: Bool = false,
        faviconURL: URL? = nil
    ) {
        self.url = url
        self.title = title
        self.isLoading = isLoading
        self.estimatedProgress = estimatedProgress
        self.canGoBack = canGoBack
        self.canGoForward = canGoForward
        self.faviconURL = faviconURL
    }
}
