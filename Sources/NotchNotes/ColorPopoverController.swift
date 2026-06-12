import AppKit
import SwiftUI

// MARK: - Panel

@MainActor
final class ColorPopoverPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

// MARK: - Controller

@MainActor
final class ColorPopoverController: NSObject, NSWindowDelegate {
    private let settingsStore: AppSettingsStore
    private var panel: ColorPopoverPanel?
    private var localOutsideClickMonitor: Any?
    private var globalOutsideClickMonitor: Any?
    private var suppressShowUntil: Date?
    private let contentSize = NSSize(width: 238, height: 152)

    init(settingsStore: AppSettingsStore) {
        self.settingsStore = settingsStore
        super.init()
    }

    func show(relativeTo parentWindow: NSWindow?) {
        if let suppressShowUntil, Date() < suppressShowUntil {
            return
        }
        suppressShowUntil = nil

        if let panel {
            close(panel, animated: true)
            return
        }

        let panel = ColorPopoverPanel(
            contentRect: NSRect(origin: .zero, size: contentSize),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = false
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .none
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 2)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.delegate = self

        let view = ColorPopoverView(settingsStore: settingsStore)
        let host = FirstMouseHostingView(rootView: view)
        host.frame = NSRect(origin: .zero, size: contentSize)
        host.wantsLayer = true
        panel.contentView = host

        self.panel = panel
        let finalOrigin = origin(relativeTo: parentWindow)
        panel.setFrameOrigin(NSPoint(x: finalOrigin.x, y: finalOrigin.y + 8))
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        panel.makeKeyAndOrderFront(nil)
        installOutsideClickMonitor()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
            panel.animator().setFrameOrigin(finalOrigin)
        }
    }

    func close() {
        guard let panel else { return }
        close(panel, animated: true)
    }

    func close(animated: Bool) {
        guard let panel else { return }
        close(panel, animated: animated)
    }

    func contains(_ point: NSPoint) -> Bool {
        panel?.frame.insetBy(dx: -4, dy: -4).contains(point) ?? false
    }

    func windowWillClose(_ notification: Notification) {
        removeOutsideClickMonitor()
        panel = nil
    }

    func windowDidResignKey(_ notification: Notification) {
        close(animated: true, suppressImmediateReopen: true)
    }

    private func close(animated: Bool, suppressImmediateReopen: Bool) {
        guard let panel else { return }
        close(panel, animated: animated, suppressImmediateReopen: suppressImmediateReopen)
    }

    private func close(_ panel: ColorPopoverPanel, animated: Bool,
                       suppressImmediateReopen: Bool = false) {
        removeOutsideClickMonitor()
        if suppressImmediateReopen {
            suppressShowUntil = Date(timeIntervalSinceNow: 0.25)
        }
        let finalOrigin = NSPoint(x: panel.frame.minX, y: panel.frame.minY + 8)

        guard animated else {
            if self.panel === panel { self.panel = nil }
            panel.close()
            return
        }

        if self.panel === panel { self.panel = nil }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
            panel.animator().setFrameOrigin(finalOrigin)
        }

        panel.perform(#selector(NSWindow.close), with: nil, afterDelay: 0.13)
    }

    private func origin(relativeTo parentWindow: NSWindow?) -> NSPoint {
        let parentFrame = parentWindow?.frame
            ?? NotchGeometry.targetScreen()?.frame
            ?? NSScreen.main?.frame
            ?? NSRect(x: 0, y: 0, width: 1440, height: 900)

        let screenFrame = parentWindow?.screen?.frame
            ?? NotchGeometry.targetScreen()?.frame
            ?? NSScreen.main?.frame
            ?? parentFrame

        let preferredOrigin = NSPoint(
            x: parentFrame.maxX - contentSize.width - 76,
            y: parentFrame.maxY - contentSize.height - 68
        )

        return NSPoint(
            x: min(max(preferredOrigin.x, screenFrame.minX + 10),
                   screenFrame.maxX - contentSize.width - 10),
            y: min(max(preferredOrigin.y, screenFrame.minY + 10),
                   screenFrame.maxY - contentSize.height - 10)
        )
    }

    private func installOutsideClickMonitor() {
        removeOutsideClickMonitor()
        localOutsideClickMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] event in
            guard let self, let panel = self.panel else { return event }
            if event.window !== panel, !self.contains(NSEvent.mouseLocation) {
                self.close(panel, animated: true, suppressImmediateReopen: true)
            }
            return event
        }

        globalOutsideClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            Task { @MainActor in
                self?.close(animated: true, suppressImmediateReopen: true)
            }
        }
    }

    private func removeOutsideClickMonitor() {
        if let localOutsideClickMonitor {
            NSEvent.removeMonitor(localOutsideClickMonitor)
            self.localOutsideClickMonitor = nil
        }
        if let globalOutsideClickMonitor {
            NSEvent.removeMonitor(globalOutsideClickMonitor)
            self.globalOutsideClickMonitor = nil
        }
    }
}

