APP_NAME    := Lens
CONFIG      := release

# Build outside the source tree. Handy if the checkout lives in a synced folder (Dropbox,
# iCloud, Google Drive), where syncing tens of thousands of object files is pure waste, and it
# keeps build paths free of spaces.
SCRATCH     := $(HOME)/.cache/lens-build
BIN         := $(SCRATCH)/$(CONFIG)/$(APP_NAME)
APP         := $(SCRATCH)/$(APP_NAME).app

# Ad-hoc ("-") by default so the project builds for anyone with no setup.
#
# The trade-off: an ad-hoc signature gets a fresh code hash on every build, so macOS drops the
# Accessibility grant and re-prompts after each reinstall. If you have a Developer ID or Apple
# Development certificate, pass it to keep the grant across rebuilds:
#
#   make identities                                       # list what you have
#   make install IDENTITY="Developer ID Application: Your Name (TEAMID1234)"
IDENTITY    ?= -
INSTALL_DIR ?= /Applications

.PHONY: all build debug test app install uninstall run clean identities package package-install

all: app

build:
	swift build -c $(CONFIG) --scratch-path "$(SCRATCH)"

debug:
	swift build -c debug --scratch-path "$(SCRATCH)"

test:
	swift test --scratch-path "$(SCRATCH)"

app: build
	rm -rf "$(APP)"
	mkdir -p "$(APP)/Contents/MacOS" "$(APP)/Contents/Resources"
	cp "$(BIN)" "$(APP)/Contents/MacOS/$(APP_NAME)"
	cp Resources/Info.plist "$(APP)/Contents/Info.plist"
	@if [ -f Resources/AppIcon.icns ]; then \
		cp Resources/AppIcon.icns "$(APP)/Contents/Resources/AppIcon.icns"; \
	fi
	codesign --force --options runtime \
		--entitlements Resources/Lens.entitlements \
		--sign "$(IDENTITY)" \
		"$(APP)"
	@codesign --verify --verbose=2 "$(APP)"
	@echo "==> $(APP)"

install: app
	@pkill -x $(APP_NAME) 2>/dev/null || true
	@sleep 0.5
	rm -rf "$(INSTALL_DIR)/$(APP_NAME).app"
	cp -R "$(APP)" "$(INSTALL_DIR)/$(APP_NAME).app"
	open "$(INSTALL_DIR)/$(APP_NAME).app"
	@echo "==> installed to $(INSTALL_DIR)/$(APP_NAME).app"

uninstall:
	@pkill -x $(APP_NAME) 2>/dev/null || true
	rm -rf "$(INSTALL_DIR)/$(APP_NAME).app"

# Run the built bundle in place, without installing.
run: app
	@pkill -x $(APP_NAME) 2>/dev/null || true
	open "$(APP)"

# Build and sign the bundle with swiftc directly, no SwiftPM. Needed on machines whose security
# policy blocks executing freshly built binaries, since SwiftPM has to run a compiled manifest
# just to read Package.swift. See the comment at the top of Scripts/package.sh.
package:
	bash Scripts/package.sh

package-install:
	bash Scripts/package.sh --install

identities:
	@security find-identity -v -p codesigning

clean:
	rm -rf "$(SCRATCH)"
