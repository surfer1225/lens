#!/bin/bash
#
# Runs the LensCore test suite without SwiftPM, the counterpart of Scripts/package.sh.
#
# `make test` (SwiftPM) is the normal path. This compiles the library and the tests into dylibs
# and has the Swift interpreter load them and call Swift Testing's entry point, so it works where
# SwiftPM's manifest helper can't run, and it never executes a freshly built binary.
#
# Usage:
#   Scripts/test.sh                       run every test
#   Scripts/test.sh --filter Fingerprint  run tests whose name matches

set -euo pipefail

readonly ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly BUILD="${LENS_BUILD_DIR:-$HOME/.cache/lens-build}/test"
readonly TOOLCHAIN="$(dirname "$(dirname "$(xcrun --find swiftc)")")"
readonly DEVELOPER="${DEVELOPER_DIR:-$(xcode-select -p)}"

# Swift Testing ships outside the SDK: with the Command Line Tools in Library/Developer, with
# Xcode under the platform directory.
FRAMEWORKS=""
for candidate in \
  "$DEVELOPER/Library/Developer/Frameworks" \
  "$DEVELOPER/Platforms/MacOSX.platform/Developer/Library/Frameworks"; do
  if [[ -d "$candidate/Testing.framework" ]]; then FRAMEWORKS="$candidate"; break; fi
done
[[ -n "$FRAMEWORKS" ]] || { echo "!!! Testing.framework not found under $DEVELOPER" >&2; exit 1; }

SDK="$(xcrun --show-sdk-path)"
COMMON=(-target arm64-apple-macos14.0 -sdk "$SDK" -disable-sandbox -swift-version 6 -Onone)

mkdir -p "$BUILD"

echo "==> LensCore (testable)"
xcrun swiftc "${COMMON[@]}" -enable-testing -emit-library -module-name LensCore \
  -emit-module -emit-module-path "$BUILD/LensCore.swiftmodule" \
  -Xlinker -install_name -Xlinker "$BUILD/libLensCore.dylib" \
  -o "$BUILD/libLensCore.dylib" "$ROOT"/Sources/LensCore/*.swift

# A C entry point inside the test library. The interpreter's JIT can't link against
# Testing.framework itself, so the script it runs needs nothing beyond dlopen/dlsym.
cat >"$BUILD/TestEntryPoint.swift" <<'SWIFT'
import Foundation
import Testing

@_cdecl("lens_run_tests")
public func lensRunTests() {
  Task { exit(await Testing.__swiftPMEntryPoint() as CInt) }
  dispatchMain()  // Keeps the main queue running for @MainActor tests.
}
SWIFT

echo "==> LensCoreTests"
xcrun swiftc "${COMMON[@]}" -emit-library -module-name LensCoreTests \
  -I "$BUILD" -L "$BUILD" -lLensCore \
  -F "$FRAMEWORKS" -framework Testing -Xlinker -rpath -Xlinker "$FRAMEWORKS" \
  -Xlinker -rpath -Xlinker "$FRAMEWORKS/../usr/lib" \
  -plugin-path "$TOOLCHAIN/lib/swift/host/plugins/testing" \
  -o "$BUILD/libLensCoreTests.dylib" \
  "$ROOT"/Tests/LensCoreTests/*.swift "$BUILD/TestEntryPoint.swift"

cat >"$BUILD/run.swift" <<SWIFT
import Foundation

guard let library = dlopen("$BUILD/libLensCoreTests.dylib", RTLD_NOW),
  let entryPoint = dlsym(library, "lens_run_tests")
else {
  fatalError(String(cString: dlerror()))
}
unsafeBitCast(entryPoint, to: (@convention(c) () -> Void).self)()
SWIFT

echo "==> running"
cd "$BUILD"
xcrun swift "${COMMON[@]}" run.swift "$@"
