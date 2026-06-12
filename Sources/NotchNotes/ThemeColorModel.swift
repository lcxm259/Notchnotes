import SwiftUI

/// Stores user-chosen panel background color, persisted to UserDefaults.
struct ThemeColor: Codable, Equatable {
    var red: Double
    var green: Double
    var blue: Double

    /// The SwiftUI Color for the main panel background.
    var swiftUIColor: Color {
        Color(red: red, green: green, blue: blue)
    }

    /// Perceived brightness (ITU-R BT.709).  ≥ 0.5 → treat as light background.
    var isLight: Bool {
        let luminance = 0.299 * red + 0.587 * green + 0.114 * blue
        return luminance >= 0.5
    }

    /// Color used for text, icons, and foreground elements — white on dark
    /// backgrounds, black on light backgrounds.
    var foregroundBase: Color {
        isLight ? .black : .white
    }

    // MARK: - Derived background colors

    /// Main panel / compact-notch background.
    var panelBackground: Color {
        swiftUIColor.opacity(0.98)
    }

    /// Editor text-area background — slightly offset from the panel.
    var editorBackground: Color {
        let offset: Double = isLight ? -0.04 : 0.04
        return Color(
            red: clamp(red + offset),
            green: clamp(green + offset),
            blue: clamp(blue + offset + (isLight ? -0.01 : 0.01))
        )
    }

    /// Markdown shortcut toolbar background.
    var toolbarBackground: Color {
        let offset: Double = isLight ? -0.02 : 0.035
        return Color(
            red: clamp(red + offset),
            green: clamp(green + offset),
            blue: clamp(blue + offset + (isLight ? -0.00 : 0.01))
        )
    }

    /// Settings / color popover background.
    var popoverBackground: Color {
        let offset: Double = isLight ? -0.02 : 0.025
        return Color(
            red: clamp(red + offset),
            green: clamp(green + offset),
            blue: clamp(blue + offset + (isLight ? -0.00 : 0.01))
        ).opacity(0.98)
    }

    /// Tab-pager capsule background.
    var tabPagerBackground: Color {
        foregroundBase.opacity(isLight ? 0.06 : 0.045)
    }

    // MARK: - Borders / separators

    var borderColor: Color {
        foregroundBase.opacity(isLight ? 0.12 : 0.09)
    }

    var separatorColor: Color {
        foregroundBase.opacity(isLight ? 0.08 : 0.045)
    }

    // MARK: - Foreground

    /// Icon / primary text foreground (e.g. compact icon, tab dots).
    var iconForeground: Color {
        foregroundBase.opacity(isLight ? 0.78 : 0.82)
    }

    /// Active tab dot.
    var activeTabDot: Color {
        foregroundBase.opacity(isLight ? 0.78 : 0.82)
    }

    /// Inactive tab dot.
    var inactiveTabDot: Color {
        foregroundBase.opacity(isLight ? 0.30 : 0.34)
    }

    // MARK: - Settings / popover header

    var popoverHeaderIcon: Color {
        foregroundBase.opacity(isLight ? 0.68 : 0.72)
    }

    var popoverHeaderText: Color {
        foregroundBase.opacity(isLight ? 0.88 : 0.92)
    }

    var popoverLabel: Color {
        foregroundBase.opacity(isLight ? 0.44 : 0.50)
    }

    // MARK: - Button helpers

    /// Background opacity values for `RoundedHoverButtonBody`.
    func buttonBackground(normal: CGFloat, hover: CGFloat, pressed: CGFloat)
        -> (normal: CGFloat, hover: CGFloat, pressed: CGFloat)
    {
        if isLight {
            // Light theme: scale opacities down slightly so the effect isn't too heavy.
            return (normal * 1.2, hover * 1.3, pressed * 1.3)
        }
        return (normal, hover, pressed)
    }

    /// Stroke opacity for `RoundedHoverButtonBody`.
    var buttonStrokeOpacity: CGFloat {
        isLight ? 0.10 : 0.06
    }

    // MARK: - Editor theme

    var editorBodyText: NSColor {
        NSColor(white: isLight ? 0.12 : 0.92, alpha: 1)
    }

    var editorMutedText: NSColor {
        NSColor(white: isLight ? 0.38 : 0.58, alpha: 1)
    }

    var editorDisabledText: NSColor {
        NSColor(white: isLight ? 0.55 : 0.38, alpha: 1)
    }

    var editorHeadingMarker: NSColor {
        NSColor(white: isLight ? 0.50 : 0.44, alpha: 1)
    }

    var editorStrikethrough: NSColor {
        NSColor(white: isLight ? 0.45 : 0.62, alpha: 1)
    }

    var editorCheckboxUncheckedStroke: NSColor {
        NSColor(white: isLight ? 0.50 : 0.48, alpha: 1)
    }

    // MARK: - Presets

    static let dark = ThemeColor(red: 0.02, green: 0.02, blue: 0.025)
    static let white = ThemeColor(red: 0.97, green: 0.97, blue: 0.97)

    // MARK: - Helpers

    private func clamp(_ value: Double) -> Double {
        max(0, min(1, value))
    }
}

// MARK: - Environment key for light/dark awareness

private struct ThemeIsLightKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    var themeIsLight: Bool {
        get { self[ThemeIsLightKey.self] }
        set { self[ThemeIsLightKey.self] = newValue }
    }
}
