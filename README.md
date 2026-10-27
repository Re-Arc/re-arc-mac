<div align="center">

# Re-Arc for Mac

**An open-source alternative to the Arc browser for macOS.**

Vertical tabs, Spaces, split view and a command bar, in a free, private, community-built browser.

[![GitHub stars](https://img.shields.io/github/stars/Re-Arc/re-arc-mac?style=flat)](https://github.com/Re-Arc/re-arc-mac/stargazers)
[![Platform: macOS](https://img.shields.io/badge/platform-macOS-lightgrey)](#)
[![PRs welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](https://github.com/Re-Arc/re-arc-mac/pulls)
[![Good first issues](https://img.shields.io/github/issues/Re-Arc/re-arc-mac/good%20first%20issue)](https://github.com/Re-Arc/re-arc-mac/issues?q=is%3Aopen+is%3Aissue+label%3A%22good+first+issue%22)

</div>

> **Status:** early development. Nothing is ready to download yet. Star and watch the repo to follow along, or jump in and help build it.

## Why Re-Arc?

Many people love the Arc browser's sidebar-first design, but Arc is closed source, and The Browser Company has said it is no longer building new features for Arc. **Re-Arc** is a community-built, open-source browser inspired by that way of browsing. Anyone can use it, inspect it and improve it.

- **Open source:** every line of code is public, and nothing is hidden.
- **Private by default:** no account required and no tracking.
- **Community-driven:** the roadmap is decided in the open, through issues and discussions.
- **Cross-platform family:** this repo is the Mac app. Windows and mobile apps are planned under the [Re-Arc organization](https://github.com/Re-Arc).

## Features (roadmap)

- [ ] Vertical sidebar tabs
- [ ] Pinned tabs and favorites
- [ ] Spaces: separate sets of tabs for work, personal and projects
- [ ] Profiles per Space (separate cookies and logins)
- [ ] Command bar for quick search, tab switching and actions
- [ ] Split view: two or more pages side by side
- [ ] Auto-archive of inactive tabs
- [ ] Quick lookup window for links opened from other apps
- [ ] Keyboard-first navigation
- [ ] Themes and custom colors per Space

Have an idea? [Open a feature request](https://github.com/Re-Arc/re-arc-mac/issues/new).

## Re-Arc vs Arc

|                         | Re-Arc                       | Arc                               |
| ----------------------- | ---------------------------- | --------------------------------- |
| Open source             | ✅                           | ❌                                |
| Free                    | ✅                           | ✅                                |
| Account required        | ❌                           | ✅                                |
| Active development      | ✅                           | Maintenance mode                  |
| Platforms               | macOS (Windows, mobile planned) | macOS, Windows, iOS            |
| Community contributions | ✅                           | ❌                                |

## Getting started

Re-Arc is not ready to install yet, but you can build the project skeleton.

**Requirements:** macOS 14 or later, Xcode 26 or later, and [Homebrew](https://brew.sh).

```sh
make bootstrap   # install XcodeGen
make test        # build and test the Swift package
make open        # generate ReArc.xcodeproj and open it in Xcode
```

### Tech stack

- **Swift 6**, with **AppKit** windows that host **SwiftUI** views
- **The Composable Architecture** for app state
- **WebKit** (`WKWebView`) as the web engine, behind a `BrowserEngine` protocol so other engines can be added
- **Sparkle** for updates, and **XcodeGen** to generate the Xcode project

The stack follows how Arc itself is built. See the [Arc teardown](docs/arc-teardown.md) for what Arc uses and why Re-Arc differs where it does.

### Project layout

```
App/                    app target: entry point, Info.plist, entitlements
Packages/ReArcKit/      all app code, as Swift package modules
  AppShell/             app delegate, windows, menus, engine hosting
  AppFeature/           root reducer; composes the feature modules (TCA)
  <Name>Feature/        one module per feature: reducer and its views
  BrowserEngine/        engine protocol and WebKit implementation
  ReArcUI/              design tokens and store-free shared views
  ReArcFoundation/      models, URL parsing, the shared command list
project.yml             XcodeGen spec for ReArc.xcodeproj
```

New features get their own `<Name>Feature` module; views that take a store live with their reducer. See [docs/dev-notes.md](docs/dev-notes.md) for the full layout rules and how the app is wired.

## Contributing

Contributions of all sizes are welcome: code, design, docs, testing and ideas.

1. Look for issues labeled [`good first issue`](https://github.com/Re-Arc/re-arc-mac/issues?q=is%3Aopen+is%3Aissue+label%3A%22good+first+issue%22) or [`help wanted`](https://github.com/Re-Arc/re-arc-mac/issues?q=is%3Aopen+is%3Aissue+label%3A%22help+wanted%22).
2. Comment on an issue to claim it, or open a new one to propose something.
3. Fork the repo, make your change on a branch, and open a pull request.

If you're not sure where to start, open an issue and say hi.

## FAQ

**Is Arc open source?**
No. Arc by The Browser Company is closed source. Re-Arc is an open-source alternative built from scratch.

**Is Arc still being developed?**
The Browser Company has said it is no longer developing new features for Arc and has moved its focus to its newer browser, Dia. Re-Arc aims to carry the sidebar-first browsing style forward in the open.

**Is Re-Arc affiliated with The Browser Company or Arc?**
No. Re-Arc is an independent community project, not affiliated with, endorsed by or connected to The Browser Company. "Arc" is a trademark of its owner and is used here only to describe what Re-Arc is an alternative to.

**Will there be a Windows or mobile version?**
Yes, they're planned as separate apps under the [Re-Arc organization](https://github.com/Re-Arc).

## Support the project

If you want an open-source Arc alternative to exist, the easiest way to help is to **⭐ star this repo** and share it.
