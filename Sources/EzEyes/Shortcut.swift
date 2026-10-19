import AppKit
import Carbon
import SwiftUI

struct Shortcut: Codable, Equatable {
    let keyCode: UInt32
    let modifiers: UInt32
    let keyLabel: String

    static let initial = Shortcut(keyCode: 45, modifiers: UInt32(controlKey), keyLabel: "N")

    var displayName: String {
        var parts: [String] = []
        if modifiers & UInt32(controlKey) != 0 { parts.append("⌃") }
        if modifiers & UInt32(optionKey) != 0 { parts.append("⌥") }
        if modifiers & UInt32(shiftKey) != 0 { parts.append("⇧") }
        if modifiers & UInt32(cmdKey) != 0 { parts.append("⌘") }
        return parts.joined() + keyLabel
    }

    init(keyCode: UInt32, modifiers: UInt32, keyLabel: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.keyLabel = keyLabel
    }

    init?(event: NSEvent) {
        let flags = event.modifierFlags.intersection([.control, .option, .shift, .command])
        guard flags.contains(.control) || flags.contains(.option) || flags.contains(.command) else {
            return nil
        }

        var carbonModifiers: UInt32 = 0
        if flags.contains(.control) { carbonModifiers |= UInt32(controlKey) }
        if flags.contains(.option) { carbonModifiers |= UInt32(optionKey) }
        if flags.contains(.shift) { carbonModifiers |= UInt32(shiftKey) }
        if flags.contains(.command) { carbonModifiers |= UInt32(cmdKey) }

        let code = event.keyCode
        let special: [UInt16: String] = [
            36: "↩", 48: "⇥", 49: "Space", 51: "⌫",
            123: "←", 124: "→", 125: "↓", 126: "↑",
            122: "F1", 120: "F2", 99: "F3", 118: "F4",
            96: "F5", 97: "F6", 98: "F7", 100: "F8",
            101: "F9", 109: "F10", 103: "F11", 111: "F12"
        ]
        let label: String
        if let name = special[code] {
            label = name
        } else if let characters = event.charactersIgnoringModifiers,
                  characters.count == 1,
                  let scalar = characters.unicodeScalars.first,
                  !CharacterSet.controlCharacters.contains(scalar) {
            label = characters.uppercased()
        } else {
            return nil
        }

        self.init(keyCode: UInt32(code), modifiers: carbonModifiers, keyLabel: label)
    }
}

final class HotkeyManager {
    private var hotkey: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private var registrationID: UInt32 = 0
    private(set) var handlerStatus: OSStatus = noErr
    var onPress: (() -> Void)?

    init() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
        handlerStatus = InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let event, let context else { return OSStatus(eventNotHandledErr) }
            let manager = Unmanaged<HotkeyManager>.fromOpaque(context).takeUnretainedValue()
            var identifier = EventHotKeyID()
            let result = GetEventParameter(event,
                                           EventParamName(kEventParamDirectObject),
                                           EventParamType(typeEventHotKeyID),
                                           nil,
                                           MemoryLayout<EventHotKeyID>.size,
                                           nil,
                                           &identifier)
            guard result == noErr,
                  identifier.signature == 0x455A4559,
                  identifier.id == manager.registrationID else {
                return OSStatus(eventNotHandledErr)
            }
            manager.onPress?()
            return noErr
        }, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), &handler)
    }

    deinit {
        if let hotkey { UnregisterEventHotKey(hotkey) }
        if let handler { RemoveEventHandler(handler) }
    }

    func register(_ shortcut: Shortcut) -> OSStatus {
        guard handlerStatus == noErr else { return handlerStatus }
        let nextID = registrationID &+ 1
        var replacement: EventHotKeyRef?
        let result = RegisterEventHotKey(shortcut.keyCode,
                                         shortcut.modifiers,
                                         EventHotKeyID(signature: 0x455A4559, id: nextID),
                                         GetApplicationEventTarget(),
                                         0,
                                         &replacement)
        guard result == noErr else { return result }
        if let hotkey { UnregisterEventHotKey(hotkey) }
        hotkey = replacement
        registrationID = nextID
        return noErr
    }

    /// Exercises our Carbon event handler without synthesizing a system key press.
    func verifyDispatch() -> Bool {
        guard hotkey != nil else { return false }
        var event: EventRef?
        let created = CreateEvent(nil,
                                  OSType(kEventClassKeyboard),
                                  UInt32(kEventHotKeyPressed),
                                  GetCurrentEventTime(),
                                  0,
                                  &event)
        guard created == noErr, let event else { return false }
        defer { ReleaseEvent(event) }
        var identifier = EventHotKeyID(signature: 0x455A4559, id: registrationID)
        let parameter = withUnsafePointer(to: &identifier) {
            SetEventParameter(event,
                              EventParamName(kEventParamDirectObject),
                              EventParamType(typeEventHotKeyID),
                              MemoryLayout<EventHotKeyID>.size,
                              $0)
        }
        return parameter == noErr
            && SendEventToEventTarget(event, GetApplicationEventTarget()) == noErr
    }
}

struct ShortcutRecorder: NSViewRepresentable {
    let shortcut: Shortcut
    let onRecord: (Shortcut) -> Void

    func makeNSView(context: Context) -> RecorderButton {
        let button = RecorderButton(title: shortcut.displayName, target: nil, action: nil)
        button.bezelStyle = .rounded
        button.controlSize = .regular
        button.target = button
        button.action = #selector(RecorderButton.startRecording(_:))
        button.show(shortcut.displayName)
        button.toolTip = shortcut == .initial
            ? "Control-N also moves down one line in macOS text fields. Click to change it."
            : "Click to record a new shortcut."
        button.onRecord = onRecord
        return button
    }

    func updateNSView(_ button: RecorderButton, context: Context) {
        button.onRecord = onRecord
        button.toolTip = shortcut == .initial
            ? "Control-N also moves down one line in macOS text fields. Click to change it."
            : "Click to record a new shortcut."
        if !button.isRecording {
            button.show(shortcut.displayName)
        }
    }
}

final class RecorderButton: NSButton {
    var onRecord: ((Shortcut) -> Void)?
    private(set) var isRecording = false
    private var previousTitle = ""
    private var displayText = ""

    override var acceptsFirstResponder: Bool { true }

    @objc func startRecording(_ sender: Any?) {
        guard !isRecording else { return }
        previousTitle = displayText
        guard window?.makeFirstResponder(self) == true else { return }
        isRecording = true
        show("Press shortcut…")
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }
        guard !event.isARepeat else { return }
        if event.keyCode == 53 {
            endRecording()
            return
        }
        guard let shortcut = Shortcut(event: event) else {
            NSSound.beep()
            show("Use ⌃, ⌥, or ⌘")
            return
        }
        endRecording()
        onRecord?(shortcut)
    }

    override func resignFirstResponder() -> Bool {
        endRecording()
        return super.resignFirstResponder()
    }

    private func endRecording() {
        guard isRecording else { return }
        isRecording = false
        show(previousTitle)
    }

    func show(_ text: String) {
        displayText = text
        attributedTitle = NSAttributedString(
            string: text,
            attributes: [
                .foregroundColor: NSColor.systemOrange,
                .font: NSFont.systemFont(ofSize: 13, weight: .semibold)
            ]
        )
    }
}
