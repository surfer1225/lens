# Feature review

What Rectangle, Rectangle Pro and Moom offer, and whether Lens should have it. Sources: each
project's own site and README, checked October 2026.

Each decision is tested against what Lens is for:

- **It remembers.** Window arrangements survive display changes, and moves can be undone. This is
  the reason to choose Lens over Rectangle, so it gets the most investment.
- **Keyboard first.** Spectacle's shortcuts and model; the mouse is optional.
- **Small and readable.** A pure, tested geometry core and a thin Accessibility layer. A feature
  that would double the codebase for a niche needs a very good reason.
- **Private.** No network access, no analytics, no accounts.

Decisions: **Have** (already in Lens) · **Build** (on the roadmap) · **Later** (fits, not yet) ·
**Skip** (conflicts with the above, or not worth it).

## Remembering

| Feature | Where | Decision | Why |
|---|---|---|---|
| Restore the arrangement automatically when a display setup returns | Lens only (Rectangle Pro applies predefined workspaces on display change) | Have | The headline feature. |
| Per-window, multi-step undo/redo | Lens only (Rectangle has a single restore) | Have | |
| Restore after an app relaunches or the Mac restarts | — | **Build** | The natural next step for "remembers": the same matching, triggered by app launch. |
| Named layouts you can save and switch to ("Focus", "Review") | Rectangle Pro workspaces, Moom layouts | **Build** | Builds on layout memory's storage; keyboard-triggered. |
| Show what layout memory has saved, and forget a setup | — | **Build** | Makes the automatic behaviour visible and trustworthy. |

## Arranging

| Feature | Where | Decision | Why |
|---|---|---|---|
| Halves, thirds, quarters, sixths, centre, maximize | All | Have | |
| Ninths and eighths | Rectangle | Later | Cheap with the geometry core; low demand. |
| Custom sizes and positions | Rectangle Pro, Moom | Later | Useful, but needs a settings UI that stays simple. |
| Repeated press cycles sizes / moves to the next display | Rectangle, Rectangle Pro | Have | |
| Multi-window actions (tile the front two windows side by side) | Rectangle Pro | Later | |
| Window "throw" (one combo, 16 targets, unfocused windows) | Rectangle Pro | Skip | A second interaction model; Lens stays with Spectacle's. |
| Drag to snap, custom snap areas | Rectangle, Rectangle Pro, Moom, macOS | Skip | macOS now does basic drag tiling; Lens is keyboard first. |
| Move/resize under the cursor with modifier keys | Moom | Later | Small, popular, and keyboard-driven. |
| Stashing windows at the screen edge | Rectangle Pro | Skip | Niche, and it fights with Stage Manager. |
| Pin a window on top | Rectangle Pro | Skip | macOS offers no public API; tools fake it with screen capture. |
| On-screen grid, pop-up palette | Moom | Skip | Mouse-centred. |

## Fitting in

| Feature | Where | Decision | Why |
|---|---|---|---|
| Gaps, per-app exclusions, Stage Manager reservation | Lens, Rectangle (gaps, ignore) | Have | |
| Settings import/export | Lens, Moom | Have | |
| URL scheme (`lens://action?name=left-half`) | Rectangle | **Build** | Lets Raycast, Alfred, scripts and Stream Deck drive Lens. Small. |
| Shortcuts and Spotlight actions (App Intents) | — | **Build** | The native way to automate macOS today. |
| Settings sync across Macs | Rectangle Pro (iCloud) | Later | Through a file in a folder the user chooses, not an account. |
| Update checks | Rectangle (Sparkle) | Later | Only as an opt-in check against GitHub releases, keeping "no network access" the default. |

## Roadmap

1. **Restore on app relaunch and restart**, so layout memory covers the cases users hit next.
2. **Named layouts**, saved and switched by keyboard.
3. **Layout memory inspector:** see what's remembered for each display setup, and forget it.
4. **URL scheme and Shortcuts actions.**
5. Later: hover move/resize, custom sizes, ninths/eighths, file-based settings sync.

## Sources

[Rectangle README](https://github.com/rxhanson/Rectangle) ·
[Rectangle Pro](https://rectangleapp.com/pro) ·
[Moom](https://manytricks.com/moom/) ·
[macOS tiling (Sequoia)](https://www.macrumors.com/2024/06/12/macos-sequoia-window-tiling/)
