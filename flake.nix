{
  description = "NebulaMac - macOS menu bar app for Nebula mesh networks";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs = { self, nixpkgs }:
    let
      # `make release` updates these two lines.
      version = "1.1.0";
      hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
      systems = [ "aarch64-darwin" "x86_64-darwin" ];
      forAll = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in {
      packages = forAll (pkgs: {
        default = pkgs.stdenvNoCC.mkDerivation {
          pname = "nebulamac";
          inherit version;
          # The signed, notarized release build (building from source needs Xcode).
          src = pkgs.fetchurl {
            url = "https://github.com/justinan7/NebulaMac/releases/download/v${version}/NebulaMac-${version}.zip";
            inherit hash;
          };
          nativeBuildInputs = [ pkgs.unzip ];
          sourceRoot = ".";
          installPhase = ''
            mkdir -p $out/Applications
            cp -R NebulaMac.app $out/Applications/
          '';
          # Leave the signed app untouched.
          dontFixup = true;
          meta = {
            description = "Menu bar app for Nebula mesh networks";
            homepage = "https://github.com/justinan7/NebulaMac";
            license = pkgs.lib.licenses.mit;
            platforms = pkgs.lib.platforms.darwin;
          };
        };
      });
    };
}
