APP_NAME = NebulaMac
BUNDLE_ID = io.github.justinan7.NebulaMac
APP_BUNDLE = .build/$(APP_NAME).app
INSTALL_DIR = /Applications
ICONSET_DIR = .build/AppIcon.iconset
ICON_SRC = NebulaMac/Assets.xcassets/AppIcon.appiconset
VERSION := $(shell /usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" NebulaMac/Info.plist)
ARCHS = --arch arm64 --arch x86_64
SIGN_ID ?= Developer ID Application: Justin Nunn (E6YX7F4KUC)
NOTARY_PROFILE ?= nebulamac-notary
DIST = .build/release
ZIP = $(DIST)/$(APP_NAME)-$(VERSION).zip
DMG = $(DIST)/$(APP_NAME)-$(VERSION).dmg

# The asset catalog needs actool, which ships with full Xcode but not the Command Line Tools.
XCODE_DEV ?= $(firstword $(wildcard /Applications/Xcode.app/Contents/Developer /Applications/Xcode-beta.app/Contents/Developer))
ifneq ($(XCODE_DEV),)
export DEVELOPER_DIR ?= $(XCODE_DEV)
endif

# Ask SwiftPM where the release binary is: Xcode's build system and the Command Line Tools
# use different folders. (Recursive '=', so it's only evaluated by targets that need it.)
BUILD_DIR = $(shell DEVELOPER_DIR="$(DEVELOPER_DIR)" swift build -c release $(ARCHS) --show-bin-path)

.PHONY: build bundle install uninstall clean test release publish icon

build:
	swift build -c release $(ARCHS)

bundle: build
	@echo "Creating app bundle..."
	mkdir -p "$(APP_BUNDLE)/Contents/MacOS"
	mkdir -p "$(APP_BUNDLE)/Contents/Resources"
	cp "$(BUILD_DIR)/$(APP_NAME)" "$(APP_BUNDLE)/Contents/MacOS/$(APP_NAME)"
	cp NebulaMac/Info.plist "$(APP_BUNDLE)/Contents/Info.plist"
	cp scripts/install-sudoers.sh "$(APP_BUNDLE)/Contents/Resources/install-sudoers.sh"
	@# Add CFBundleExecutable and CFBundlePackageType if missing
	@/usr/libexec/PlistBuddy -c "Add :CFBundleExecutable string $(APP_NAME)" "$(APP_BUNDLE)/Contents/Info.plist" 2>/dev/null || true
	@/usr/libexec/PlistBuddy -c "Add :CFBundlePackageType string APPL" "$(APP_BUNDLE)/Contents/Info.plist" 2>/dev/null || true
	@# Build .icns from asset catalog PNGs
	@echo "Building app icon..."
	@rm -rf "$(ICONSET_DIR)"
	@mkdir -p "$(ICONSET_DIR)"
	@cp "$(ICON_SRC)/icon_16x16@1x.png"   "$(ICONSET_DIR)/icon_16x16.png"
	@cp "$(ICON_SRC)/icon_16x16@2x.png"   "$(ICONSET_DIR)/icon_16x16@2x.png"
	@cp "$(ICON_SRC)/icon_32x32@1x.png"   "$(ICONSET_DIR)/icon_32x32.png"
	@cp "$(ICON_SRC)/icon_32x32@2x.png"   "$(ICONSET_DIR)/icon_32x32@2x.png"
	@cp "$(ICON_SRC)/icon_128x128@1x.png" "$(ICONSET_DIR)/icon_128x128.png"
	@cp "$(ICON_SRC)/icon_128x128@2x.png" "$(ICONSET_DIR)/icon_128x128@2x.png"
	@cp "$(ICON_SRC)/icon_256x256@1x.png" "$(ICONSET_DIR)/icon_256x256.png"
	@cp "$(ICON_SRC)/icon_256x256@2x.png" "$(ICONSET_DIR)/icon_256x256@2x.png"
	@cp "$(ICON_SRC)/icon_512x512@1x.png" "$(ICONSET_DIR)/icon_512x512.png"
	@cp "$(ICON_SRC)/icon_512x512@2x.png" "$(ICONSET_DIR)/icon_512x512@2x.png"
	@iconutil -c icns -o "$(APP_BUNDLE)/Contents/Resources/AppIcon.icns" "$(ICONSET_DIR)"
	@/usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "$(APP_BUNDLE)/Contents/Info.plist" 2>/dev/null || true
	@rm -rf "$(ICONSET_DIR)"
	@echo "Bundle created at $(APP_BUNDLE)"

install: bundle
	@echo "Installing to $(INSTALL_DIR)..."
	@if [ -d "$(INSTALL_DIR)/$(APP_NAME).app" ]; then \
		rm -rf "$(INSTALL_DIR)/$(APP_NAME).app"; \
	fi
	cp -R "$(APP_BUNDLE)" "$(INSTALL_DIR)/$(APP_NAME).app"
	@echo "Installed $(APP_NAME).app to $(INSTALL_DIR)"
	@echo ""
	@echo "You can now:"
	@echo "  - Launch from Spotlight or Applications folder"
	@echo "  - Enable 'Launch at login' in the app's Settings"

uninstall:
	rm -rf "$(INSTALL_DIR)/$(APP_NAME).app"
	@echo "Uninstalled $(APP_NAME).app"

clean:
	swift package clean
	rm -rf "$(APP_BUNDLE)"

# Signed + notarized zip and dmg; updates the cask and flake hashes. See docs/RELEASING.md.
release: bundle
	rm -rf "$(DIST)" && mkdir -p "$(DIST)"
	codesign --force --options runtime --timestamp --sign "$(SIGN_ID)" "$(APP_BUNDLE)"
	codesign --verify --strict --verbose=2 "$(APP_BUNDLE)"
	@echo "Notarizing app..."
	ditto -c -k --keepParent "$(APP_BUNDLE)" "$(ZIP)"
	xcrun notarytool submit "$(ZIP)" --keychain-profile "$(NOTARY_PROFILE)" --wait
	xcrun stapler staple "$(APP_BUNDLE)"
	rm "$(ZIP)" && ditto -c -k --keepParent "$(APP_BUNDLE)" "$(ZIP)"
	@echo "Building dmg..."
	rm -rf "$(DIST)/dmg" && mkdir -p "$(DIST)/dmg"
	cp -R "$(APP_BUNDLE)" "$(DIST)/dmg/"
	ln -s /Applications "$(DIST)/dmg/Applications"
	hdiutil create -volname "$(APP_NAME)" -srcfolder "$(DIST)/dmg" -format UDZO -ov "$(DMG)"
	rm -rf "$(DIST)/dmg"
	codesign --sign "$(SIGN_ID)" --timestamp "$(DMG)"
	xcrun notarytool submit "$(DMG)" --keychain-profile "$(NOTARY_PROFILE)" --wait
	xcrun stapler staple "$(DMG)"
	spctl -a -vv "$(APP_BUNDLE)"
	xcrun stapler validate "$(DMG)"
	@sha=$$(shasum -a 256 "$(ZIP)" | cut -d' ' -f1); \
	sri="sha256-$$(openssl dgst -sha256 -binary "$(ZIP)" | base64)"; \
	sed -i '' -E "s/^  version \".*\"/  version \"$(VERSION)\"/; s/^  sha256 \".*\"/  sha256 \"$$sha\"/" packaging/homebrew/nebulamac.rb; \
	sed -i '' -E "s|^      version = \".*\";|      version = \"$(VERSION)\";|; s|^      hash = \".*\";|      hash = \"$$sri\";|" flake.nix; \
	echo ""; echo "Release $(VERSION) ready in $(DIST):"; ls -1 "$(DIST)"; \
	echo "zip sha256: $$sha"; echo "zip SRI:    $$sri"; \
	echo "Next: commit packaging/homebrew/nebulamac.rb + flake.nix, then 'make publish'."

# Tag and upload to GitHub Releases (public).
publish:
	@test -f "$(ZIP)" -a -f "$(DMG)" || { echo "Run 'make release' first."; exit 1; }
	git tag -a "v$(VERSION)" -m "NebulaMac $(VERSION)"
	git push origin "v$(VERSION)"
	gh release create "v$(VERSION)" "$(DMG)" "$(ZIP)" --title "NebulaMac $(VERSION)" --generate-notes

icon:
	mkdir -p .build
	swiftc -parse-as-library -o .build/generate_icon NebulaMacCore/Swirl.swift scripts/generate_icon.swift
	.build/generate_icon "$(ICON_SRC)"

test:
	swift test
	shellcheck scripts/install-sudoers.sh Tests/scripts/install-sudoers-test.sh
	bash Tests/scripts/install-sudoers-test.sh
