import AppFeature
import BrowserEngine
import CommandBarFeature
import ComposableArchitecture
import ReArcUI
import SwiftUI

struct BrowserWindowView: View {
    let store: StoreOf<AppFeature>
    let tabs: TabRegistry

    var body: some View {
        HStack(spacing: 0) {
            if store.isSidebarVisible {
                SidebarView(store: store)
                    .frame(width: Theme.sidebarWidth)
                    .transition(.move(edge: .leading))
            }
            if let tab = store.selectedTab {
                WebContentView(tab: tabs.engineTab(for: tab))
                    // Without the sidebar, the page would sit under the traffic lights.
                    .padding(.top, store.isSidebarVisible ? 0 : Theme.titleBarHeight)
            } else {
                // Closing the last tab leaves the window open with an empty page area.
                Color(nsColor: .windowBackgroundColor)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: store.isSidebarVisible)
        .ignoresSafeArea()
        .overlay(alignment: .top) {
            if let barStore = store.scope(state: \.commandBar, action: \.commandBar.presented) {
                ZStack(alignment: .top) {
                    // Clicking anywhere outside the bar closes it.
                    Color.black.opacity(0.001)
                        .onTapGesture { barStore.send(.cancelled) }
                    CommandBarView(store: barStore)
                        .padding(.top, Theme.commandBarTopInset)
                }
            }
        }
        .onChange(of: store.commandBar == nil) { _, isClosed in
            // Give the keyboard back to the page once the bar goes away.
            guard isClosed, let tab = store.selectedTab else { return }
            // Opening a new tab or switching attaches a different page in this
            // same update, so wait until it's in the window.
            let pageView = tabs.engineTab(for: tab).view
            DispatchQueue.main.async {
                pageView.window?.makeFirstResponder(pageView)
            }
        }
    }
}

/// Placeholder sidebar that lists tabs. The real sidebar (Spaces, pinned tabs) goes here.
struct SidebarView: View {
    let store: StoreOf<AppFeature>

    var body: some View {
        List(store.tabs, selection: selection) { tab in
            Text(tab.title)
        }
        .listStyle(.sidebar)
        .padding(.top, Theme.titleBarHeight)
    }

    private var selection: Binding<AppFeature.Tab.ID?> {
        Binding(
            get: { store.selectedTabID },
            set: { id in
                if let id {
                    store.send(.tabSelected(id))
                }
            }
        )
    }
}

/// Shows a live engine tab. Switching tabs swaps which page is attached here;
/// the pages themselves keep running in `TabRegistry`.
struct WebContentView: NSViewRepresentable {
    let tab: any BrowserTab

    func makeNSView(context: Context) -> NSView {
        let container = NSView()
        attach(tab.view, to: container)
        return container
    }

    func updateNSView(_ container: NSView, context: Context) {
        guard container.subviews != [tab.view] else { return }
        // Keep typing and scrolling going to the page after a switch.
        let window = container.window
        let hadFocus = container.subviews.contains { pageView in
            (window?.firstResponder as? NSView)?.isDescendant(of: pageView) == true
        }
        for pageView in container.subviews {
            pageView.removeFromSuperview()
        }
        attach(tab.view, to: container)
        if hadFocus {
            window?.makeFirstResponder(tab.view)
        }
    }

    private func attach(_ pageView: NSView, to container: NSView) {
        pageView.frame = container.bounds
        pageView.autoresizingMask = [.width, .height]
        container.addSubview(pageView)
    }
}
