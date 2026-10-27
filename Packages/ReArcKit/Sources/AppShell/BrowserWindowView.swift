import AppFeature
import BrowserEngine
import ComposableArchitecture
import ReArcUI
import SwiftUI

struct BrowserWindowView: View {
    let store: StoreOf<AppFeature>
    let engine: any BrowserEngine

    var body: some View {
        HStack(spacing: 0) {
            if store.isSidebarVisible {
                SidebarView(store: store)
                    .frame(width: Theme.sidebarWidth)
                    .transition(.move(edge: .leading))
            }
            if let tab = store.selectedTab {
                WebContentView(engine: engine, initialURL: tab.url)
                    .id(tab.id)
                    // Without the sidebar, the page would sit under the traffic lights.
                    .padding(.top, store.isSidebarVisible ? 0 : Theme.titleBarHeight)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: store.isSidebarVisible)
        .ignoresSafeArea()
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

/// Bridges an engine tab's native view into SwiftUI.
struct WebContentView: NSViewRepresentable {
    let engine: any BrowserEngine
    let initialURL: URL

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let tab = engine.makeTab(configuration: TabConfiguration(initialURL: initialURL))
        context.coordinator.tab = tab
        return tab.view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    /// Keeps the engine tab alive for as long as its view is on screen.
    final class Coordinator {
        var tab: (any BrowserTab)?
    }
}
