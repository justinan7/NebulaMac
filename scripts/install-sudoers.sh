#!/bin/bash
# Install /etc/sudoers.d/nebulamac scoped to exactly the commands NebulaMac runs for each
# mesh config in ~/.nebula/meshes/ (start, stop, force-stop). Re-run after adding or
# renaming a mesh; until then NebulaMac falls back to the macOS password prompt.
#
# Usage: scripts/install-sudoers.sh [--dry-run] [--nebula PATH]
# Run as your normal user -- it calls sudo itself. Works with macOS's stock bash 3.2.
set -euo pipefail

NEBULA=/usr/local/bin/nebula
PKILL=/usr/bin/pkill
MESH_DIR="${NEBULAMAC_MESH_DIR:-$HOME/.nebula/meshes}"
TARGET=/etc/sudoers.d/nebulamac
DRY_RUN=0

usage() { sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'; }

while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run) DRY_RUN=1 ;;
        --nebula)
            [ $# -ge 2 ] || { echo "--nebula needs a path" >&2; exit 2; }
            NEBULA="$2"
            shift
            ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
    esac
    shift
done

if [ "$(id -u)" -eq 0 ]; then
    echo "Run this as your normal user (it calls sudo itself), not with sudo." >&2
    exit 2
fi
USER_NAME="$(id -un)"

# Anything sudoers treats specially (space , : = \ ...) is refused rather than escaped.
safe() {
    case "$1" in
        ''|*[!A-Za-z0-9._/-]*) return 1 ;;
        *) return 0 ;;
    esac
}

for value in "$USER_NAME" "$NEBULA"; do
    safe "$value" || { echo "Refusing unsafe value for sudoers: '$value'" >&2; exit 1; }
done

case "$MESH_DIR" in
    /*) ;;
    *) MESH_DIR="$PWD/$MESH_DIR" ;;
esac

configs=()
for f in "$MESH_DIR"/*.yml "$MESH_DIR"/*.yaml; do
    [ -f "$f" ] || continue
    safe "$f" || { echo "Refusing mesh config path sudoers can't take safely: '$f'" >&2; exit 1; }
    configs+=("$f")
done

if [ "${#configs[@]}" -eq 0 ]; then
    echo "No mesh configs (*.yml / *.yaml) in $MESH_DIR -- refusing to install an empty rule." >&2
    exit 1
fi

generate() {
    echo "# Managed by NebulaMac scripts/install-sudoers.sh -- re-run it after adding or renaming a mesh."
    echo "# Exactly the commands NebulaMac runs per mesh: start, stop, force-stop."
    for cfg in "${configs[@]}"; do
        echo "$USER_NAME ALL=(root) NOPASSWD: $NEBULA -config $cfg"
        echo "$USER_NAME ALL=(root) NOPASSWD: $PKILL -f nebula -config $cfg"
        echo "$USER_NAME ALL=(root) NOPASSWD: $PKILL -9 -f nebula -config $cfg"
    done
}

if [ "$DRY_RUN" -eq 1 ]; then
    echo "=== would install to $TARGET ==="
    generate
    echo "=== then: sudo visudo -cf <tmp>; back up $TARGET; sudo install -m 0440 -o root -g wheel <tmp> $TARGET; sudo visudo -c ==="
    exit 0
fi

tmp="$(mktemp -t nebulamac-sudoers)"
trap 'rm -f "$tmp"' EXIT
generate > "$tmp"

echo "Validating with visudo (sudo may ask for your password)..."
sudo /usr/sbin/visudo -cf "$tmp"

if [ -e "$TARGET" ]; then
    # sudo ignores files in sudoers.d whose names contain '.', so this backup is inert.
    backup="/etc/sudoers.d/.nebulamac.bak-$(date +%Y%m%d-%H%M%S)"
    sudo cp -p "$TARGET" "$backup"
    echo "Backed up previous rule to $backup"
fi

sudo install -m 0440 -o root -g wheel "$tmp" "$TARGET"
sudo /usr/sbin/visudo -c
echo "Installed $TARGET for ${#configs[@]} mesh(es)."
# (Not 'sudo -n -l <cmd>': for an admin it exits 0 once any NOPASSWD rule exists.)
echo "Check: sudo -n -l | grep -F '$NEBULA -config ${configs[0]}'"
