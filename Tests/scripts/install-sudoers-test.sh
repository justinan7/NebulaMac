#!/bin/bash
# Dry-run tests for scripts/install-sudoers.sh -- never touches the real system.
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
script="$root/scripts/install-sudoers.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }

# Two meshes -> exactly six rules naming each absolute config path; other files ignored.
mkdir -p "$tmp/two"
touch "$tmp/two/work.yml" "$tmp/two/home.yaml" "$tmp/two/notes.txt" "$tmp/two/home.yml.disabled"
out="$(NEBULAMAC_NEBULA_SEARCH="$tmp/nope" NEBULAMAC_MESH_DIR="$tmp/two" "$script" --dry-run)"
[ "$(printf '%s\n' "$out" | grep -c 'NOPASSWD:')" -eq 6 ] || fail "expected 6 rules, got: $out"
printf '%s\n' "$out" | grep -qF "NOPASSWD: /usr/local/bin/nebula -config $tmp/two/work.yml" || fail "missing start rule"
printf '%s\n' "$out" | grep -qF "NOPASSWD: /usr/bin/pkill -f nebula -config $tmp/two/work.yml" || fail "missing stop rule"
printf '%s\n' "$out" | grep -qF "NOPASSWD: /usr/bin/pkill -9 -f nebula -config $tmp/two/home.yaml" || fail "missing force-stop rule"
if printf '%s\n' "$out" | grep -q 'home.yml.disabled'; then fail ".disabled file produced a rule"; fi

# --nebula override.
out="$(NEBULAMAC_MESH_DIR="$tmp/two" "$script" --dry-run --nebula /opt/homebrew/bin/nebula)"
printf '%s\n' "$out" | grep -qF "NOPASSWD: /opt/homebrew/bin/nebula -config $tmp/two/work.yml" || fail "--nebula ignored"

# A path with a space is refused.
mkdir -p "$tmp/with space"
touch "$tmp/with space/a.yml"
if NEBULAMAC_MESH_DIR="$tmp/with space" "$script" --dry-run >/dev/null 2>&1; then fail "space in path accepted"; fi

# No meshes -> refused (never install an empty rule).
mkdir -p "$tmp/empty"
if NEBULAMAC_MESH_DIR="$tmp/empty" "$script" --dry-run >/dev/null 2>&1; then fail "empty mesh dir accepted"; fi

# Unknown argument -> usage error.
if "$script" --bogus >/dev/null 2>&1; then fail "unknown argument accepted"; fi

# Default --nebula is auto-detected from the search list.
mkdir -p "$tmp/bin"
printf '#!/bin/sh\n' > "$tmp/bin/nebula"
chmod +x "$tmp/bin/nebula"
out="$(NEBULAMAC_NEBULA_SEARCH="$tmp/nope:$tmp/bin" NEBULAMAC_MESH_DIR="$tmp/two" "$script" --dry-run)"
printf '%s\n' "$out" | grep -qF "NOPASSWD: $tmp/bin/nebula -config $tmp/two/work.yml" || fail "nebula not auto-detected"

# Nothing found -> falls back to /usr/local/bin/nebula.
out="$(NEBULAMAC_NEBULA_SEARCH="$tmp/nope" NEBULAMAC_MESH_DIR="$tmp/two" "$script" --dry-run)"
printf '%s\n' "$out" | grep -qF "NOPASSWD: /usr/local/bin/nebula -config" || fail "fallback default wrong"

echo "install-sudoers tests: OK"
