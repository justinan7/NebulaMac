# NebulaMac

A macOS menu bar app for connecting to [Nebula](https://github.com/slackhq/nebula) mesh networks — one or several at once. Each network gets a switch; the menu bar swirl shows which are up.

## Install

You need macOS 14 or later, and Nebula itself.

**Homebrew** (installs Nebula too):

```bash
brew install --cask justinan7/tap/nebulamac
```

**Download:** get `NebulaMac-<version>.dmg` from [Releases](https://github.com/justinan7/NebulaMac/releases), drag the app to Applications, then install Nebula with `brew install nebula`.

**Nix:**

```bash
nix profile install github:justinan7/NebulaMac
```

With nix-darwin, add `inputs.nebulamac.packages.${system}.default` to `environment.systemPackages`. Install `nebula` from nixpkgs as well.

## Get a mesh

Each network needs a CA certificate, a host certificate and key, and a config file. The easiest way to run your own is **[Nebula Commander](https://github.com/NixRTR/nebula-commander)** — a self-hosted web UI that issues certificates and hands out ready-to-use configs. If someone else runs your mesh, ask them for these files.

## Add a network

1. Put `ca.crt`, `host.crt` and `host.key` in `~/.nebula/<name>/`.
2. Put the config at `~/.nebula/meshes/<name>.yml` (start from [the template](docs/examples/mesh.yml.template)). Use full paths, not `~`.
3. In NebulaMac: **Settings → Networks → Rescan Configs**, then flip the switch.

Only have one network? `~/.nebula/config.yml` works too.

## Skip the password prompt (optional)

Connecting needs admin rights, so macOS asks for your password each time. To stop that, copy the command from **Settings → Advanced** and run it once in Terminal. It only allows the exact start and stop commands for your networks. Run it again after adding a network.

## Build from source

Needs Xcode.

```bash
git clone https://github.com/justinan7/NebulaMac.git && cd NebulaMac
make install     # builds and copies to /Applications
make test
```

More: [how it works](docs/how-it-works.md) · [releasing](docs/RELEASING.md) · [MIT license](LICENSE)
