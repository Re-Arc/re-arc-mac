import AppKit
import ComposableArchitecture
import ReArcFoundation
import ReArcUI
import SwiftUI

public struct CommandBarView: View {
    let store: StoreOf<CommandBarFeature>

    public init(store: StoreOf<CommandBarFeature>) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 0) {
            CommandBarTextField(
                text: store.query,
                onChange: { store.send(.queryChanged($0)) },
                onMove: { store.send(.highlightMoved(by: $0)) },
                onSubmit: { store.send(.submitted) },
                onCancel: { store.send(.cancelled) }
            )
            .frame(height: 28)
            .padding(14)

            if !store.suggestions.isEmpty {
                Divider()
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 2) {
                            ForEach(Array(store.suggestions.enumerated()), id: \.element) { index, suggestion in
                                SuggestionRow(
                                    suggestion: suggestion,
                                    isHighlighted: index == store.highlightedIndex
                                )
                                .id(index)
                                .onTapGesture { store.send(.suggestionClicked(suggestion)) }
                            }
                        }
                        .padding(6)
                    }
                    .frame(maxHeight: Theme.commandBarMaxListHeight)
                    .fixedSize(horizontal: false, vertical: true)
                    .onChange(of: store.highlightedIndex) { _, index in
                        proxy.scrollTo(index)
                    }
                }
            }
        }
        .frame(width: Theme.commandBarWidth)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Theme.commandBarCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.commandBarCornerRadius)
                .strokeBorder(.separator)
        )
        .shadow(color: .black.opacity(0.25), radius: 24, y: 8)
    }
}

private struct SuggestionRow: View {
    let suggestion: CommandBarFeature.Suggestion
    let isHighlighted: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .frame(width: 18)
                .foregroundStyle(.secondary)
            Text(title)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 12)
            Text(detail)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .contentShape(Rectangle())
        .background(
            isHighlighted ? Color.accentColor.opacity(0.2) : .clear,
            in: RoundedRectangle(cornerRadius: 6)
        )
    }

    private var symbol: String {
        switch suggestion {
        case .open: "globe"
        case .search: "magnifyingglass"
        case .switchToTab: "square.on.square"
        case .command: "command"
        case .useSearchEngine: "magnifyingglass.circle"
        }
    }

    private var title: String {
        switch suggestion {
        case let .open(url): url.absoluteString
        case let .search(query, _): query
        case let .switchToTab(tab): tab.title
        case let .command(command): command.title
        case let .useSearchEngine(engine): engine.commandTitle
        }
    }

    private var detail: String {
        switch suggestion {
        case .open: "Open"
        case let .search(_, engine): "Search \(engine.name)"
        case .switchToTab: "Switch to Tab"
        case let .command(command): command.shortcut?.displayString ?? ""
        case .useSearchEngine: ""
        }
    }
}

/// An AppKit text field, so arrow keys, Return and Esc reach the bar instead of
/// moving the cursor. It takes focus and selects its text when it appears,
/// which makes Cmd+L ready to replace the current URL.
private struct CommandBarTextField: NSViewRepresentable {
    let text: String
    let onChange: (String) -> Void
    let onMove: (Int) -> Void
    let onSubmit: () -> Void
    let onCancel: () -> Void

    func makeNSView(context: Context) -> NSTextField {
        let field = FocusingTextField()
        field.placeholderString = "Search or enter address"
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = .systemFont(ofSize: 20)
        field.cell?.isScrollable = true
        field.cell?.wraps = false
        field.stringValue = text
        field.delegate = context.coordinator
        return field
    }

    func updateNSView(_ field: NSTextField, context: Context) {
        context.coordinator.parent = self
        if field.stringValue != text {
            field.stringValue = text
            // Text set from outside (Cmd+L again) is selected, ready to replace.
            field.currentEditor()?.selectAll(nil)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: CommandBarTextField

        init(parent: CommandBarTextField) {
            self.parent = parent
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            parent.onChange(field.stringValue)
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            switch selector {
            case #selector(NSResponder.moveUp(_:)), #selector(NSResponder.insertBacktab(_:)):
                parent.onMove(-1)
            case #selector(NSResponder.moveDown(_:)), #selector(NSResponder.insertTab(_:)):
                parent.onMove(1)
            case #selector(NSResponder.insertNewline(_:)):
                parent.onSubmit()
            case #selector(NSResponder.cancelOperation(_:)):
                parent.onCancel()
            default:
                return false
            }
            return true
        }
    }

    private final class FocusingTextField: NSTextField {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window else { return }
            // Becoming first responder selects the whole text.
            DispatchQueue.main.async { [weak self] in
                guard let self, self.window === window else { return }
                window.makeFirstResponder(self)
            }
        }
    }
}
