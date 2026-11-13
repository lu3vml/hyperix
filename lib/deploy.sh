#!/usr/bin/env bash
# =============================================================================
#  lib/deploy.sh — copia HYPRIX desde el repo a tu usuario
#  Lo usan install.sh y hyprix-update. No usa sudo.
#
#  · Scripts, temas, plantillas y configs de HYPRIX: se actualizan siempre
#    (si cambiaste alguno a mano, queda una copia en ~/.config/hyprix/backup/)
#  · Tus archivos (user.conf, hyprix.conf, settings.conf): se crean sólo si faltan
# =============================================================================
set -euo pipefail
REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
H="$HOME/.config/hyprix"; BIN="$HOME/.local/bin"; CFG="$HOME/.config"
BK="$H/backup/$(date +%Y%m%d-%H%M%S)"
QUIET=0; [[ ${1:-} == -q ]] && QUIET=1
changed=0; saved=0

say() { ((QUIET)) || echo "$@"; }

# inst ORIGEN DESTINO [modo] — copia si cambió, respaldando la versión anterior
inst() {
  local src=$1 dst=$2 mode=${3:-644}
  if [[ -f $dst ]] && cmp -s "$src" "$dst"; then return 0; fi
  if [[ -f $dst ]]; then
    mkdir -p "$BK/$(dirname "${dst#"$HOME"/}")"; cp -a "$dst" "$BK/${dst#"$HOME"/}"; saved=$((saved + 1))
  fi
  install -D -m "$mode" "$src" "$dst"; changed=$((changed + 1))
}
# inst_once ORIGEN DESTINO — sólo si no existe (archivos tuyos)
inst_once() { [[ -e $2 ]] || { install -D -m 644 "$1" "$2"; changed=$((changed + 1)); }; }

mkdir -p "$BIN" "$H/themes" "$H/templates" "$H/current" "$H/backgrounds"

# --- scripts ---
for f in "$REPO"/bin/*; do inst "$f" "$BIN/$(basename "$f")" 755; done
# --- temas y plantillas ---
for f in "$REPO"/themes/*.theme; do inst "$f" "$H/themes/$(basename "$f")"; done
inst "$REPO/templates/waybar.css" "$H/templates/waybar.css"
# barra: el sensor de temperatura depende del procesador
tmp=$(mktemp); cp "$REPO/templates/waybar.jsonc" "$tmp"
if grep -q AuthenticAMD /proc/cpuinfo 2>/dev/null; then
  sed -i 's|"hwmon-path-abs": "/sys/devices/platform/coretemp.0/hwmon"|"hwmon-path-abs": "/sys/devices/pci0000:00/0000:00:18.3/hwmon"|' "$tmp"
fi
inst "$tmp" "$H/templates/waybar.jsonc"; rm -f "$tmp"

# --- configs de HYPRIX ---
for f in hyprland.conf bindings.conf rules.conf workflow.conf hyprlock.conf; do
  inst "$REPO/config/hypr/$f" "$CFG/hypr/$f"
done

inst "$REPO/config/fontconfig/fonts.conf" "$CFG/fontconfig/fonts.conf"
inst "$REPO/config/nautilus/Usar como fondo de pantalla" \
     "$HOME/.local/share/nautilus/scripts/Usar como fondo de pantalla" 755

# --- archivos que después ajustan hyprix-theme / hyprix-config: sólo si faltan ---
inst_once "$REPO/config/udiskie/config.yml"  "$CFG/udiskie/config.yml"
inst_once "$REPO/config/gtk-3.0/settings.ini" "$CFG/gtk-3.0/settings.ini"
inst_once "$REPO/config/gtk-4.0/settings.ini" "$CFG/gtk-4.0/settings.ini"

# --- tus archivos ---
inst_once "$REPO/config/hypr/user.conf"     "$CFG/hypr/user.conf"
inst_once "$REPO/config/hyprix/hyprix.conf" "$H/hyprix.conf"

# --- cosas que dependen de tu usuario ---
PICS=$(xdg-user-dir PICTURES 2>/dev/null || echo "$HOME/Pictures")
if [[ ! -f "$CFG/swappy/config" ]]; then
  mkdir -p "$CFG/swappy"
  cat > "$CFG/swappy/config" <<EOF
[Default]
save_dir=$PICS/Capturas
save_filename_format=captura-%Y%m%d-%H%M%S-editada.png
show_panel=true
line_size=4
text_size=18
text_font=Inter
paint_mode=arrow
early_exit=true
fill_shape=false
auto_save=false
EOF
fi
mkdir -p "$PICS/Fondos"
[[ -e "$PICS/Fondos/Fondos de los temas HYPRIX" ]] || ln -s "$H/backgrounds" "$PICS/Fondos/Fondos de los temas HYPRIX"
mkdir -p "$CFG/imv"
grep -qs 'hyprix-bg set' "$CFG/imv/config" || cat >> "$CFG/imv/config" <<'EOF'
[binds]
# Shift+W: usar la imagen que estás viendo como fondo de pantalla
<Shift+W> = exec ~/.local/bin/hyprix-bg set "$imv_current_file"
EOF

# --- scripts y temas que ya no están en el repo: se sacan (con respaldo) ---
MAN="$H/deployed.list"; NEW=$(mktemp)
{ for f in "$REPO"/bin/*; do echo "$BIN/$(basename "$f")"; done
  for f in "$REPO"/themes/*.theme; do echo "$H/themes/$(basename "$f")"; done; } | sort > "$NEW"
if [[ -f $MAN ]]; then
  while IFS= read -r old; do
    [[ -e $old ]] || continue
    mkdir -p "$BK/$(dirname "${old#"$HOME"/}")"; mv "$old" "$BK/${old#"$HOME"/}"
    saved=$((saved + 1)); changed=$((changed + 1))
  done < <(comm -23 "$MAN" "$NEW")
fi
mv "$NEW" "$MAN"

# --- dónde está el repo y qué versión hay ---
echo "$REPO" > "$H/repo-path"
cp "$REPO/VERSION" "$H/version" 2>/dev/null || true

say "  $changed archivos actualizados$( ((saved)) && echo " · tus versiones anteriores quedaron en ${BK/#$HOME/\~}")"
