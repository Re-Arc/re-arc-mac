# Developer notes

Working notes for contributors: how the app is wired today, the layout new code
should follow, and WebKit/AppKit gotchas already hit. For how Arc itself is
built, see [arc-teardown.md](arc-teardown.md).

## How a tab works (as of #1 and #2)

Follow one tab from launch to close:

1. `AppDelegate.init` creates a `TabRegistry` (backed by `WebKitEngine`) and the
   TCA `Store<AppFeature>`. The store's `tabEngine` dependency is the registry,
   so reducers can act on live pages.
2. `BrowserWindowView` shows the selected `AppFeature.Tab` with
   `WebContentView(tab: tabs.engineTab(for: tab))`. The registry creates the
   engine page the first time a tab is shown, then reuses it.
3. `WebContentView` only swaps which page view is attached to its container.
   Pages keep running off screen, so switching tabs never reloads.
4. `WebKitTab` watches `WKWebView` with KVO and sends a `PageState` snapshot
   (URL, title, loading, progress, back/forward, favicon) through `onEvent`.
5. `TabRegistry` tags the event with the tab ID; `AppDelegate` sends
   `.pageStateChanged(id, page)` to the store, and `Tab.apply` copies it over.
6. Popups, `target=_blank` and Cmd/middle-clicks arrive as `.newTabOpened`.
   The engine has already made the child page; `AppDelegate` registers it under
   a new tab ID and sends `.tabOpenedByPage`.
7. Menu commands (Tabs menu) go through the responder chain to the key
   window's `BrowserWindowController`, which sends actions to the store.
   With no window open, `AppDelegate.newTab` handles Cmd+T.
8. `.closeTab` removes the tab, records it in `recentlyClosed`, picks the next
   selection and runs an effect calling `tabEngine.unload(id)`.

To act on a page from a reducer (load a URL, go back, zoom), add a closure to
`TabEngineClient` (in `AppFeature`), implement it in `TabRegistry`, and wire it
in `AppDelegate.init`.

## Module and folder layout

Decided while working on #2, applied from #3 on:

```
Packages/ReArcKit/Sources/
  AppShell/            AppDelegate, ReArcApplication, TabRegistry
    Windows/           window controllers
    Menus/             MainMenu
    Views/             BrowserWindowView, WebContentView, split hosting
  AppFeature/          root reducer, TabEngineClient
  <Name>Feature/       one module per child reducer, with its views
  PersistenceClient/   saved state on disk (from #8)
  BrowserEngine/       engine protocol, WebKit implementation, favicon loading
  ReArcUI/             Theme and store-free shared views
  ReArcFoundation/
    Models/            Tab (from #5), SidebarItem, Space, Profile, PageState, ProfileID
    URLs/              URL+ReArc, URL-or-search parsing, search engines
    AppCommand.swift   shared command list for menus and the command bar
```

Rules:

- Add a module only when an issue needs one. Planned: `CommandBarFeature`
  (#3), `SidebarFeature` (#5), `PersistenceClient` (#8), `SpacesFeature`
  (#9), `ArchiveFeature` and `SettingsFeature` (#13). #4, #6, #7, #10, #11 and
  #12 extend `AppFeature` and `AppShell` instead.
- Dependencies point down only: AppShell → AppFeature → feature modules →
  PersistenceClient / ReArcUI / ReArcFoundation. BrowserEngine depends only on
  ReArcFoundation.
- Child features talk to the parent with `delegate` actions and never import
  `AppFeature`.
- A view that takes `StoreOf<XFeature>` lives in that feature's module.
  `ReArcUI` views take plain values and closures.
- Clients are a `struct XClient` of closures with `testValue` and a
  `DependencyValues` accessor in the same file. A live value that needs AppKit
  or the engine goes in AppShell.
- Models are plain Foundation types with no TCA import.
- Feature modules stay flat. Only AppShell and ReArcFoundation get subfolders.
- One main type per file, named after it. Extensions go in `Type+Topic.swift`.
- Tests: one target per module (`Tests/<Module>Tests/`), files named
  `<Subject>Tests.swift` with a Swift Testing `struct`. Fakes live in the
  test target that uses them (see `AppShellTests/TabRegistryTests.swift`).

## Gotchas

**WebKit**

- `createWebViewWith` must return a web view built from the configuration
  WebKit passes in, and something must keep it alive. If nothing does, the
  popup closes immediately and `window.open` (OAuth, payments) breaks.
- WebKit doesn't expose favicons. `WebKitTab` reads `<link rel=icon>` after
  load and falls back to `/favicon.ico`. Icons often come from a CDN host, so
  compare the page host the icon was found on, not the icon's own host.
- KVO on `WKWebView` fires on the main thread. Wrap handlers in
  `MainActor.assumeIsolated`. `evaluateJavaScript`'s completion is already
  `@MainActor`.
- `WKWebView.url` changes when a navigation starts, but `title` still holds
  the old page's title until commit, then is briefly `""`. `Tab.apply` falls
  back to the host for empty titles.
- Removing the focused web view drops first responder. `WebContentView`
  restores focus to the newly attached page.
- A web view can't change its data store, so moving a tab to another profile
  (#10) means a new engine tab.

**AppKit and TCA**

- Ctrl+Tab is used by AppKit for key-view navigation before menus see it, so
  `BrowserWindow.sendEvent` catches it. Other shortcuts are plain menu key
  equivalents. An uppercase key equivalent (`"T"`, `"W"`) means Shift.
- Menu items route through the responder chain. `NSWindowController` is
  automatically the window's next responder, so `BrowserWindowController`
  receives them, and `validateMenuItem` disables items that don't apply.
- Don't name menu actions `selectNextTab:`/`selectPreviousTab:` or other
  selectors NSWindow already implements: the window answers first. Browser
  actions use `selectNextBrowserTab:` and similar, and windows set
  `tabbingMode = .disallowed` so native window tabs don't compete.
- When masking modifier flags, keep only command/option/control/shift.
  `deviceIndependentFlagsMask` includes Caps Lock and breaks equality checks.
- Change selection only through `State.select(_:)`, which records
  `previouslySelectedTabID`. A `didSet` would also work, but it depends on how
  the `@ObservableState` macro expands. Tests use `@testable import` to set and
  assert these `internal(set)` properties.
- Effects that call `TabEngineClient` must capture it (`.run { [tabEngine] _ in
  ... }`); capturing `self` fails Swift 6 sendability checks.

## Building and CI

- `make test` runs the package tests. `make app` builds the .app and passes
  `-skipMacroValidation`, because `xcodebuild` otherwise refuses TCA's macros
  from the command line (#14).
- `make app` rewrites `Packages/ReArcKit/Package.resolved` to add Sparkle.
  Don't commit that change; run `git checkout Packages/ReArcKit/Package.resolved`.
- `make lint` fails on code that predates these notes (`case let .x(a, b)`,
  trailing commas, one long line in `MainMenu`). CI doesn't run it. Match the
  surrounding style rather than reformatting existing code.
- Run a built app with
  `.build/DerivedData/Build/Products/Debug/Re-Arc.app/Contents/MacOS/Re-Arc`.

## Branches

Issue work is stacked, each PR based on the one before it:
`main ← ci/skip-macro-validation (#14) ← issue/1-live-tabs (#15) ←
issue/2-tab-shortcuts ← issue/3-…`. When a PR merges, retarget the next one
to `main`.
