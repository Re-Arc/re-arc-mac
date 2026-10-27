# Arc for Mac: tech stack teardown

What Arc is built with, taken from the installed app bundle. This guided the choices in Re-Arc's setup.

- **Arc version inspected:** 1.160.0 (build 85122), August 2026
- **Method:** static inspection only (no code was executed or decompiled), using [REA](https://github.com/morluto/rea) (`inspect-artifact`, `inspect-plist`, `trace-dylib-resolution`) along with `otool`, `strings` and `plutil`.

## Summary

Arc is a **native Swift macOS app** (AppKit windows with SwiftUI views, state managed with The Composable Architecture). It runs on a **private fork of Chromium**, shipped as one framework that Swift calls through a C bridge.

```
Arc.app
├── Contents/MacOS/Arc                     Swift app (164 MB, universal arm64 + x86_64)
├── Contents/Frameworks/
│   ├── ArcCore.framework                  Chromium fork, 573 MB
│   │   ├── Helpers/Browser Helper (GPU|Renderer|Alerts).app
│   │   ├── Libraries/ libEGL, libGLESv2, SwiftShader (Vulkan)
│   │   └── Resources/ resources.pak, icudtl.dat, v8 snapshots,
│   │                  arc/services/*/mojom-bridge.h + mojom-c_api.h
│   ├── Sparkle.framework                  auto-update (2.9.4)
│   ├── Lottie.framework                   animations
│   ├── Sentry.framework                   crash reporting
│   └── Firebase / gRPC / abseil / openssl_grpc
├── Contents/PlugIns/DockTilePlugIn.plugin
└── Contents/Resources/
    ├── ARC_*.bundle  (~55 feature resource bundles: CommandBar, Sidebar, Spaces, Boosts, LittleBrowser...)
    ├── Arc.sdef                           AppleScript dictionary
    └── popularDomains.json, GoogleService-Info.plist, 50+ .lproj locales
```

## Layers

| Layer | What Arc uses | Evidence |
|---|---|---|
| Language | Swift (with some Objective-C) | links `libswiftCore` and around 30 other Swift overlay libraries; `.swift` source paths in the binary |
| App shell | AppKit: `NSApplication` subclass `Arc.BrowserApp`, `MainMenu.nib`, `NSWindow` view controllers | `NSPrincipalClass`, `NSMainNibFile`, `BrowserWindow.swift`, `WindowContentViewController.swift` |
| UI | SwiftUI inside AppKit, plus Lottie and Metal/CoreImage effects | links `SwiftUI`, `Lottie`, `Metal`, `MetalKit` |
| State | The Composable Architecture and swift-dependencies | `swift-composable-architecture`, `swift-dependencies` and `swift-custom-dump` package checkouts; `Browser/Windows/Store`, `Browser/Application/Store` |
| Modularity | Local Swift packages: `ARC` (features), `ARCClients` (services), `ARCFoundation`, `ARCUI`, `ADK` | source paths `Frameworks/<Package>/Sources/...`; `ARC_*.bundle` SwiftPM resource bundles |
| Web engine | **Chromium 151.0.7922.138**, a private fork named `ArcCore` | `ArcCore.framework` Info.plist, `SCMRevision …refs/branch-heads/7922` |
| Engine bridge | Custom Mojo services exposed to Swift through generated C APIs | `arc/services/ai/public/mojom/ai_service.mojom-c_api.h`, `content_conversion_service.mojom-*` |
| Secondary engine | WebKit (`WKWebView`), probably for small embedded surfaces | links `WebKit.framework` |
| Local persistence | Core Data, plus leveldb (from Firebase) | links `CoreData`; `leveldb_leveldb.bundle` |
| Sync | CloudKit for sidebar sync, Firebase (Auth, Firestore, Functions, Storage) for accounts and sync, with encryption for synced data | `ARC_SidebarSyncCloudKit.bundle`, `FirebaseSidebarSyncClient`, `FirebaseSyncRemoteEncryptionClient` |
| Updates | Sparkle 2 (EdDSA-signed appcast, checked every 8 h) | `SUFeedURL`, `SUPublicEDKey`, `SUScheduledCheckInterval = 28800` |
| Telemetry | Sentry, Datadog, Segment, LaunchDarkly (feature flags) | symbol and string counts in the main binary |
| Other libraries | SDWebImage, KeyboardShortcuts, Defaults, Down (Markdown), DomainParser, ZIPFoundation, YouTubePlayerKit, swift-crypto, swift-transformers, swift-eventsource | SwiftPM resource bundles and strings |
| Automation | AppleScript (`Arc.sdef`, `AppDelegate+Applescript.swift`) | `OSAScriptingDefinition` |
| Build | Xcode 26.1, macOS 26.1 SDK, minimum macOS 13.0, built in CI on GitHub Actions self-hosted runners | `DT*` plist keys, `/Users/admin/actions-runner/_work/arc/arc/...` paths |

## App source layout (from embedded file paths)

```
arc/
├── Browser/                     app target
│   ├── Application/             AppDelegate, MainWindowController, Store/
│   ├── Windows/                 BrowserWindow, LittleWindowViewController, Store/
│   ├── WindowContent/           WindowContentViewController, WebContentViewController, Modals/
│   ├── Sidebar/                 SidebarCells/, Previews/
│   ├── CommandBar/
│   ├── PictureInPicture/
│   ├── DataStore/
│   └── AppleScript/
└── Frameworks/                  local Swift packages
    ├── ARC/          feature modules (most code, ~600 file refs)
    ├── ARCClients/   service clients (CloudKit, Firebase, fonts, block lists...)
    ├── ARCFoundation/
    ├── ARCUI/
    └── ADK/
```

## What Re-Arc takes from this

| Decision | Re-Arc choice | Why |
|---|---|---|
| Language and shell | Swift, AppKit windows hosting SwiftUI | Same as Arc. You need AppKit for custom window chrome, the sidebar and traffic-light placement. |
| State | The Composable Architecture | Same as Arc; it fits a multi-window app with lots of shared state. |
| Modularity | One local SwiftPM package with feature modules, plus a thin app target | Mirrors Arc's `Frameworks/` and `Browser/` split. Modules build and test without Xcode. |
| Web engine | **WKWebView now, behind a `BrowserEngine` protocol** | Maintaining a Chromium fork (Arc's approach) needs dedicated build infrastructure and many hours of CI for each build. WebKit ships with macOS. The protocol keeps the option of adding a Chromium (CEF) engine later. |
| Updates | Sparkle 2 | Same as Arc, and open source. |
| Persistence | Undecided (SwiftData or GRDB) | Arc uses Core Data; choose this when the first feature needs storage. |
| Telemetry | None | The project promises privacy: no Sentry, Datadog, Segment or LaunchDarkly. |
| Accounts and sync | None for now | Arc requires an account; Re-Arc doesn't. CloudKit sync can be added later as an opt-in. |
| Minimum macOS | 14.0 | Gives `@Observable`, SwiftData and recent SwiftUI APIs. |
