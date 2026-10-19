import AppKit
import SwiftUI

struct MenuView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.orange)
                Text("EzEyes")
                    .font(.headline)
                Spacer()
                Text(model.isAvailable ? (model.isEnabled ? "ON" : "OFF") : "UNAVAILABLE")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(model.isEnabled ? .orange : .secondary)
            }

            Divider()

            Toggle(isOn: Binding(
                get: { model.isEnabled },
                set: { model.setEnabled($0) }
            )) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Night Shift")
                        .font(.body.weight(.medium))
                    Text("Toggle now, or use your shortcut")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.switch)
            .disabled(!model.isAvailable)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Warmth")
                        .font(.body.weight(.medium))
                    Spacer()
                    Text("\(Int((model.warmth * 100).rounded()))%")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Slider(value: Binding(
                    get: { model.warmth },
                    set: { model.setWarmth($0) }
                ), in: 0...1) { editing in
                    model.isAdjustingWarmth = editing
                    if !editing { model.refresh() }
                }
                .tint(.orange)
                .disabled(!model.isAvailable)
                HStack {
                    Text("Less warm")
                    Spacer()
                    Text("More warm")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Divider()

            HStack {
                Text("Toggle shortcut")
                    .font(.body.weight(.medium))
                Spacer()
                ShortcutRecorder(shortcut: model.shortcut, onRecord: model.setShortcut)
                    .frame(width: 120, height: 27)
            }

            Text("Click the shortcut, then press a new one. Esc cancels.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let message = model.controlMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let message = model.shortcutMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            HStack {
                Button("Display Settings") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.Displays-Settings.extension") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                Spacer()
                Button("Quit EzEyes") { NSApplication.shared.terminate(nil) }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
            }
            .font(.caption)
        }
        .padding(20)
        .frame(width: 340)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
