# NebulaMac

A native macOS menu bar app for connecting to self-hosted [Nebula](https://github.com/slackhq/nebula) mesh networks — one or several at the same time.

No dock icon, no main window: a menu bar swirl that shows each network's state, with a switch per network, peer list, lighthouse latency and certificate expiry.

## Features

- **Several meshes at once** — one config per network (e.g. `work`, `home`), each with its own on/off switch in the menu and in Settings
- **Swirl icon, one arm per network** — bright = connected, faint = off, pulsing = connecting, broken arm = error; the core glows while anything is up. Settings can switch to a classic three-arm icon that stays lit while any network is connected
- **Never mixes meshes up** — each mesh's IP is read from its host certificate and matched exactly to its `utun` interface
- **Certificate expiry** — Settings always shows it; the menu shows it once fewer than 90 days remain (orange under 30, red when expired)
- **Config checks** — warns when two meshes pin the same `tun.dev` or carry the same certificate IP
- **Live status** — lighthouse latency and connected peers
- **Passwordless (optional)** — a helper script installs a sudoers rule scoped to exactly the commands NebulaMac runs; otherwise macOS asks for your password
- **Auto-connect, launch at login, notifications**

## Requirements

- macOS 14 or later
- [Nebula](https://github.com/slackhq/nebula/releases) **`nebula`** and **`nebula-cert`** from the same release. The defaults are `/usr/local/bin/nebula` and `/usr/local/bin/nebula-cert`; with Homebrew (`brew install nebula`) they live in `/opt/homebrew/bin/` — set both paths in Settings.
  `nebula-cert` is how NebulaMac reads each mesh's IP and expiry. Without it the app still connects, but can't tell meshes apart or show expiry.
- A Nebula host certificate, key and CA for each network (from whoever runs your mesh)
- Full **Xcode** to build (the asset catalog needs `actool`; the Command Line Tools alone aren't enough). The Makefile finds `/Applications/Xcode.app` or `Xcode-beta.app` automatically.

## Install (build from source)

```bash
git clone https://github.com/justinan7/NebulaMac.git
cd NebulaMac
make install          # builds a release .app and copies it to /Applications
open /Applications/NebulaMac.app
```

The app isn't signed or notarized; building it yourself avoids Gatekeeper prompts.

Other commands:

```bash
swift run             # run from the checkout
make test             # unit tests (Swift Testing) + install-sudoers dry-run tests + shellcheck
```

## Configuration

### One network

Put your Nebula config at `~/.nebula/config.yml` — it shows up as **default**.

### Several networks

One YAML config per network in `~/.nebula/meshes/`, with its certificates in a folder per network:

```
~/.nebula/
├── meshes/
│   ├── work.yml    # pki paths → ~/.nebula/work/
│   └── home.yml    # pki paths → ~/.nebula/home/
├── work/  (ca.crt, host.crt, host.key)
└── home/  (ca.crt, host.crt, host.key)
```

`pki.cert` can be a path or an inline PEM block (as Nebula Commander-style managed configs use).

### Adding a network

1. Put the network's `ca.crt`, `host.crt` and `host.key` in `~/.nebula/<name>/`.
2. Copy `docs/examples/mesh.yml.template` to `~/.nebula/meshes/<name>.yml` and fill in your paths and lighthouse.
   Use **absolute paths** (nebula runs as root and doesn't expand `~`), keep `listen.port: 0`, and leave `tun.dev` unset so two meshes can't collide.
3. If you use passwordless mode, re-run `scripts/install-sudoers.sh` (until then that network asks for your password).
4. Settings → **Rescan configs**, then switch it on.

Files that don't end in `.yml`/`.yaml` (e.g. `work.yml.disabled`) are ignored.

### Passwordless mode (optional)

```bash
scripts/install-sudoers.sh --dry-run   # preview
scripts/install-sudoers.sh             # install (asks for your password once)
```

It writes `/etc/sudoers.d/nebulamac` allowing **only** the exact commands NebulaMac runs for each config in `~/.nebula/meshes/` (start, stop, force-stop) — nothing broader. The file is validated with `visudo -cf` before it's installed, and any previous version is backed up. Use `--nebula PATH` if your `nebula` isn't in `/usr/local/bin`. Without it, NebulaMac uses the standard macOS administrator dialog.

To check it: `sudo -n -l | grep -F 'nebula -config'` (note that `sudo -n -l <command>` is not a reliable check for admin users).

### Settings

Nebula and `nebula-cert` paths, config directory, per-network switches with certificate expiry, icon style, auto-connect, launch at login, poll interval and notifications.

## How it works

NebulaMac doesn't embed Nebula — it drives the `nebula` binary you installed:

1. **Start:** `sudo -n nebula -config <path>` in the background (so Nebula keeps running if the app quits unexpectedly); if sudo needs a password, it falls back to the macOS administrator dialog.
2. **Status:** reads the mesh IP from the host certificate (`nebula-cert print -json`) and finds the `utun` interface carrying exactly that IP.
3. **Latency:** pings the first lighthouse in the config.
4. **Stop:** `pkill -f 'nebula -config <path>'`, scoped to that one config.

Quitting from the menu disconnects every network. Nebula processes started earlier are picked up again when the app relaunches.

## License

[MIT](LICENSE)
