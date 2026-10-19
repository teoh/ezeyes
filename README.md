# EzEyes

EzEyes is a small native macOS menu bar app for Night Shift. Click the moon in the menu bar to toggle Night Shift, drag a warmth slider, or record a different global shortcut. The default shortcut is **Control-N (⌃N)**.

## Run it

Open [`dist/EzEyes.app`](dist/EzEyes.app) in Finder. The app has no Dock icon; its moon icon appears in the menu bar. Click the shortcut button in the panel, press a new key combination, or press Esc to cancel. A shortcut needs Control, Option, or Command. The choice is saved locally and restored on the next launch.

[Apple also uses Control-N to move down one line](https://support.apple.com/en-us/102650) in text fields. The recorder lets you choose another combination if that interferes with your work.

## Build it

macOS 13 or later and Apple's Command Line Tools are required. Full Xcode and third-party packages are not required.

```sh
./scripts/build-app.sh
open dist/EzEyes.app
```

The build creates an ad hoc signed app bundle in `dist/`. To stop it, choose **Quit EzEyes** in the panel.

## Checks

```sh
dist/EzEyes.app/Contents/MacOS/EzEyes --diagnose
dist/EzEyes.app/Contents/MacOS/EzEyes --check-hotkey
dist/EzEyes.app/Contents/MacOS/EzEyes --verify-controls
```

`--verify-controls` briefly toggles Night Shift and changes warmth, then restores the original settings. On macOS 26.6.2, the toggle, warmth change, and restoration passed. The hotkey registration and handler dispatch check passed.

The visible preview also passed UI checks: the switch changed the actual Night Shift state, the slider changed the system warmth from 50% to 71%, and both settings were restored. The shortcut recorder accepted ⌃⌥M, retained it after relaunch, accepted Esc to cancel, could start from the keyboard with Space, and was restored to ⌃N. The available UI automation sends keys to a selected app and did not trigger the global hotkey; a physical Control-N press is the remaining manual check.

## How it works

EzEyes uses Apple's Carbon hotkey registration and a small Objective-C runtime bridge to `CBBlueLightClient` in the private CoreBrightness framework. [Apple documents](https://support.apple.com/en-gb/guide/mac-help/mchl9d976e85/27/mac/27) the Night Shift toggle and colour temperature settings, but does not provide a public app API for them. The [nightlight implementation](https://github.com/smudge/nightlight/blob/master/src/macos/client.rs) shows the private calls used here. A future macOS release could change them; EzEyes shows an unavailable message if it cannot read Night Shift. macOS still controls any Night Shift schedule you have configured.

The app has no network code. It saves only the shortcut in local UserDefaults.
