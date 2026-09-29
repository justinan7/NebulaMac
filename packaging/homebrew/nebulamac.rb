# Copy to github.com/justinan7/homebrew-tap as Casks/nebulamac.rb after each release.
# `make release` updates version and sha256 here.
cask "nebulamac" do
  version "1.1.0"
  sha256 "0000000000000000000000000000000000000000000000000000000000000000"

  url "https://github.com/justinan7/NebulaMac/releases/download/v#{version}/NebulaMac-#{version}.zip"
  name "NebulaMac"
  desc "Menu bar app for Nebula mesh networks"
  homepage "https://github.com/justinan7/NebulaMac"

  depends_on macos: ">= :sonoma"
  depends_on formula: "nebula"

  app "NebulaMac.app"

  zap trash: "~/Library/Preferences/io.github.justinan7.NebulaMac.plist"
end
