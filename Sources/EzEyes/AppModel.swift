import Foundation
import NightShiftBridge
import SwiftUI

final class AppModel: ObservableObject {
    @Published private(set) var isAvailable = false
    @Published private(set) var isEnabled = false
    @Published var warmth = 0.5
    @Published private(set) var shortcut: Shortcut
    @Published var controlMessage: String?
    @Published var shortcutMessage: String?

    var onStatusChange: ((Bool, Bool) -> Void)?
    var isAdjustingWarmth = false

    private let bridge = NightShiftBridge()
    private let hotkey = HotkeyManager()
    private let shortcutKey = "toggleShortcut.v1"

    init() {
        let storedData = UserDefaults.standard.data(forKey: shortcutKey)
        let legacyData: Data?
        if storedData == nil {
            // Carry forward shortcuts saved by builds with the original bundle ID.
            legacyData = UserDefaults.standard.persistentDomain(forName: "com.mat.ezeyes")?[shortcutKey] as? Data
        } else {
            legacyData = nil
        }

        if let data = storedData ?? legacyData,
           let saved = try? JSONDecoder().decode(Shortcut.self, from: data) {
            shortcut = saved
            if storedData == nil {
                UserDefaults.standard.set(data, forKey: shortcutKey)
            }
        } else {
            shortcut = .initial
        }

        hotkey.onPress = { [weak self] in self?.toggle() }
        let status = hotkey.register(shortcut)
        if status != noErr {
            shortcutMessage = "Could not register \(shortcut.displayName) (error \(status)). Click it to choose another."
            NSLog("EzEyes shortcut registration failed: %d", status)
        }
        refresh()
    }

    func refresh() {
        guard bridge.isSupported else {
            isAvailable = false
            controlMessage = "Night Shift control is unavailable on this macOS version."
            onStatusChange?(false, false)
            return
        }

        var enabled: ObjCBool = false
        var strength: Float = 0
        var available: ObjCBool = false
        guard bridge.readEnabled(&enabled, strength: &strength, available: &available) else {
            isAvailable = false
            controlMessage = "Could not read Night Shift. Try reopening EzEyes."
            onStatusChange?(false, false)
            return
        }

        isAvailable = available.boolValue
        isEnabled = enabled.boolValue
        if !isAdjustingWarmth && strength.isFinite {
            warmth = min(max(Double(strength), 0), 1)
        }
        onStatusChange?(isAvailable, isEnabled)
        if !isAvailable {
            controlMessage = "Night Shift is unavailable for the current display."
        } else if controlMessage?.contains("Night Shift") == true {
            controlMessage = nil
        }
    }

    func toggle() {
        refresh()
        guard isAvailable else { return }
        setEnabled(!isEnabled)
    }

    func setEnabled(_ enabled: Bool) {
        guard isAvailable else { return }
        if bridge.setEnabled(enabled) {
            controlMessage = nil
            refresh()
        } else {
            controlMessage = "Could not change Night Shift."
        }
    }

    func setWarmth(_ value: Double) {
        warmth = min(max(value, 0), 1)
        guard isAvailable else { return }
        if !bridge.setStrength(Float(warmth)) {
            controlMessage = "Could not change warmth."
        } else if controlMessage == "Could not change warmth." {
            controlMessage = nil
        }
    }

    func setShortcut(_ newShortcut: Shortcut) {
        guard newShortcut != shortcut else { return }
        let status = hotkey.register(newShortcut)
        guard status == noErr else {
            shortcutMessage = "\(newShortcut.displayName) is unavailable. Try another shortcut."
            return
        }
        shortcut = newShortcut
        if let data = try? JSONEncoder().encode(newShortcut) {
            UserDefaults.standard.set(data, forKey: shortcutKey)
        }
        shortcutMessage = nil
        onStatusChange?(isAvailable, isEnabled)
    }

    static func diagnosis() -> String {
        let bridge = NightShiftBridge()
        var enabled: ObjCBool = false
        var strength: Float = 0
        var available: ObjCBool = false
        let read = bridge.readEnabled(&enabled, strength: &strength, available: &available)
        return "supported=\(bridge.isSupported) read=\(read) available=\(available.boolValue) enabled=\(enabled.boolValue) warmth=\(Int(strength * 100))% \(bridge.diagnosticReport())"
    }

    static func verifyControls() -> String {
        let bridge = NightShiftBridge()
        var originalEnabled: ObjCBool = false
        var originalStrength: Float = 0
        var available: ObjCBool = false
        guard bridge.readEnabled(&originalEnabled, strength: &originalStrength, available: &available),
              available.boolValue else {
            return "FAIL: Night Shift status unavailable"
        }

        let toggled = bridge.setEnabled(!originalEnabled.boolValue)
        var afterToggle: ObjCBool = false
        var toggleStrength: Float = 0
        var toggleAvailable: ObjCBool = false
        let toggleRead = bridge.readEnabled(&afterToggle,
                                            strength: &toggleStrength,
                                            available: &toggleAvailable)
        let togglePassed = toggled && toggleRead && afterToggle.boolValue != originalEnabled.boolValue
        let enabledRestored = bridge.setEnabled(originalEnabled.boolValue)

        let testStrength: Float = originalStrength < 0.5 ? 0.75 : 0.25
        let warmed = bridge.setStrength(testStrength)
        var afterWarmth: ObjCBool = false
        var measuredStrength: Float = 0
        var warmthAvailable: ObjCBool = false
        let warmthRead = bridge.readEnabled(&afterWarmth,
                                            strength: &measuredStrength,
                                            available: &warmthAvailable)
        let warmthPassed = warmed && warmthRead && abs(measuredStrength - testStrength) < 0.02
        let strengthRestored = bridge.setStrength(originalStrength)

        var finalEnabled: ObjCBool = false
        var finalStrength: Float = 0
        var finalAvailable: ObjCBool = false
        let finalRead = bridge.readEnabled(&finalEnabled,
                                           strength: &finalStrength,
                                           available: &finalAvailable)
        let restored = enabledRestored && strengthRestored && finalRead
            && finalEnabled.boolValue == originalEnabled.boolValue
            && abs(finalStrength - originalStrength) < 0.02
        return "toggle=\(togglePassed ? "PASS" : "FAIL") warmth=\(warmthPassed ? "PASS" : "FAIL") restored=\(restored ? "YES" : "NO")"
    }
}
