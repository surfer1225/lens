# Changelog

All notable changes to Lens are recorded here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project
uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

First public release is not yet cut. Everything below is what exists on `main`.

### Documentation

- README now leads with what sets Lens apart (automatic layout memory, per-window undo) and
  compares it honestly with Rectangle, Rectangle Pro, Moom and macOS tiling.
- `FEATURES.md`: a feature-by-feature review of the alternatives, with what Lens will and won't
  build, and the roadmap.

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
