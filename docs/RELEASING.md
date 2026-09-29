# Releasing

## One-time setup

1. **Signing certificate:** a "Developer ID Application" certificate in your login Keychain. Check with `security find-identity -v -p codesigning`.
2. **Notary credentials:** create an app-specific password at account.apple.com (under the Apple ID that owns the developer account), then run this in Terminal.app — not an embedded terminal, the password prompt needs a real TTY:

   ```bash
   xcrun notarytool store-credentials nebulamac-notary --apple-id <apple-id> --team-id <team-id>
   ```

   Check: `xcrun notarytool history --keychain-profile nebulamac-notary`.
3. **Homebrew tap:** a public repo `justinan7/homebrew-tap` with a `Casks/` folder.
4. **GitHub CLI:** `gh auth login`.

Different identity or profile name? Pass `SIGN_ID=...` or `NOTARY_PROFILE=...` to make.

## Each release

1. Bump `CFBundleShortVersionString` and `CFBundleVersion` in `NebulaMac/Info.plist`.
2. `make test`
3. `make release` — builds a universal app, signs, notarizes (a few minutes), writes the dmg and zip to `dist/`, and puts the new version and hashes into `packaging/homebrew/nebulamac.rb` and `flake.nix`.
4. Commit `Info.plist`, the cask and `flake.nix`, merge to `main` and push. (The Nix install and the README read `main`.)
5. `make publish` (from `main`) — tags `v<version>` and uploads the dmg and zip to GitHub Releases. It refuses while the hashes are placeholders or uncommitted.
6. Copy `packaging/homebrew/nebulamac.rb` to the tap's `Casks/` and push.
7. Smoke test: open the dmg on another Mac (no Gatekeeper warning) and `brew install --cask justinan7/tap/nebulamac`.

The Nix flake isn't evaluated on the release machine (no Nix installed); ask a Nix user to run `nix profile install github:justinan7/NebulaMac` after the first release.

## App icon

The icon is drawn from the same swirl geometry as the menu bar icon. After changing `NebulaMacCore/Swirl.swift` or `scripts/generate_icon.swift`, run `make icon` and commit the PNGs.
