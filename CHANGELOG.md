# Changelog

All notable changes to Lens are recorded here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project
uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed

- **Layout memory now survives sleep and wake.** Waking the Mac or its displays could leave
  windows piled on one screen with the display setup unchanged, so nothing was restored, and the
  next periodic capture then recorded the mess over the good layout. Lens now records just before
  sleep and restores a few seconds after wake.
- A display that drops out and returns within the debounce window (loose cable, KVM switch) now
  triggers a restore; before, the unchanged fingerprint meant the moved windows were left alone.

### Added

- `Scripts/test.sh` runs the test suite without SwiftPM.
- `MemoryPolicy`: the record/restore timing rules as a pure, tested state machine (9 new tests).

### Documentation

- Clearer README notes on building without SwiftPM.

## [1.0.0] - 2026-10-05

First public release. Install with `brew install surfer1225/tap/lens-window-manager`, or build
from source.

### Documentation

- README now leads with what sets Lens apart (automatic layout memory, per-window undo) and
  compares it honestly with Rectangle, Rectangle Pro, Moom and macOS tiling.
- `FEATURES.md`: a feature-by-feature review of the alternatives, with what Lens will and won't
  build, and the roadmap.
- Install with Homebrew: `brew install surfer1225/tap/lens-window-manager` builds from source.
- Requirements corrected: building needs Xcode. The Command Line Tools lack the SwiftUI macro
  plugin that `@State` needs on current SDKs.

### Added

- Spectacle parity: all eighteen of its actions with identical default shortcuts — halves,
  corners, centre, fullscreen, thirds, grow/shrink, display movement, and undo/redo.
- 14 further actions, unbound by default: First/Center/Last Third, First/Last Two Thirds, the six
  sixths, Maximize Height, Maximize Width, Almost Maximize.
- **Layout memory.** Records where windows sit in each display arrangement and restores it when
  that arrangement returns, so undocking and redocking no longer scatters everything. Matching
  uses exact window title first, then position.
- **Edge-crossing on repeated presses.** A second `⌥⌘←` carries the window to the display on the
  left, landing against its facing edge. Falls back to cycling ½ → ⅓ → ⅔ where there is no
  display that way. Switchable to pure size-cycling, or off.
- Per-window undo and redo history.
- Configurable gaps, both around screen edges and between adjacent windows.
- Per-application exclusion list.
- Stage Manager awareness — reserves space for the strip, which macOS does not exclude from
  `visibleFrame`.
- JSON import and export of settings.
- Menu bar item, rebindable shortcuts, and launch at login via `SMAppService`.

### Security

- No network access of any kind: no telemetry, update check, or crash reporting.
- Sole dependency (KeyboardShortcuts) pinned to a verified commit rather than a mutable tag; the
  build refuses to proceed on a mismatch.
- Third-party licence notices shipped inside the app bundle, so redistributed builds comply
  independently.
- Settings import bounded to 64 KB.
- Accessibility messaging timeout capped during the window sweep, so an unresponsive application
  cannot stall the main thread.

### Known limitations

- Apple silicon only; the build targets `arm64-apple-macos14.0`.
- Ad-hoc signed, so macOS drops the Accessibility grant on every rebuild. A stable signing
  identity avoids this.
- Behaviour against the long tail of individual applications is not systematically verified. Bug
  reports naming the specific app are the most useful contribution.

[Unreleased]: https://github.com/surfer1225/lens/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/surfer1225/lens/releases/tag/v1.0.0
