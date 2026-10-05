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

Decisions: **Have** (already in Lens) · **Later** (fits, not yet) ·
**Skip** (conflicts with the above, or not worth it).

## Remembering

| Feature | Where | Decision | Why |
|---|---|---|---|
| Restore the arrangement automatically when a display setup returns | Lens; paid apps Resettle and Putback. Rectangle Pro, Moom and BetterTouchTool apply layouts you save, on display change | Have | The headline feature. Among free, open-source apps, only Lens does it automatically. |
| Restore after sleep and wake, and after a display briefly drops out | Rectangle Pro (a "waking from sleep" trigger for saved layouts) | Have | Records just before sleep, restores after wake. |
| Per-window, multi-step undo/redo | Lens only (Rectangle and Rectangle Pro have a single restore; macOS restores the previous size) | Have | |
| Restore after an app relaunches or the Mac restarts | Rectangle Pro ("window opens" trigger, for saved layouts) | Later | The same matching, triggered by app launch. |
| Named layouts you can save and switch to ("Focus", "Review") | Rectangle Pro workspaces, Moom layouts | Later | Builds on layout memory's storage; keyboard-triggered. |
| Show what layout memory has saved, and forget a setup | — | Later | Makes the automatic behaviour visible and trustworthy. |

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
| URL scheme (`lens://action?name=left-half`) | Rectangle | Later | Lets Raycast, Alfred, scripts and Stream Deck drive Lens. Small. |
| Shortcuts and Spotlight actions (App Intents) | — | Later | The native way to automate macOS today. |
| Settings sync across Macs | Rectangle Pro (iCloud) | Later | Through a file in a folder the user chooses, not an account. |
| Update checks | Rectangle (Sparkle) | Later | Only as an opt-in check against GitHub releases, keeping "no network access" the default. |

## Roadmap

Lens stays small on purpose. The priority is making layout memory dependable in every way macOS
scatters windows: display changes, brief drop-outs, and sleep and wake (done, unreleased). Beyond
that, the **Later** items above are ideas rather than commitments. Tell us in an issue which ones
you would use.

## Sources

[Rectangle README](https://github.com/rxhanson/Rectangle) ·
[Rectangle Pro](https://rectangleapp.com/pro) ·
[Rectangle Pro layouts](https://rectangleapp.com/pro/docs/layouts/) ·
[Moom](https://manytricks.com/moom/) ·
[Resettle](https://macoswm.com/wm/resettle) ·
[Putback](https://putback.app/why-mac-windows-move/) ·
[macOS tiling (Sequoia)](https://www.macrumors.com/2024/06/12/macos-sequoia-window-tiling/) ·
[macOS 27](https://9to5mac.com/2026/09/14/macos-27-golden-gate-now-available-here-is-everything-new/)
