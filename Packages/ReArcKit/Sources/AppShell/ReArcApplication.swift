import AppKit

/// Entry point called from the app target's `main.swift`.
@MainActor
public enum ReArcApplication {
    public static func run() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        // NSApplication holds its delegate weakly, so keep it alive for the run loop.
        withExtendedLifetime(delegate) {
            app.run()
        }
    }
}
