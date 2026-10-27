import CoreGraphics

/// Shared design tokens. Colors, typography and per-Space themes go here.
public enum Theme {
    public static let sidebarWidth: CGFloat = 240
    /// Space reserved at the top of the sidebar for the window's traffic lights.
    public static let titleBarHeight: CGFloat = 28

    public static let commandBarWidth: CGFloat = 640
    public static let commandBarCornerRadius: CGFloat = 12
    /// Distance from the top of the window to the command bar.
    public static let commandBarTopInset: CGFloat = 120
    /// Longer suggestion lists scroll.
    public static let commandBarMaxListHeight: CGFloat = 360
}
