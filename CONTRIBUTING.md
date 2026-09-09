# Contributing

Thanks for taking a look. Lens is small on purpose, and the aim is to keep it readable in an
afternoon.

## The most useful contribution

**Bug reports naming a specific application.** The geometry is well tested; what is not is how
individual apps respond to being resized. Every app is entitled to be strange in its own way, and
that long tail only shortens with reports. If Lens misplaces a window in some app, say which app —
that single detail is what makes a report actionable.

## Getting set up

```sh
git clone https://github.com/surfer1225/lens.git
cd lens
make test     # unit tests — no permissions, no displays, no running apps needed
make package  # build and ad-hoc sign Lens.app into ~/.cache/lens-build
```

If SwiftPM fails with `Invalid manifest ... Missing or empty JSON output`, you are on a machine
with binary authorisation software. `make package` avoids SwiftPM entirely — see the README.

## The one architectural rule

**`LensCore` must never import AppKit, ApplicationServices, or anything that touches the system.**

That constraint is the whole reason the test suite exists. `LensCore` is pure functions over
`CGRect` values, so its tests need no Accessibility permission, no display hardware, and no
running applications — which means they run on a CI runner, and on your machine, every time.

The moment `NSScreen` appears in `LensCore`, that stops being true and the tests become
unrunnable. Coordinate conversion, screen enumeration, and every Accessibility call belong in
`LensAX`.

| Target | May import | Tested by |
| --- | --- | --- |
| `LensCore` | Foundation, CoreGraphics | Unit tests |
| `LensAX` | AppKit, ApplicationServices | Manual |
| `Lens` | Anything | Manual |

## Adding an action

1. Add a case to `WindowAction` with a `title`.
2. Add its layout to `RectCalculator.sequence(for:)` — usually a single `UnitRect`.
3. If it pins a window to one side, add it to `crossingEdge` and `mirroredAcrossEdge` so repeated
   presses can carry it across displays.
4. Optionally add a default binding in `Shortcuts.defaultShortcut(for:)`. New actions normally
   ship unbound, since the Spectacle defaults are deliberately preserved.
5. Add a test.

It appears in Settings automatically.

## Testing

```sh
make test
```

New geometry needs a test. The existing suites are the model: assert exact frames against a
1512×982 screen, and cover the multi-display cases including negative origins.

`LensAX` and the UI are not unit-tested — they are boundary code whose behaviour lives in other
processes. If you change them, exercise the awkward cases by hand:

| App | Exercises |
| --- | --- |
| Terminal or iTerm | Size quantised to whole character cells |
| Google Chrome | `AXEnhancedUserInterface` |
| System Settings' About panel | A window that refuses to resize |
| Anything in native fullscreen | Un-fullscreen before moving |
| A second display | Coordinate flip, screen ordering, edge crossing |

## Things that are out of scope

Not because they are bad, but because they belong to other tools and would change what Lens is:

- **Drag-to-edge snapping** — needs a global mouse event tap, which contradicts the minimal
  permissions story. Rectangle does this well.
- **Automatic tiling** — Amethyst and AeroSpace territory.
- **Anything requiring SIP to be disabled**, including moving windows between Spaces. Working on
  a machine you do not fully control is a core property of the project.
- **Network access of any kind.** Lens has none, and the absence is a documented guarantee in
  `SECURITY.md`, not an accident.

## Style

Follow the surrounding code. Comments explain *why*, especially around the Accessibility
workarounds — most of them look arbitrary without the reason, and the reason is usually a macOS
bug or an undocumented behaviour that took a while to find.

## Pull requests

Keep them focused, explain the reasoning in the description, and note how you tested. If it
changes behaviour, update `CHANGELOG.md` under `[Unreleased]`.

CI runs the tests and builds a signed bundle on every pull request.

## Security

Please report vulnerabilities privately — see [SECURITY.md](SECURITY.md).
