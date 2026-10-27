import Foundation

extension URL {
    /// Page shown in a new window until a real start page exists.
    public static let startPage = URL(string: "https://github.com/Re-Arc")!

    /// An empty page, for tabs that don't have a URL yet.
    public static let blankPage = URL(string: "about:blank")!
}
