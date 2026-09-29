# How NebulaMac works

## Finding Nebula

NebulaMac doesn't embed Nebula — it drives the `nebula` and `nebula-cert` binaries you installed. On launch it looks in `/opt/homebrew/bin`, `/usr/local/bin`, `~/.nix-profile/bin` and `/run/current-system/sw/bin`, unless the path in Settings → Advanced already works.

`nebula-cert` is how the app reads each network's IP and certificate expiry. Without it, connecting still works, but the app can't tell networks apart or warn about expiry.

## Config layout

One network: `~/.nebula/config.yml` (shows up as **default**).

Several networks: one YAML config per network in `~/.nebula/meshes/`, certificates in a folder per network:

```
~/.nebula/
├── meshes/
│   ├── work.yml    # pki paths → ~/.nebula/work/
│   └── home.yml    # pki paths → ~/.nebula/home/
├── work/  (ca.crt, host.crt, host.key)
└── home/  (ca.crt, host.crt, host.key)
```

- Use **absolute paths** in configs — nebula runs as root and doesn't expand `~`.
- Keep `listen.port: 0` and leave `tun.dev` unset so two networks can't collide. The app warns if two configs pin the same `tun.dev` or carry the same certificate IP.
- `pki.cert` can be a path or an inline PEM block (as Nebula Commander's generated configs use).
- Files that don't end in `.yml` / `.yaml` (e.g. `work.yml.disabled`) are ignored.

## Connecting

1. **Start:** `sudo -n nebula -config <path>` in the background, so Nebula keeps running if the app quits unexpectedly. If sudo needs a password, it falls back to the macOS administrator dialog.
2. **Status:** reads the network IP from the host certificate (`nebula-cert print -json`) and finds the `utun` interface carrying exactly that IP.
3. **Latency:** pings the first lighthouse in the config.
4. **Stop:** `pkill -f 'nebula -config <path>'`, scoped to that one config.

Quitting from the menu disconnects every network. Nebula processes started earlier are picked up again when the app relaunches.

## Passwordless mode

The command shown in Settings → Advanced runs `install-sudoers.sh` (shipped inside the app; also at `scripts/install-sudoers.sh` in this repo):

```bash
install-sudoers.sh --dry-run            # preview
install-sudoers.sh                      # install (asks for your password once)
install-sudoers.sh --nebula /path/nebula
```

It writes `/etc/sudoers.d/nebulamac` allowing **only** the exact commands NebulaMac runs for each config in `~/.nebula/meshes/` — start, stop, force-stop — nothing broader. The file is checked with `visudo -cf` before it's installed, and any previous version is backed up. Re-run it after adding or renaming a network.

To check it: `sudo -n -l | grep -F 'nebula -config'`. (`sudo -n -l <command>` is not a reliable check for admin users.)

## Menu bar icon

One swirl arm per network: bright = connected, faint = off, pulsing = connecting, broken arm = error; the core glows while anything is up. Settings → General can switch to a classic three-arm icon that stays lit while any network is connected.

Certificate expiry shows in the menu once fewer than 90 days remain (orange under 30, red when expired); Settings → Networks always shows it.
