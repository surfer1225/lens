#!/bin/bash
#
# Builds Lens.app by driving swiftc directly, without SwiftPM.
#
# Why this exists: SwiftPM compiles Package.swift into a helper binary and *executes* it to read
# the manifest. Where that helper can't run, no SwiftPM command works at all, including `swift
# build`. Compiling and linking with swiftc never runs the output, so it succeeds where SwiftPM
# cannot. The Homebrew formula builds through this script too.
#
# `make app` (SwiftPM) remains the primary path. Use this when SwiftPM is unavailable, or to
# produce a bundle without resolving the package graph.
#
# Usage:
#   Scripts/package.sh              build and sign Lens.app
#   Scripts/package.sh --dmg        ...and wrap it in a drag-to-Applications disk image
#   Scripts/package.sh --install    ...and copy straight to /Applications (needs App Management)
#   Scripts/package.sh --no-build   skip compilation, act on the existing bundle
#
# --no-build exists because linking is not reproducible: every rebuild yields a new code hash, and
# with it macOS drops the Accessibility grant. Use it to wrap a bundle you have already approved
# in a disk image without disturbing it.

set -euo pipefail

readonly APP_NAME="Lens"
readonly DEPLOYMENT_TARGET="arm64-apple-macos14.0"

# Dependency pinned to a commit, not just a tag: git tags are mutable, so `--branch v1.10.0`
# alone would let a retagged upstream change what we build without the version moving. The
# commit is verified after cloning.
readonly KS_VERSION="v1.10.0"
readonly KS_COMMIT="70caa8dea43e2d273cd5ab78885d7eff01df550c"

readonly ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly BUILD="${LENS_BUILD_DIR:-$HOME/.cache/lens-build}"
readonly OBJ="$BUILD/manual"
readonly DEPS="$BUILD/deps"
readonly APP="$BUILD/$APP_NAME.app"

# Ad-hoc ("-") by default so this builds for anyone with no certificate setup.
#
# Trade-off: an ad-hoc signature gets a new code hash every build, so macOS drops the
# Accessibility grant and re-prompts after each reinstall. Pass a real identity to keep the
# grant across rebuilds:
#
#   make package IDENTITY="Developer ID Application: Your Name (TEAMID1234)"
#
# Check first that any certificate you use is actually valid — `spctl -a -vv -t exec <app>`
# reporting CSSMERR_TP_CERT_REVOKED means macOS will refuse to run the result at all.
IDENTITY="${IDENTITY:--}"

has_flag() { local FLAG="$1"; shift; [[ " $* " == *" $FLAG "* ]]; }

