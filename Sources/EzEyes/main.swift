import AppKit
import SwiftUI

if CommandLine.arguments.contains("--diagnose") {
    print(AppModel.diagnosis())
} else if CommandLine.arguments.contains("--check-hotkey") {
    let manager = HotkeyManager()
    var presses = 0
    manager.onPress = { presses += 1 }
    let status = manager.register(.initial)
    let dispatched = manager.verifyDispatch()
    print("handler=\(manager.handlerStatus) register=\(status) dispatch=\(dispatched) presses=\(presses)")
    if status != noErr || !dispatched || presses != 1 { exit(EXIT_FAILURE) }
} else if CommandLine.arguments.contains("--verify-controls") {
    let report = AppModel.verifyControls()
    print(report)
    if report != "toggle=PASS warmth=PASS restored=YES" { exit(EXIT_FAILURE) }
} else {
    let app = NSApplication.shared
    let delegate = EzEyesAppDelegate()
    app.delegate = delegate
    let inspectionMode = CommandLine.arguments.contains("--preview")
        || CommandLine.arguments.contains("--inspect-popover")
    app.setActivationPolicy(inspectionMode ? .regular : .accessory)
    withExtendedLifetime(delegate) {
        app.run()
    }
}

final class EzEyesAppDelegate: NSObject, NSApplicationDelegate {
    private var model: AppModel!
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private var refreshTimer: Timer?
    private var previewWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        model = AppModel()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.autosaveName = "EzEyes.NightShift"
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(togglePopover)
            button.toolTip = "EzEyes Night Shift"
        }

        popover.behavior = CommandLine.arguments.contains("--inspect-popover")
            ? .applicationDefined : .transient
        popover.contentViewController = NSHostingController(rootView: MenuView(model: model))
        model.onStatusChange = { [weak self] available, enabled in
            self?.updateStatusIcon(available: available, enabled: enabled)
        }
        model.refresh()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.model.refresh()
        }

        if CommandLine.arguments.contains("--preview")
            || CommandLine.arguments.contains("--inspect-popover") {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 360, height: 430),
                                  styleMask: [.titled, .closable],
                                  backing: .buffered,
                                  defer: false)
            window.title = "EzEyes Preview"
            window.contentViewController = NSHostingController(rootView: MenuView(model: model))
            window.center()
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            previewWindow = window
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                guard let view = window.contentView,
                      let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
                view.cacheDisplay(in: view.bounds, to: bitmap)
                let output = Bundle.main.bundleURL.deletingLastPathComponent()
                    .appendingPathComponent("EzEyes-preview.png")
                try? bitmap.representation(using: .png, properties: [:])?.write(to: output)
            }
        }

        if CommandLine.arguments.contains("--inspect-popover") {
            DispatchQueue.main.async { [weak self] in
                self?.togglePopover()
                NSLog("EzEyes popover shown: %@", self?.popover.isShown == true ? "yes" : "no")
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        refreshTimer?.invalidate()
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            model.refresh()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func updateStatusIcon(available: Bool, enabled: Bool) {
        let symbol = enabled ? "moon.stars.fill" : "moon"
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Night Shift")
        image?.isTemplate = true
        statusItem.button?.image = image
        statusItem.button?.toolTip = available
            ? "Night Shift \(enabled ? "on" : "off") · \(model.shortcut.displayName)"
            : "Night Shift unavailable"
    }
}
