# Cycle — common tasks, a make alternative to the justfile. `make help` lists them.
# Pass options as variables: `make build CONFIG=debug`, `make icon NAME=cycle-panes`.
# Written for the GNU Make 3.81 that ships with macOS: each recipe is one shell script.

SHELL := /bin/bash
.DEFAULT_GOAL := help

APP := build/Cycle.app
BUNDLE_ID := com.zms.Cycle
VERSION := $(shell tr -d '[:space:]' < VERSION)
# Where releases are published, and the Homebrew tap that installs them.
GITHUB := zmscode/Cycle
TAP := zmscode/homebrew-cycle
CONFIG ?= release
NAME ?= cycle-minimal
ZIP := build/Cycle-$(VERSION).zip

.PHONY: help build b run r reset-permissions icon package release

help: ## List the tasks
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  %-18s %s\n", $$1, $$2}'

build: ## Build build/Cycle.app (CONFIG=release by default; CONFIG=debug for debug)
	@set -euo pipefail; \
	swift build -c $(CONFIG); \
	bin=$$(swift build -c $(CONFIG) --show-bin-path); \
	rm -rf "$(APP)"; \
	mkdir -p "$(APP)/Contents/MacOS" "$(APP)/Contents/Resources"; \
	cp "$$bin/Cycle" "$(APP)/Contents/MacOS/Cycle"; \
	cp Support/Info.plist "$(APP)/Contents/Info.plist"; \
	cp Support/AppIcon.icns "$(APP)/Contents/Resources/"; \
	build_number=$$(git rev-list --count HEAD 2>/dev/null || echo 1); \
	/usr/libexec/PlistBuddy \
		-c "Set :CFBundleShortVersionString $(VERSION)" \
		-c "Set :CFBundleVersion $$build_number" \
		"$(APP)/Contents/Info.plist"; \
	xattr -cr "$(APP)"; \
	if [ -n "$${CYCLE_SIGN_IDENTITY:-}" ]; then \
		codesign --force --sign "$$CYCLE_SIGN_IDENTITY" "$(APP)"; \
	else \
		codesign --force --sign - --identifier $(BUNDLE_ID) \
			--requirements '=designated => identifier "$(BUNDLE_ID)"' "$(APP)"; \
	fi; \
	echo "Built $(APP) ($(VERSION) build $$build_number)"
# The version comes from VERSION and the build number counts commits. A stable signing
# identity (CYCLE_SIGN_IDENTITY) keeps the Accessibility grant across rebuilds; otherwise the
# app is signed ad hoc with a designated requirement of just the bundle id, so the grants
# still match after each rebuild (the default ad hoc requirement is the changing cdhash).

b: build

run: build ## Build, quit any running copy, and open the fresh build
	-@pkill -x Cycle
	@open "$(APP)"

r: run

reset-permissions: ## Reset Cycle's Accessibility and Screen Recording grants
	-tccutil reset Accessibility $(BUNDLE_ID)
	-tccutil reset ScreenCapture $(BUNDLE_ID)

icon: ## Rebuild Support/AppIcon.icns from Support/Icons/<NAME>.svg (NAME=cycle-minimal)
	@set -euo pipefail; \
	tmp=$$(mktemp -d); \
	mkdir -p "$$tmp/AppIcon.iconset"; \
	qlmanage -t -s 1024 -o "$$tmp" "Support/Icons/$(NAME).svg" >/dev/null 2>&1; \
	src="$$tmp/$(NAME).svg.png"; \
	for sz in 16 32 128 256 512; do \
		sips -z $$sz $$sz "$$src" --out "$$tmp/AppIcon.iconset/icon_$${sz}x$${sz}.png" >/dev/null; \
		d=$$((sz * 2)); \
		sips -z $$d $$d "$$src" --out "$$tmp/AppIcon.iconset/icon_$${sz}x$${sz}@2x.png" >/dev/null; \
	done; \
	iconutil -c icns "$$tmp/AppIcon.iconset" -o Support/AppIcon.icns; \
	echo "Wrote Support/AppIcon.icns from $(NAME)"; \
	rm -rf "$$tmp"

package: build ## Zip the app as build/Cycle-<version>.zip and print its SHA-256
	@rm -f "$(ZIP)"
	@ditto -c -k --sequesterRsrc --keepParent "$(APP)" "$(ZIP)"
	@shasum -a 256 "$(ZIP)"

release: package ## Publish v<VERSION> on GitHub and update the Homebrew tap
	@set -euo pipefail; \
	sha=$$(shasum -a 256 "$(ZIP)" | cut -d' ' -f1); \
	if ! git diff --quiet || ! git diff --cached --quiet; then \
		echo "Commit your changes before releasing."; exit 1; \
	fi; \
	git push origin HEAD; \
	gh release create "v$(VERSION)" "$(ZIP)" --repo $(GITHUB) \
		--title "Cycle $(VERSION)" --notes "Install with: brew install --cask zmscode/cycle/cycle"; \
	rm -rf build/tap; \
	gh repo clone $(TAP) build/tap; \
	git -C build/tap config user.name "$$(git config user.name)"; \
	git -C build/tap config user.email "$$(git config user.email)"; \
	mkdir -p build/tap/Casks; \
	sed -e 's/^  version ".*"/  version "$(VERSION)"/' -e "s/^  sha256 \".*\"/  sha256 \"$$sha\"/" \
		Casks/cycle.rb > build/tap/Casks/cycle.rb; \
	cd build/tap; \
	git add Casks/cycle.rb; \
	git commit -m "Cycle $(VERSION)" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"; \
	git push; \
	echo "Released Cycle $(VERSION): brew install --cask zmscode/cycle/cycle"
# release clones the tap, fills Casks/cycle.rb with this version and checksum, and commits
# as the same author as this repo.
