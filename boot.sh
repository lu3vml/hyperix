#!/usr/bin/env bash
# =============================================================================
#  HYPRIX — arranque en una línea para un Debian 13 recién instalado
#    wget -qO- https://raw.githubusercontent.com/lu3vml/hyperix/main/boot.sh | bash
#  Instala git, clona el repo en ~/.local/share/hyprix y corre el instalador.
# =============================================================================
set -euo pipefail
HYPRIX_REPO=${HYPRIX_REPO:-https://github.com/lu3vml/hyperix.git}
DEST="$HOME/.local/share/hyprix"
[[ $EUID -ne 0 ]] || { echo "Corrélo como tu usuario, no como root."; exit 1; }
command -v git >/dev/null || sudo apt-get install -y git
if [[ -d $DEST/.git ]]; then git -C "$DEST" pull --ff-only
else mkdir -p "$(dirname "$DEST")"; git clone "$HYPRIX_REPO" "$DEST"; fi
exec bash "$DEST/install.sh" "$@" < /dev/tty
