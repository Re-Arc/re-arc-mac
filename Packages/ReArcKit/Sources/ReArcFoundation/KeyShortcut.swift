import Foundation

/// A keyboard shortcut, independent of AppKit so models and reducers can use it.
public struct KeyShortcut: Hashable, Sendable {
    public enum Key: Hashable, Sendable {
        case character(Character)
        case upArrow
        case downArrow
    }

    public struct Modifiers: OptionSet, Hashable, Sendable {
        public let rawValue: Int

        public init(rawValue: Int) {
            self.rawValue = rawValue
        }

        public static let control = Modifiers(rawValue: 1 << 0)
        public static let option = Modifiers(rawValue: 1 << 1)
        public static let shift = Modifiers(rawValue: 1 << 2)
        public static let command = Modifiers(rawValue: 1 << 3)
    }

    public var key: Key
    public var modifiers: Modifiers

    public init(_ key: Key, _ modifiers: Modifiers) {
        self.key = key
        self.modifiers = modifiers
    }

    /// The shortcut as macOS menus show it, such as "⇧⌘T".
    public var displayString: String {
        var result = ""
        if modifiers.contains(.control) { result += "⌃" }
        if modifiers.contains(.option) { result += "⌥" }
        if modifiers.contains(.shift) { result += "⇧" }
        if modifiers.contains(.command) { result += "⌘" }
        switch key {
        case let .character(character): result += character.uppercased()
        case .upArrow: result += "↑"
        case .downArrow: result += "↓"
        }
        return result
    }
}
