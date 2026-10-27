import Foundation

/// What the user typed into the command bar: somewhere to go, or something to search for.
public enum AddressInput: Equatable, Sendable {
    case url(URL)
    case search(String)

    /// Returns nil for empty or whitespace-only text.
    public init?(_ text: String) {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        if let url = Self.urlWithScheme(text) ?? Self.urlWithoutScheme(text) {
            self = .url(url)
        } else {
            self = .search(text)
        }
    }

    /// Schemes typed explicitly are taken as-is. Others (`localhost:3000`,
    /// `mailto:`) aren't, since they look like a host and port or aren't pages.
    private static let explicitSchemes: Set<String> = ["http", "https", "file", "about"]

    private static func urlWithScheme(_ text: String) -> URL? {
        guard !text.contains(where: \.isWhitespace),
            let colon = text.firstIndex(of: ":"),
            explicitSchemes.contains(text[..<colon].lowercased()),
            let url = URL(string: text)
        else { return nil }
        // `https:example.com` and `https://` parse, but have nowhere to go.
        if ["http", "https"].contains(url.scheme?.lowercased()), url.host()?.isEmpty != false {
            return nil
        }
        return url
    }

    /// `example.com`, `example.com/path`, `localhost:3000`, `192.168.1.1`, `[::1]:8080`.
    private static func urlWithoutScheme(_ text: String) -> URL? {
        guard !text.contains(where: \.isWhitespace) else { return nil }
        let authorityEnd = text.firstIndex { "/?#".contains($0) } ?? text.endIndex
        let authority = text[..<authorityEnd]
        guard let (host, port) = splitHostAndPort(authority), isValidPort(port) else { return nil }

        let scheme: String
        if host.lowercased() == "localhost" || isIPv4(host) || host.hasPrefix("[") {
            // Local servers rarely have certificates.
            scheme = "http"
        } else if isDomainName(host) {
            scheme = "https"
        } else {
            return nil
        }
        guard let url = URL(string: "\(scheme)://\(text)"), url.host() != nil else { return nil }
        return url
    }

    /// Extensions that aren't top-level domains but show up in searches. Real
    /// TLDs that double as extensions (`.md`, `.py`) still open as sites, with
    /// a search offered next to them.
    private static let fileExtensions: Set<String> = [
        "js", "jsx", "mjs", "html", "htm", "txt", "json", "swift", "css", "scss", "yaml", "yml",
        "xml", "plist", "jpg", "jpeg", "png", "gif", "pdf", "exe", "dmg", "dll", "cpp", "java",
    ]

    private static func splitHostAndPort(_ authority: Substring) -> (host: Substring, port: Substring?)? {
        if authority.hasPrefix("[") {
            guard let close = authority.firstIndex(of: "]") else { return nil }
            let host = authority[...close]
            let rest = authority[authority.index(after: close)...]
            guard isIPv6(host.dropFirst().dropLast()) else { return nil }
            if rest.isEmpty { return (host, nil) }
            guard rest.hasPrefix(":") else { return nil }
            return (host, rest.dropFirst())
        }
        let parts = authority.split(separator: ":", omittingEmptySubsequences: false)
        switch parts.count {
        case 1: return (parts[0], nil)
        case 2: return (parts[0], parts[1])
        default: return nil
        }
    }

    private static func isValidPort(_ port: Substring?) -> Bool {
        guard let port else { return true }
        guard let number = Int(port), port.allSatisfy(\.isASCII) else { return false }
        return (1...65535).contains(number)
    }

    private static func isIPv4(_ host: Substring) -> Bool {
        let octets = host.split(separator: ".", omittingEmptySubsequences: false)
        return octets.count == 4
            && octets.allSatisfy { octet in
                octet.count <= 3 && octet.allSatisfy(\.isASCIIDigit) && Int(octet).map { $0 <= 255 } == true
            }
    }

    private static func isIPv6(_ address: Substring) -> Bool {
        address.contains(":") && address.allSatisfy { $0.isHexDigit || $0 == ":" || $0 == "." }
    }

    /// At least two labels, each letters, digits and hyphens, and a top-level
    /// domain that isn't all digits (so `1.5` is a search, not a host) or a
    /// common file extension (so `node.js` is a search).
    private static func isDomainName(_ host: Substring) -> Bool {
        let labels = host.split(separator: ".", omittingEmptySubsequences: false)
        guard labels.count >= 2, let tld = labels.last, tld.count >= 2, !tld.allSatisfy(\.isASCIIDigit),
            !fileExtensions.contains(tld.lowercased())
        else {
            return false
        }
        return labels.allSatisfy { label in
            !label.isEmpty && !label.hasPrefix("-") && !label.hasSuffix("-")
                && label.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" }
        }
    }
}

extension Character {
    fileprivate var isASCIIDigit: Bool {
        isASCII && isNumber
    }
}
