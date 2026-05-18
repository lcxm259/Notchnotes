import AppKit
import SwiftUI

@MainActor
final class SettingsPopoverPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class SettingsPopoverController: NSObject, NSWindowDelegate {
    private let settingsStore: AppSettingsStore
    private var panel: SettingsPopoverPanel?
    private var outsideClickMonitor: Any?
    private let contentSize = NSSize(width: 238, height: 126)

    init(settingsStore: AppSettingsStore) {
        self.settingsStore = settingsStore
        super.init()
    }

    func show(relativeTo parentWindow: NSWindow?) {
        if let panel {
            close(panel, animated: true)
            return
        }

        let panel = SettingsPopoverPanel(
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

        let view = SettingsPopoverView(settingsStore: settingsStore)
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

    func contains(_ point: NSPoint) -> Bool {
        panel?.frame.insetBy(dx: -4, dy: -4).contains(point) ?? false
    }

    func windowWillClose(_ notification: Notification) {
        removeOutsideClickMonitor()
        panel = nil
    }

    private func close(_ panel: SettingsPopoverPanel, animated: Bool) {
        removeOutsideClickMonitor()
        let finalOrigin = NSPoint(x: panel.frame.minX, y: panel.frame.minY + 8)

        guard animated else {
            if self.panel === panel {
                self.panel = nil
            }
            panel.close()
            return
        }

        if self.panel === panel {
            self.panel = nil
        }

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
            x: parentFrame.maxX - contentSize.width - 22,
            y: parentFrame.maxY - contentSize.height - 68
        )

        return NSPoint(
            x: min(max(preferredOrigin.x, screenFrame.minX + 10), screenFrame.maxX - contentSize.width - 10),
            y: min(max(preferredOrigin.y, screenFrame.minY + 10), screenFrame.maxY - contentSize.height - 10)
        )
    }

    private func installOutsideClickMonitor() {
        removeOutsideClickMonitor()
        outsideClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self else { return event }
            guard let panel = self.panel else { return event }
            if event.window !== panel, !self.contains(NSEvent.mouseLocation) {
                self.close(panel, animated: true)
            }
            return event
        }
    }

    private func removeOutsideClickMonitor() {
        if let outsideClickMonitor {
            NSEvent.removeMonitor(outsideClickMonitor)
            self.outsideClickMonitor = nil
        }
    }
}

struct SettingsPopoverView: View {
    @ObservedObject var settingsStore: AppSettingsStore
    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "gearshape")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.72))

                Text("Settings")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.92))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Trigger")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.50))

                HStack(spacing: 8) {
                    ForEach(TriggerMode.allCases) { mode in
                        Button {
                            settingsStore.triggerMode = mode
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: mode.systemImage)
                                    .font(.system(size: 12, weight: .semibold))
                                Text(mode.title)
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 34)
                        }
                        .buttonStyle(PopoverTriggerButtonStyle(isSelected: settingsStore.triggerMode == mode))
                    }
                }
            }
        }
        .padding(14)
        .frame(width: 238, height: 126)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(red: 0.045, green: 0.045, blue: 0.052).opacity(0.98))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(.white.opacity(0.075), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.45), radius: 24, x: 0, y: 14)
        .scaleEffect(appeared ? 1 : 0.965, anchor: .topTrailing)
        .opacity(appeared ? 1 : 0)
        .animation(.spring(response: 0.22, dampingFraction: 0.86), value: appeared)
        .onAppear {
            appeared = true
        }
    }
}

struct PopoverTriggerButtonStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white.opacity(foregroundOpacity(configuration: configuration)))
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.white.opacity(backgroundOpacity(configuration: configuration)))
            )
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }

    private func backgroundOpacity(configuration: Configuration) -> CGFloat {
        if configuration.isPressed {
            return isSelected ? 0.18 : 0.11
        }
        return isSelected ? 0.13 : 0.055
    }

    private func foregroundOpacity(configuration: Configuration) -> CGFloat {
        if configuration.isPressed {
            return 0.74
        }
        return isSelected ? 0.94 : 0.62
    }
}
