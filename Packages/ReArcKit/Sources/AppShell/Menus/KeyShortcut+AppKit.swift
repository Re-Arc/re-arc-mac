import AppKit
import ReArcFoundation

extension KeyShortcut {
    var keyEquivalent: String {
        switch key {
        case let .character(character): String(character).lowercased()
        case .upArrow: String(Character(UnicodeScalar(UInt16(NSUpArrowFunctionKey))!))
        case .downArrow: String(Character(UnicodeScalar(UInt16(NSDownArrowFunctionKey))!))
        }
    }

    var modifierMask: NSEvent.ModifierFlags {
        var mask: NSEvent.ModifierFlags = []
        if modifiers.contains(.control) { mask.insert(.control) }
        if modifiers.contains(.option) { mask.insert(.option) }
        if modifiers.contains(.shift) { mask.insert(.shift) }
        if modifiers.contains(.command) { mask.insert(.command) }
        return mask
    }
}

extension NSMenuItem {
    /// The command a menu item built from `AppCommand` runs.
    var appCommand: AppCommand? {
        (representedObject as? String).flatMap(AppCommand.init(rawValue:))
    }
}
