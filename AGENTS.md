# EzEyes project notes

- Keep this a small native menu bar app with no third-party runtime dependencies.
- Build with `./scripts/build-app.sh`; this environment has Command Line Tools but no full Xcode.
- CoreBrightness is private. Check `--diagnose` when changing the bridge, and run `--verify-controls` outside the Codex workspace sandbox so the check can access the Night Shift service. That check must restore the original state.
- Carbon hotkey registration is also blocked by the Codex workspace sandbox. Run `--check-hotkey` outside it.
- For UI checks, launch with `open -a dist/EzEyes.app --args --preview` for a regular window, or `--inspect-popover` for the real menu bar popover. Quit the inspection instance and reopen the app normally afterward.
- Keep all source, scripts, notes, screenshots, and builds under this project folder. `dist/` and `.build/` are generated output.
