# Security

## Reporting a vulnerability

Open a [private security advisory](https://docs.github.com/en/code-security/security-advisories/guidance-on-reporting-and-writing-information-about-vulnerabilities/privately-reporting-a-security-vulnerability)
on this repository rather than a public issue.

## Threat model

Lens is a local macOS utility with **no network access of any kind** — no telemetry, no update
check, no crash reporting, no server. It executes no subprocesses and touches no credentials.

What makes it security-relevant is the permission it needs, not what it does with it.

### Accessibility access

Lens requires Accessibility permission to move other applications' windows. That permission is
broad: any app holding it can read and control other apps' user interfaces, including text in
windows you have open.

This is unavoidable for a window manager — there is no narrower API — but it means you should
grant it only to software you trust. Lens is built from source on your Mac, by hand or by the
Homebrew formula, so you can read exactly what you grant it to.

Builds are ad-hoc signed, so macOS asks for the permission again after each rebuild or
`brew upgrade`. Only approve a Lens you just built or upgraded yourself.

### Not sandboxed

`Resources/Lens.entitlements` disables the App Sandbox. A sandboxed process cannot drive other
applications through the Accessibility API, so every macOS window manager makes this trade. Lens
requests no other entitlements and no hardened-runtime exceptions.

### Private API

Lens resolves one private symbol at runtime via `dlsym`: `_AXUIElementGetWindow`, used to
distinguish two windows of the same application. It is not linked, and its absence is handled
with a documented fallback. See the README for details and the App Store implications.

### Data stored

All in `UserDefaults` under `dev.lens.Lens`:

- **Settings:** gaps, resize step, display and fullscreen preferences, and the bundle identifiers
  of excluded apps.
- **Keyboard shortcut bindings,** stored by the shortcut recorder.
- **Layout memory:** for up to 20 display setups, each window's app, position and size, and its
  title as an HMAC-SHA256 digest under a random per-Mac key (also stored there). Titles are never
  stored as text. Erase with **Forget** in Settings.

Exported configuration files contain only the settings: no layouts, and no system or user
identifiers.

### Supply chain

One dependency, [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) (MIT),
pinned to the same exact commit on every build path:

- `Package.swift` requires that revision;
- `Scripts/package.sh` verifies the commit after cloning and refuses a checkout with local changes;
- the Homebrew formula pins both Lens and the dependency to tag and commit.

Git tags are mutable; commit hashes are not. CI actions are pinned to commits too.

## Scope

Lens moves windows. It does not read window contents, log keystrokes beyond the global hotkeys it
registers, enumerate files, or communicate off-device. A report showing otherwise is a genuine
vulnerability and very much wanted.
