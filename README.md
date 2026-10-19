# EzEyes

EzEyes is a small macOS menu bar app for Night Shift. Click its eye icon to toggle Night Shift, adjust warmth, or change the global shortcut. The default shortcut is **Control-N (⌃N)**.

## What is in the download

This repository contains the Swift and Objective-C source, `Package.swift`, `Resources/Info.plist`, and `scripts/build-app.sh`. It does **not** contain a prebuilt app. The build script creates `dist/EzEyes.app` on your own Mac; `dist/` and the Swift build cache in `.build/` are excluded from Git.

An `.app` is the standard macOS folder bundle that makes EzEyes appear in the menu bar. Building from this source creates that bundle locally. The script ad hoc signs it; no Apple Developer account, full Xcode install, or third-party package is needed.

## Build and run on a Mac

You need macOS 13 or later and a Swift 5.9 or later toolchain from Xcode or Apple's [Command Line Tools](https://developer.apple.com/documentation/xcode/installing-the-command-line-tools/). If `swift --version` does not work, run `xcode-select --install` and complete Apple's installer. If Swift is older than 5.9, update the tools through Software Update. EzEyes has been tested on macOS 26.6.2; earlier supported versions have not been tested here.

Once this repository is published on GitHub, choose **Code → Download ZIP** and extract it. In Terminal, type `cd `, drag the extracted folder from Finder into Terminal, and press Return. You can also copy the repository's clone URL from the **Code** menu, clone it with Git, and enter the cloned folder. Then run:

```sh
swift --version
zsh scripts/build-app.sh
open dist/EzEyes.app
```

That runs EzEyes directly from the build folder. Nothing needs to be copied into Applications. It has no Dock icon; look for the eye in the menu bar (outline when Night Shift is off, filled when on). Click the shortcut button to record a new combination, or press Esc to cancel. The shortcut must include Control, Option, or Command. Choose **Quit EzEyes** from its panel when finished.

If you want a permanent copy for your account, quit the running copy first and run these commands from the repository folder:

```sh
mkdir -p "$HOME/Applications"
ditto dist/EzEyes.app "$HOME/Applications/EzEyes.app"
open "$HOME/Applications/EzEyes.app"
```

Run only one copy at a time so the two copies do not compete for the same shortcut. To update a Git clone, pull the new source, quit EzEyes, rerun `zsh scripts/build-app.sh`, copy the new app with `ditto`, and open it again.

This local build is not notarized for distribution. On a managed Mac, installing developer tools or running a locally built app may be restricted by your administrator; building it yourself does not override those rules. See [Apple's guidance on opening apps](https://support.apple.com/en-us/102445) if macOS blocks the app. EzEyes also depends on a private Night Shift API, which may change in a future macOS release.

## Uninstall and remove saved settings

First choose **Quit EzEyes** from the menu bar panel. Then remove the per-user installed copy and its saved shortcut:

```sh
rm -rf "$HOME/Applications/EzEyes.app"
defaults delete com.mat.ezeyes 2>/dev/null || true
```

If you ran it from `dist/EzEyes.app` instead, there is no installed copy to remove. From the repository folder, remove the generated app and build cache with `rm -rf dist .build`, or move the entire downloaded source folder to Trash. If you installed the app somewhere other than `~/Applications`, remove that copy too. EzEyes does not install a login item, launch agent, helper, or background service.

## Checks for maintainers

```sh
dist/EzEyes.app/Contents/MacOS/EzEyes --diagnose
dist/EzEyes.app/Contents/MacOS/EzEyes --check-hotkey
dist/EzEyes.app/Contents/MacOS/EzEyes --verify-controls
```

`--verify-controls` briefly toggles Night Shift and changes warmth, then restores the original settings. On macOS 26.6.2, the control checks, menu bar popover, shortcut recorder, and a physical Control-N press passed.

## How it works

EzEyes uses Apple's Carbon hotkey registration and an Objective-C bridge to `CBBlueLightClient` in the private CoreBrightness framework. [Apple documents](https://support.apple.com/en-gb/guide/mac-help/mchl9d976e85/27/mac/27) the Night Shift controls, while the [nightlight implementation](https://github.com/smudge/nightlight/blob/master/src/macos/client.rs) shows the private calls used here. EzEyes shows an unavailable message if it cannot read Night Shift. macOS still controls any Night Shift schedule you have configured.

The app has no network code. It saves only the shortcut in local UserDefaults under `com.mat.ezeyes`. [Apple also uses Control-N to move down one line](https://support.apple.com/en-us/102650) in text fields, so you may want to change the shortcut.
