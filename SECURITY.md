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
grant it only to software you trust. Building Lens yourself from source, which is currently the
only way to install it, is the recommended path for exactly this reason.

### Not sandboxed

`Resources/Lens.entitlements` disables the App Sandbox. A sandboxed process cannot drive other
applications through the Accessibility API, so every macOS window manager makes this trade. Lens
requests no other entitlements and no hardened-runtime exceptions.

### Private API

Lens resolves one private symbol at runtime via `dlsym`: `_AXUIElementGetWindow`, used to
distinguish two windows of the same application. It is not linked, and its absence is handled
with a documented fallback. See the README for details and the App Store implications.

### Data stored

- A JSON blob in `UserDefaults` under `dev.lens.Lens`: gaps, resize step, display and fullscreen
  preferences, and the bundle identifiers of excluded apps.
- Keyboard shortcut bindings, stored by the shortcut recorder.

Nothing else is persisted. Exported configuration files contain the same fields and no
system or user identifiers.

### Supply chain

One dependency, [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) (MIT).
`Scripts/package.sh` pins it to an exact commit and verifies that commit after cloning, refusing
to build on a mismatch — git tags are mutable, commit hashes are not.

## Scope

Lens moves windows. It does not read window contents, log keystrokes beyond the global hotkeys it
registers, enumerate files, or communicate off-device. A report showing otherwise is a genuine
vulnerability and very much wanted.