build_app() {
  local SDK
  SDK="$(xcrun --show-sdk-path)"

  # The macro plugin server (@Observable) is spawned under sandbox-exec, which cannot nest inside
  # an outer sandbox. Harmless when there is no outer sandbox.
  local COMMON=(-target "$DEPLOYMENT_TARGET" -sdk "$SDK" -disable-sandbox -O)

  mkdir -p "$OBJ" "$DEPS"

  if [[ ! -d "$DEPS/KeyboardShortcuts" ]]; then
    echo "==> fetching KeyboardShortcuts $KS_VERSION"
    git clone --quiet --depth 1 --branch "$KS_VERSION" \
      https://github.com/sindresorhus/KeyboardShortcuts.git "$DEPS/KeyboardShortcuts"
  fi

  local actual
  actual="$(git -C "$DEPS/KeyboardShortcuts" rev-parse HEAD)"
  if [[ "$actual" != "$KS_COMMIT" ]]; then
    echo "!!! KeyboardShortcuts is at $actual, expected $KS_COMMIT" >&2
    echo "!!! Refusing to build. Delete $DEPS/KeyboardShortcuts and retry, or update" >&2
    echo "!!! KS_COMMIT here if you have deliberately changed the dependency version." >&2
    exit 1
  fi

  echo "==> KeyboardShortcuts"
  xcrun swiftc -c -wmo "${COMMON[@]}" -swift-version 5 \
    -module-name KeyboardShortcuts \
    -emit-module -emit-module-path "$OBJ/KeyboardShortcuts.swiftmodule" \
    -o "$OBJ/KeyboardShortcuts.o" \
    "$DEPS"/KeyboardShortcuts/Sources/KeyboardShortcuts/*.swift \
    "$ROOT/Scripts/resource_bundle_accessor.swift"

  echo "==> LensCore"
  xcrun swiftc -c -wmo "${COMMON[@]}" -swift-version 6 \
    -module-name LensCore -I "$OBJ" \
    -emit-module -emit-module-path "$OBJ/LensCore.swiftmodule" \
    -o "$OBJ/LensCore.o" "$ROOT"/Sources/LensCore/*.swift

  echo "==> LensAX"
  xcrun swiftc -c -wmo "${COMMON[@]}" -swift-version 6 \
    -module-name LensAX -I "$OBJ" \
    -emit-module -emit-module-path "$OBJ/LensAX.swiftmodule" \
    -o "$OBJ/LensAX.o" "$ROOT"/Sources/LensAX/*.swift

  echo "==> Lens"
  xcrun swiftc -c -wmo "${COMMON[@]}" -swift-version 6 \
    -module-name Lens -I "$OBJ" -parse-as-library \
    -o "$OBJ/Lens.o" "$ROOT"/Sources/Lens/*.swift "$ROOT"/Sources/Lens/UI/*.swift

  echo "==> linking"
  xcrun swiftc -o "$OBJ/$APP_NAME" "${COMMON[@]}" \
    "$OBJ/KeyboardShortcuts.o" "$OBJ/LensCore.o" "$OBJ/LensAX.o" "$OBJ/Lens.o"

  echo "==> assembling $APP_NAME.app"
  rm -rf "$APP"
  mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

  cp "$OBJ/$APP_NAME" "$APP/Contents/MacOS/$APP_NAME"
  cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
  [[ -f "$ROOT/Resources/AppIcon.icns" ]] &&
    cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"

  # MIT requires the copyright notice to accompany every copy, and a linked binary is a copy.
  # Shipping these inside the bundle keeps redistributed .app files compliant on their own.
  cp "$ROOT/LICENSE" "$APP/Contents/Resources/LICENSE"
  cp "$ROOT/THIRD-PARTY-NOTICES.md" "$APP/Contents/Resources/THIRD-PARTY-NOTICES.md"

  # KeyboardShortcuts localises its recorder through Bundle.module, which SwiftPM would normally
  # satisfy with a generated resource bundle. Build the equivalent by hand.
  local KS_BUNDLE="$APP/Contents/Resources/KeyboardShortcuts_KeyboardShortcuts.bundle"
  mkdir -p "$KS_BUNDLE"
  cp -R "$DEPS"/KeyboardShortcuts/Sources/KeyboardShortcuts/Localization/*.lproj "$KS_BUNDLE/"
  cat >"$KS_BUNDLE/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>en</string>
	<key>CFBundleIdentifier</key>
	<string>KeyboardShortcuts-KeyboardShortcuts-resources</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>KeyboardShortcuts_KeyboardShortcuts</string>
	<key>CFBundlePackageType</key>
	<string>BNDL</string>
</dict>
</plist>
PLIST

  # A stable identity keeps the Accessibility grant across rebuilds; an ad-hoc signature changes
  # the code hash every build and forces re-approval each time.
  echo "==> signing as: $IDENTITY"
  codesign --force --options runtime \
    --entitlements "$ROOT/Resources/Lens.entitlements" \
    --sign "$IDENTITY" \
    "$APP"
  codesign --verify --verbose=2 "$APP"
}

make_dmg() {
  local STAGE="$BUILD/dmg"
  local DMG="$BUILD/$APP_NAME.dmg"

  echo "==> building disk image"
  rm -rf "$STAGE" "$DMG"
  mkdir -p "$STAGE"
  cp -R "$APP" "$STAGE/$APP_NAME.app"
  # The drag target. Installing is then a drag from one side of the window to the other.
  ln -s /Applications "$STAGE/Applications"

  hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$STAGE" \
    -format UDZO \
    -quiet \
    "$DMG"
  rm -rf "$STAGE"

  echo "==> built $DMG"
}

install_app() {
  pkill -x "$APP_NAME" 2>/dev/null || true
  sleep 0.5
  if rm -rf "/Applications/$APP_NAME.app" 2>/dev/null &&
    cp -R "$APP" "/Applications/$APP_NAME.app" 2>/dev/null; then
    echo "==> installed /Applications/$APP_NAME.app"
    open "/Applications/$APP_NAME.app"
  else
    echo "!!! cannot write to /Applications: App Management protection (macOS 14+)." >&2
    echo "!!! Grant your terminal App Management in System Settings › Privacy & Security," >&2
    echo "!!! or run with --dmg and drag it across in Finder." >&2
    exit 1
  fi
}

# ---------------------------------------------------------------- main

if has_flag --no-build "$@"; then
  [[ -d "$APP" ]] || {
    echo "!!! no existing bundle at $APP; run without --no-build first." >&2
    exit 1
  }
  echo "==> reusing existing $APP (not rebuilding)"
else
  build_app
  echo "==> built $APP"
fi

has_flag --dmg "$@" && make_dmg
has_flag --install "$@" && install_app

exit 0