// MARK: - SwiftUI View

struct ColorPopoverView: View {
    @ObservedObject var settingsStore: AppSettingsStore
    @State private var appeared = false

    var body: some View {
        let theme = settingsStore.themeColor

        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "paintpalette")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(theme.popoverHeaderIcon)

                Text("Color")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(theme.popoverHeaderText)
            }

            // Presets
            VStack(alignment: .leading, spacing: 8) {
                Text("Presets")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(theme.popoverLabel)

                HStack(spacing: 8) {
                    PresetButton(
                        label: "Dark",
                        color: ThemeColor.dark.swiftUIColor,
                        isSelected: settingsStore.themeColor == .dark,
                        theme: theme
                    ) {
                        settingsStore.themeColor = .dark
                    }

                    PresetButton(
                        label: "White",
                        color: ThemeColor.white.swiftUIColor,
                        isSelected: settingsStore.themeColor == .white,
                        theme: theme
                    ) {
                        settingsStore.themeColor = .white
                    }
                }
            }

            // Eyedropper
            Button {
                let sampler = NSColorSampler()
                sampler.show { selectedColor in
                    guard let selectedColor,
                          let srgb = selectedColor.usingColorSpace(.sRGB) else { return }
                    Task { @MainActor in
                        settingsStore.themeColor = ThemeColor(
                            red: Double(srgb.redComponent),
                            green: Double(srgb.greenComponent),
                            blue: Double(srgb.blueComponent)
                        )
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "eyedropper")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Pick from Screen")
                        .font(.system(size: 12, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 34)
            }
            .buttonStyle(ColorPopoverButtonStyle(isSelected: false, theme: theme))
        }
        .padding(14)
        .frame(width: 238, height: 152)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(theme.popoverBackground)
        )
        .shadow(color: .black.opacity(theme.isLight ? 0.15 : 0.45), radius: 24, x: 0, y: 14)
        .scaleEffect(appeared ? 1 : 0.965, anchor: .topTrailing)
        .opacity(appeared ? 1 : 0)
        .animation(.spring(response: 0.22, dampingFraction: 0.86), value: appeared)
        .onAppear { appeared = true }
    }
}

// MARK: - Subviews

private struct PresetButton: View {
    let label: String
    let color: Color
    let isSelected: Bool
    let theme: ThemeColor
    let action: () -> Void

    private var tint: Color { theme.foregroundBase }
    private var opacityScale: CGFloat { theme.isLight ? 1.35 : 1.0 }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Circle()
                    .fill(color)
                    .frame(width: 14, height: 14)
                    .overlay(
                        Circle()
                            .stroke(tint.opacity(0.18 * opacityScale), lineWidth: 1)
                    )
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 34)
        }
        .buttonStyle(ColorPopoverButtonStyle(isSelected: isSelected, theme: theme))
    }
}

// MARK: - Button style

struct ColorPopoverButtonStyle: ButtonStyle {
    let isSelected: Bool
    let theme: ThemeColor

    private var tint: Color { theme.foregroundBase }
    private var opacityScale: CGFloat { theme.isLight ? 1.35 : 1.0 }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(tint.opacity(foregroundOpacity(configuration: configuration) * opacityScale))
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(tint.opacity(backgroundOpacity(configuration: configuration) * opacityScale))
            )
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }

    private func backgroundOpacity(configuration: Configuration) -> CGFloat {
        configuration.isPressed
            ? (isSelected ? 0.18 : 0.11)
            : (isSelected ? 0.13 : 0.055)
    }

    private func foregroundOpacity(configuration: Configuration) -> CGFloat {
        configuration.isPressed
            ? 0.74
            : (isSelected ? 0.94 : 0.62)
    }
}
