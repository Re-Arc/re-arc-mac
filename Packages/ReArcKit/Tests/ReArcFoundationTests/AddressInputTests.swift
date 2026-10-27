import Foundation
import ReArcFoundation
import Testing

struct AddressInputTests {
    @Test(arguments: [
        ("example.com", "https://example.com"),
        ("  example.com  ", "https://example.com"),
        ("example.com/path?q=1#top", "https://example.com/path?q=1#top"),
        ("sub.example.co.uk", "https://sub.example.co.uk"),
        ("my-site.dev:8443", "https://my-site.dev:8443"),
        ("localhost", "http://localhost"),
        ("localhost:3000", "http://localhost:3000"),
        ("localhost:3000/api", "http://localhost:3000/api"),
        ("192.168.1.1", "http://192.168.1.1"),
        ("192.168.1.1:8080/admin", "http://192.168.1.1:8080/admin"),
        ("[::1]:8080", "http://[::1]:8080"),
        ("https://swift.org/blog", "https://swift.org/blog"),
        ("http://example.com", "http://example.com"),
        ("HTTPS://Example.com", "HTTPS://Example.com"),
        ("about:blank", "about:blank"),
        ("file:///Users/", "file:///Users/"),
        // A real TLD that's also an extension still opens; the bar offers a search too.
        ("readme.md", "https://readme.md"),
    ])
    func recognizesURLs(text: String, expected: String) {
        #expect(AddressInput(text) == .url(URL(string: expected)!))
    }

    @Test(arguments: [
        "what is swift",
        "swift",
        "1.5",
        "999.1.1.1",
        "example.com:99999",
        "example.com:0",
        "mailto:someone@example.com",
        "user@example.com",
        "foo.bar baz",
        "https://example.com with spaces",
        "-bad.com",
        "c++",
        "https:example.com",
        "http:foo",
        "https://",
        "node.js",
        "vue.js",
        "index.html",
        "package.json",
        "v1.2",
    ])
    func treatsOtherTextAsSearch(text: String) {
        #expect(AddressInput(text) == .search(text))
    }

    @Test(arguments: ["", "   ", "\n"])
    func ignoresBlankText(text: String) {
        #expect(AddressInput(text) == nil)
    }
}
