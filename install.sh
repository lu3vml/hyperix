#!/usr/bin/env bash
# =============================================================================
#  HYPRIX — entorno tipo Omarchy (Hyprland) para Debian 13 "trixie"
#  Probado en MacBook Air A1466; detecta el hardware y sirve en otras PCs.
#  Instalación limpia SIN escritorio (sólo "utilidades estándar del sistema").
#
#  Uso:   bash install.sh            (te hace unas preguntas al inicio)
#         bash install.sh -y         (todo por defecto, sin preguntas)
#  Después, para actualizar:  hyprix-update
#  Opciones:
#         --tema NOMBRE     tokyo-night, nord, dracula, everforest… (lista completa: --temas)
#         --autologin       entrar sin pedir usuario en tty1
#         --sin-compilar    no compilar extras: mezclador de audio y fundidos de fondo (ahorra ~15 min)
#         --sin-fondos      no bajar fondos de Omarchy y la comunidad
#  Log:   ~/hyprix-install.log
# =============================================================================
set -euo pipefail
REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
[[ -f $REPO/lib/deploy.sh ]] || { echo "Corré install.sh desde la carpeta del repo de HYPRIX (git clone …)."; exit 1; }

# ----------------------------- OPCIONES --------------------------------------
THEME_DEFAULT="tokyo-night"   # tema inicial (ver --temas)
FNMODE=2                      # teclado Apple: 1 = multimedia directas, 2 = F1-F12 directas
AUTOLOGIN=0                   # 1 = autologin en tty1
WIREMIX=1                     # 1 = compilar extras: wiremix (mezclador TUI) y awww (fundidos de fondo)
WALLS=1                       # 1 = bajar fondos al final (hyprix-walls)
INSTALL_NERDFONT=1            # 1 = JetBrainsMono Nerd Font (íconos de la barra)
ASK=1                         # 0 = no preguntar nada (-y)
THEMES=(tokyo-night gruvbox nord catppuccin fosforo rose-pine dracula everforest kanagawa osaka-jade matte-black ristretto ethereal miasma retro-82 vantablack lumon)

while (($#)); do
  case "$1" in
    -y|--si|--yes) ASK=0 ;;
    --tema)        THEME_DEFAULT=${2:?falta el nombre del tema}; shift ;;
    --autologin)   AUTOLOGIN=1 ;;
    --sin-compilar|--sin-wiremix) WIREMIX=0 ;;
    --sin-fondos)  WALLS=0 ;;
    --temas)       printf '%s\n' "${THEMES[@]}"; exit 0 ;;
    -h|--help)     sed -n '2,15p' "$0"; exit 0 ;;
    *) echo "Opción desconocida: $1 (ver --help)"; exit 1 ;;
  esac
  shift
done
[[ " ${THEMES[*]} " == *" $THEME_DEFAULT "* ]] || { echo "Tema inexistente: $THEME_DEFAULT"; exit 1; }
# -----------------------------------------------------------------------------

LOG="$HOME/hyprix-install.log"
exec > >(tee -a "$LOG") 2>&1

c_ok=$'\e[32m'; c_wr=$'\e[33m'; c_er=$'\e[31m'; c_in=$'\e[36m'; c_0=$'\e[0m'
step() { echo; echo "${c_in}==> $*${c_0}"; }
ok()   { echo "${c_ok}  ✔ $*${c_0}"; }
warn() { echo "${c_wr}  ! $*${c_0}"; }
die()  { echo "${c_er}  ✘ $*${c_0}"; exit 1; }
put()  { mkdir -p "$(dirname "$1")"; cat > "$1"; }

# Devuelve sólo los paquetes que existen en los repos (avisa los que faltan)
available() {
  local p
  for p in "$@"; do
    if apt-cache show "$p" >/dev/null 2>&1; then echo "$p"; else warn "no disponible, se omite: $p" >&2; fi
  done
}
apt_install() {
  local pk
  mapfile -t pk < <(available "$@")
  ((${#pk[@]})) || return 0
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "${pk[@]}"
}
apt_install_bpo() {
  local pk
  mapfile -t pk < <(available "$@")
  ((${#pk[@]})) || return 0
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -t trixie-backports "${pk[@]}"
}

# ----------------------------- CHEQUEOS --------------------------------------
step "Chequeos previos"
[[ $EUID -ne 0 ]] || die "Corré el script como tu usuario, no como root."
. /etc/os-release
[[ "${VERSION_CODENAME:-}" == "trixie" ]] || die "Esto es para Debian 13 (trixie). Detectado: ${PRETTY_NAME:-?}"
[[ $(dpkg --print-architecture) == amd64 ]] || die "Sólo para PCs de 64 bits (amd64)."

# Hardware
HW_VENDOR=$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null || echo "?")
HW_MODEL=$(cat /sys/class/dmi/id/product_name 2>/dev/null || echo "?")
IS_APPLE=0; [[ $HW_VENDOR == Apple* ]] && IS_APPLE=1
CPU=other
grep -q GenuineIntel /proc/cpuinfo && CPU=intel
grep -q AuthenticAMD /proc/cpuinfo && CPU=amd
IS_LAPTOP=0; compgen -G '/sys/class/power_supply/BAT*' >/dev/null && IS_LAPTOP=1
ok "Equipo: $HW_VENDOR $HW_MODEL · CPU $CPU$( ((IS_LAPTOP)) && echo ' · notebook')"

# Preguntas (sólo si hay terminal y no se pasó -y)
ask() { # ask "pregunta" default → respuesta en $REPLY
  local q=$1 d=$2
  printf '%s' "${c_in}  ? ${c_0}$q [$d]: " > /dev/tty
  IFS= read -r REPLY < /dev/tty || REPLY=""
  REPLY=${REPLY:-$d}
}
say() { printf '%s\n' "$*" > /dev/tty; }
yes_no() { ask "$1" "$2"; [[ ${REPLY,,} == s* || ${REPLY,,} == y* ]]; }

if ((ASK)) && [[ -t 0 || -e /dev/tty ]] && { : > /dev/tty; } 2>/dev/null; then
  say ""
  say "  Temas:"
  for i in "${!THEMES[@]}"; do printf '    %2d) %-13s' "$((i + 1))" "${THEMES[$i]}" > /dev/tty; (( (i + 1) % 4 == 0 )) && say ""; done; say ""
  ask "Tema inicial (número)" "1"
  if [[ $REPLY =~ ^[0-9]+$ ]] && ((REPLY >= 1 && REPLY <= ${#THEMES[@]})); then THEME_DEFAULT=${THEMES[$((REPLY - 1))]}; fi
  if ((IS_APPLE)); then
    say "  Teclas de función: 1) F1-F12 directas, brillo/volumen con Fn   2) brillo/volumen directos, F1-F12 con Fn"
    ask "Teclas de función" "1"
    [[ $REPLY == 2 ]] && FNMODE=1 || FNMODE=2
  fi
  if yes_no "¿Entrar sin pedir usuario (autologin)? s/n" "n"; then AUTOLOGIN=1; else AUTOLOGIN=0; fi
  if yes_no "¿Compilar extras: mezclador de audio y fundidos de fondo (~15 min)? s/n" "s"; then WIREMIX=1; else WIREMIX=0; fi
  if yes_no "¿Bajar fondos de Omarchy y la comunidad al final (~50 MB)? s/n" "s"; then WALLS=1; else WALLS=0; fi
  say ""
  say "  Resumen: tema $THEME_DEFAULT · autologin $( ((AUTOLOGIN)) && echo sí || echo no) · compilar extras $( ((WIREMIX)) && echo sí || echo no) · fondos $( ((WALLS)) && echo sí || echo no)"
  yes_no "¿Arranco? s/n" "s" || { echo "Cancelado."; exit 0; }
fi

if ! command -v sudo >/dev/null || ! sudo -v; then
  die "Tu usuario no tiene sudo. Ejecutá:  su -c 'apt install -y sudo && usermod -aG sudo $USER'  y volvé a iniciar sesión."
fi
# mantener sudo vivo durante la instalación
( while true; do sudo -n true; sleep 50; kill -0 "$$" 2>/dev/null || exit; done ) 2>/dev/null &
ok "Debian 13, usuario $USER con sudo"

# Internet (sin depender de curl, que todavía no está)
if ! getent hosts deb.debian.org >/dev/null 2>&1 \
   || ! timeout 10 bash -c 'exec 3<>/dev/tcp/deb.debian.org/80' 2>/dev/null; then
  die "Sin internet. Conectá un cable (USB-Ethernet o el celular por USB) y volvé a correr el script.$( ((IS_APPLE)) && echo ' La WiFi de la Mac anda recién después de instalar el driver.')"
fi
ok "Internet OK"

# ----------------------------- REPOS -----------------------------------------
step "Repositorios: contrib, non-free, non-free-firmware y backports"
if [[ -f /etc/apt/sources.list ]]; then
  sudo cp -n /etc/apt/sources.list /etc/apt/sources.list.hyprix.bak || true
  sudo sed -i -E 's/^(deb cdrom:)/# \1/' /etc/apt/sources.list
  sudo sed -i -E '/^deb(-src)? .*trixie/ s/ main( .*)?$/ main contrib non-free non-free-firmware/' /etc/apt/sources.list
fi
if [[ -f /etc/apt/sources.list.d/debian.sources ]]; then
  sudo sed -i -E 's/^Components:.*/Components: main contrib non-free non-free-firmware/' /etc/apt/sources.list.d/debian.sources
fi
if ! grep -rqsE 'deb\.debian\.org|ftp\..*debian\.org|security\.debian\.org' /etc/apt/sources.list /etc/apt/sources.list.d/; then
  warn "No hay mirror de red configurado (¿instalaste desde DVD?). Agrego deb.debian.org"
  sudo tee /etc/apt/sources.list.d/debian.sources >/dev/null <<'XEOF'
Types: deb
URIs: http://deb.debian.org/debian
Suites: trixie trixie-updates
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

Types: deb
URIs: http://security.debian.org/debian-security
Suites: trixie-security
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
XEOF
fi
sudo tee /etc/apt/sources.list.d/hyprix-backports.sources >/dev/null <<'XEOF'
Types: deb
URIs: http://deb.debian.org/debian
Suites: trixie-backports
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
XEOF
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get -y full-upgrade
apt_install pciutils curl wget ca-certificates xz-utils unzip git dbus-user-session
ok "Repos listos"

# ----------------------------- HARDWARE --------------------------------------
step "Hardware: $HW_VENDOR $HW_MODEL"
apt_install linux-headers-amd64 firmware-misc-nonfree power-profiles-daemon rfkill
case $CPU in
  intel) apt_install intel-microcode intel-media-va-driver i965-va-driver thermald
         sudo systemctl enable thermald 2>/dev/null || true ;;
  amd)   apt_install amd64-microcode firmware-amd-graphics mesa-va-drivers ;;
esac
sudo systemctl enable power-profiles-daemon 2>/dev/null || true

# WiFi según la placa
NET=$(lspci -nn 2>/dev/null | grep -iE 'network controller|wireless' || true)
if   grep -qi '14e4:43a0' <<<"$NET"; then
  ok "WiFi Broadcom BCM4360 → broadcom-sta-dkms (driver wl)"; apt_install broadcom-sta-dkms
elif grep -qiE '14e4:(4331|4353)' <<<"$NET"; then
  ok "WiFi Broadcom BCM4331/43224 → firmware b43"; apt_install firmware-b43-installer
elif grep -qi '14e4:' <<<"$NET"; then
  ok "WiFi Broadcom → firmware-brcm80211"; apt_install firmware-brcm80211
elif grep -qi 'intel' <<<"$NET"; then
  ok "WiFi Intel → firmware-iwlwifi"; apt_install firmware-iwlwifi
elif grep -qi 'realtek' <<<"$NET"; then
  ok "WiFi Realtek → firmware-realtek"; apt_install firmware-realtek
elif grep -qiE 'atheros|qualcomm' <<<"$NET"; then
  ok "WiFi Atheros → firmware-atheros"; apt_install firmware-atheros
else
  ok "Sin placa WiFi PCI reconocida (nada que instalar)"
fi

if ((IS_APPLE)); then
  apt_install mbpfan
  echo "options hid_apple fnmode=${FNMODE}" | sudo tee /etc/modprobe.d/hid_apple.conf >/dev/null
  sudo update-initramfs -u
  sudo systemctl enable mbpfan 2>/dev/null || true
  ok "Mac: ventiladores (mbpfan) y teclado Apple (fnmode=$FNMODE)"
fi
sudo usermod -aG video,input "$USER"

# ----------------------------- PAQUETES --------------------------------------
step "Hyprland desde trixie-backports"
apt_install_bpo hyprland hyprlock hypridle hyprpolkitagent \
                xdg-desktop-portal-hyprland hyprland-guiutils hyprsunset
command -v hyprsunset >/dev/null || apt_install gammastep
command -v Hyprland >/dev/null || die "Hyprland no se instaló. Revisá $LOG"
ok "Hyprland $(Hyprland --version 2>/dev/null | head -n1 | awk '{print $2}')"

step "Escritorio, audio, red y herramientas"
# Se instala con -t trixie-backports: Hyprland arrastra libs nuevas (pipewire,
# xkbcommon, atk) y el resto tiene que alinearse a esas versiones.
apt_install_bpo \
  nano network-manager bluez blueman \
  pipewire pipewire-pulse pipewire-alsa wireplumber pavucontrol \
  brightnessctl playerctl libnotify-bin \
  waybar fuzzel mako-notifier swaybg grim slurp wl-clipboard cliphist \
  foot nautilus gvfs gvfs-backends ffmpegthumbnailer imv zenity mpv firefox-esr imagemagick \
  xdg-desktop-portal-gtk xdg-user-dirs qt6-wayland qtwayland5 \
  adwaita-icon-theme gnome-themes-extra \
  fonts-inter fonts-jetbrains-mono fonts-cascadia-code fonts-firacode fonts-hack fonts-ibm-plex fonts-ubuntu fonts-roboto fonts-dejavu fonts-font-awesome fonts-noto fonts-noto-color-emoji \
  papirus-icon-theme qt6-gtk-platformtheme qt5-gtk-platformtheme \
  qalc libgtk-3-bin pulsemixer papers gnome-text-editor file-roller udiskie swappy p7zip-full unrar-free \
  neovim btop fastfetch fzf ripgrep fd-find bat eza zoxide
sudo systemctl enable NetworkManager bluetooth 2>/dev/null || true
sudo update-alternatives --set editor /bin/nano >/dev/null 2>&1 || true
[[ -f "$HOME/.nanorc" ]] || printf 'include "/usr/share/nano/*.nanorc"\nset linenumbers\nset mouse\nset softwrap\nset tabsize 4\nset tabstospaces\nset autoindent\nset constantshow\nset indicator\nset zap\n' > "$HOME/.nanorc"
xdg-user-dirs-update || true
xdg-mime default org.gnome.Nautilus.desktop inode/directory 2>/dev/null || true
apt-cache show papers >/dev/null 2>&1 || apt_install evince
first_app() { # devuelve el primer .desktop instalado de la lista
  local d
  for d in "$@"; do
    for dir in "$HOME/.local/share/applications" /usr/share/applications; do
      [[ -f "$dir/$d" ]] && { echo "$d"; return 0; }
    done
  done
  return 1
}
setdef() { # setdef "<desktop candidatos>" mime...
  local app; app=$(first_app $1) || { warn "sin app para: ${2}…"; return 0; }
  shift; xdg-mime default "$app" "$@"; echo "    $app ← $# tipos"
}

setdef "org.gnome.Papers.desktop org.gnome.Evince.desktop" \
  application/pdf application/x-pdf application/postscript image/vnd.djvu application/epub+zip

setdef "org.gnome.TextEditor.desktop" \
  text/plain text/markdown text/x-markdown text/x-log text/csv text/x-csv \
  application/json application/xml text/xml application/x-yaml text/x-yaml application/toml \
  application/x-shellscript text/x-shellscript text/x-python text/x-python3 \
  text/x-csrc text/x-chdr text/x-c++src text/x-rust text/x-go text/javascript \
  text/css text/x-ini application/x-desktop text/x-readme application/x-subrip

setdef "org.gnome.FileRoller.desktop" \
  application/zip application/x-tar application/gzip application/x-gzip \
  application/x-compressed-tar application/x-bzip2 application/x-bzip2-compressed-tar \
  application/x-xz application/x-xz-compressed-tar application/zstd application/x-zstd-compressed-tar \
  application/x-7z-compressed application/vnd.rar application/x-rar application/x-rar-compressed

setdef "imv.desktop imv-dir.desktop" \
  image/png image/jpeg image/gif image/webp image/bmp image/tiff image/x-tga \
  image/avif image/heic image/jxl image/svg+xml image/x-portable-pixmap

setdef "mpv.desktop" \
  video/mp4 video/x-matroska video/webm video/quicktime video/x-msvideo video/mpeg video/ogg \
  video/x-flv video/3gpp audio/mpeg audio/mp4 audio/ogg audio/flac audio/x-flac audio/x-wav \
  audio/wav audio/opus audio/aac audio/x-m4a audio/webm

setdef "firefox-esr.desktop firefox.desktop" \
  text/html application/xhtml+xml x-scheme-handler/http x-scheme-handler/https x-scheme-handler/about

setdef "org.gnome.Nautilus.desktop" inode/directory
gsettings set org.gnome.nautilus.preferences default-folder-viewer 'list-view' 2>/dev/null || true
gsettings set org.gnome.nautilus.list-view default-zoom-level 'small' 2>/dev/null || true
ok "Paquetes instalados"

if ((INSTALL_NERDFONT)); then
  step "JetBrainsMono Nerd Font"
  FD="$HOME/.local/share/fonts/JetBrainsMonoNF"
  if [[ ! -d $FD ]]; then
    mkdir -p "$FD"
    if curl -fsSL https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.tar.xz | tar -xJ -C "$FD"; then
      fc-cache -f >/dev/null; ok "Nerd Font instalada"
    else
      rmdir "$FD" 2>/dev/null || true; warn "No pude bajar la Nerd Font; quedan JetBrains Mono + Font Awesome"
    fi
  else ok "Ya estaba instalada"; fi
fi

# ----------------------------- BACKUP CONFIGS --------------------------------
step "Backup de configs previas"
BK="$HOME/.config/hyprix-backup-$(date +%Y%m%d-%H%M%S)"
for d in hypr waybar foot mako fuzzel; do
  if [[ -e "$HOME/.config/$d" ]]; then mkdir -p "$BK"; cp -a "$HOME/.config/$d" "$BK/"; fi
done
[[ -d $BK ]] && ok "Backup en $BK" || ok "Nada que respaldar"

H="$HOME/.config/hyprix"
BIN="$HOME/.local/bin"
mkdir -p "$H/themes" "$H/templates" "$H/current" "$H/backgrounds" "$BIN"

# ----------------------------- ASPECTO: OSD, GTK3, CURSOR, FUNDIDOS ----------
step "OSD, tema GTK3, cursor y transiciones de fondo"
gh_latest() { # repo regex → URL del asset del último release
  curl -fsSL "https://api.github.com/repos/$1/releases/latest" 2>/dev/null \
    | grep -oE '"browser_download_url": *"[^"]+"' | cut -d'"' -f4 | grep -E "$2" | head -n1
}
apt_install_bpo swayosd || true
command -v swayosd-server >/dev/null && ok "swayosd (OSD centrado)" || warn "swayosd no está en los repos: el volumen/brillo sigue con notificación"

apt_install adw-gtk3 || true
if [[ ! -d /usr/share/themes/adw-gtk3-dark && ! -d "$HOME/.local/share/themes/adw-gtk3-dark" ]]; then
  url=$(gh_latest lassekongo83/adw-gtk3 '\.tar\.xz$' || true)
  if [[ -n $url ]] && mkdir -p "$HOME/.local/share/themes" && curl -fsSL "$url" | tar -xJ -C "$HOME/.local/share/themes"; then :; fi
fi
[[ -d /usr/share/themes/adw-gtk3-dark || -d "$HOME/.local/share/themes/adw-gtk3-dark" ]] \
  && ok "adw-gtk3 (apps GTK3 con el estilo de Nautilus)" || warn "Sin adw-gtk3: las apps GTK3 quedan con Adwaita oscuro"

apt_install bibata-cursor-theme || true
if ! compgen -G "/usr/share/icons/Bibata-Modern-Classic/cursors" >/dev/null && [[ ! -d "$HOME/.local/share/icons/Bibata-Modern-Classic" ]]; then
  url=$(gh_latest ful1e5/Bibata_Cursor 'Bibata-Modern-Classic\.tar\.xz$' || true)
  if [[ -n $url ]] && mkdir -p "$HOME/.local/share/icons" && curl -fsSL "$url" | tar -xJ -C "$HOME/.local/share/icons"; then :; fi
fi
[[ -d /usr/share/icons/Bibata-Modern-Classic || -d "$HOME/.local/share/icons/Bibata-Modern-Classic" ]] \
  && ok "Cursor Bibata" || warn "Sin Bibata: queda el cursor Adwaita"

# awww (ex swww): fundido al cambiar fondo. Se compila; si falla, sigue swaybg.
if ((WIREMIX)) && ! command -v awww >/dev/null && ! command -v swww >/dev/null; then
  echo "  compilando awww (fundidos de fondo): puede tardar unos minutos"
  apt_install cargo pkg-config libwayland-dev wayland-protocols liblz4-dev
  src="$HOME/.cache/hyprix-build/awww"; rm -rf "$src"; mkdir -p "$src"
  if curl -fsSL https://codeberg.org/LGFae/awww/archive/v0.12.1.tar.gz | tar -xz -C "$src" --strip-components=1 \
     && (cd "$src" && cargo build --release 2>&1 | tail -n 3) && [[ -x "$src/target/release/awww" ]]; then
    install -m755 "$src/target/release/awww" "$src/target/release/awww-daemon" "$BIN/"
    ok "awww (fundidos de fondo)"
  else
    warn "awww no compiló con el Rust de Debian: el fondo cambia sin fundido (swaybg)"
  fi
  rm -rf "$src"
fi

# ----------------------------- TUIs: BLUETUI Y WIREMIX -----------------------
step "TUIs de Bluetooth y audio"
gh_asset() { # repo → URL del binario linux x86_64 del último release
  curl -fsSL "https://api.github.com/repos/$1/releases/latest" 2>/dev/null \
    | grep -oE '"browser_download_url": *"[^"]+"' | cut -d'"' -f4 \
    | grep -iE 'x86_64|amd64' | grep -iE 'linux|gnu|musl' | grep -viE '\.(sha256|sha512|asc|sig|sbom)' | head -n1
}
if ! command -v bluetui >/dev/null; then
  url=$(gh_asset pythops/bluetui || true)
  if [[ -n $url ]]; then
    tmp=$(mktemp -d)
    if curl -fsSL "$url" -o "$tmp/dl"; then
      case "$url" in
        *.tar.gz|*.tgz) tar -xzf "$tmp/dl" -C "$tmp"; find "$tmp" -type f -name bluetui -exec install -m755 {} "$BIN/bluetui" \; ;;
        *.zip)          unzip -q "$tmp/dl" -d "$tmp"; find "$tmp" -type f -name bluetui -exec install -m755 {} "$BIN/bluetui" \; ;;
        *)              install -m755 "$tmp/dl" "$BIN/bluetui" ;;
      esac
    fi
    rm -rf "$tmp"
  fi
fi
command -v bluetui >/dev/null || [[ -x "$BIN/bluetui" ]] && ok "bluetui" || warn "No pude bajar bluetui; sigue blueman"

# wiremix (opcional: se compila, ~10 min en la Air)
if ((WIREMIX)) && ! command -v wiremix >/dev/null && [[ ! -x "$HOME/.cargo/bin/wiremix" ]]; then
  echo "  compilando wiremix: puede tardar 5-10 minutos"
  apt_install cargo pkg-config clang
  apt_install_bpo libpipewire-0.3-dev || apt_install libpipewire-0.3-dev
  cargo install --locked wiremix 2>&1 | tail -n 3 || true
fi
if [[ -x "$HOME/.cargo/bin/wiremix" ]]; then
  ln -sf "$HOME/.cargo/bin/wiremix" "$BIN/wiremix"; ok "wiremix"
else
  ok "Audio: pulsemixer (TUI)$( ((WIREMIX)) && echo ' — wiremix no compiló con el Rust de Debian')"
fi

# ----------------------------- ARCHIVOS DE HYPRIX ----------------------------
step "Archivos de HYPRIX (scripts, temas, configs)"
bash "$REPO/lib/deploy.sh"
ok "Copiados desde $REPO"

step "Fuentes, GTK y tema"
fc-cache -f >/dev/null
gsettings set org.gnome.desktop.interface font-name 'Inter 9' 2>/dev/null || true
gsettings set org.gnome.desktop.interface monospace-font-name 'JetBrainsMono Nerd Font 9' 2>/dev/null || true
gsettings set org.gnome.desktop.interface font-hinting 'slight' 2>/dev/null || true
gsettings set org.gnome.desktop.interface font-antialiasing 'rgba' 2>/dev/null || true
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null || true

"$BIN/hyprix-theme" "$THEME_DEFAULT" >/dev/null
"$BIN/hyprix-config" --apply >/dev/null
ok "Tema $THEME_DEFAULT aplicado"

step "Fondos de pantalla"
"$BIN/hyprix-wallgen"
FONDOS="$(xdg-user-dir PICTURES 2>/dev/null || echo "$HOME/Pictures")/Fondos"
ok "Tus fondos van en $FONDOS · click derecho → Scripts → Usar como fondo"
first=$(find "$H/backgrounds/$THEME_DEFAULT" -maxdepth 1 -type f 2>/dev/null | sort | head -n1)
[[ -n $first ]] && ln -sfn "$first" "$H/current/wallpaper"   # para la pantalla de bloqueo

# ----------------------------- VERIFICACIÓN ----------------------------------
step "Verificando la configuración de Hyprland"
VERIFY="sin verificar"
if vout=$(timeout 60 Hyprland --verify-config 2>&1); then :; fi
echo "$vout" >> "$LOG"
verrs=$(grep -iE 'error|invalid|does not exist|unknown|failed' <<<"$vout" | grep -viE 'no errors|0 errors' || true)
if [[ -n $verrs ]]; then
  VERIFY="con errores"
  warn "Hyprland reporta problemas en la config:"
  sed 's/^/      /' <<<"$verrs"
  warn "Copiá estas líneas para corregirlas; la sesión arranca igual pero con barra roja."
elif [[ -n $vout ]]; then
  VERIFY="OK"; ok "Config de Hyprland sin errores"
else
  warn "No pude verificar (Hyprland --verify-config no respondió); se ve en el primer inicio"
fi

# ----------------------------- SHELL -----------------------------------------
step "Shell (bash)"
if ! grep -q '# >>> HYPRIX bash' "$HOME/.bashrc" 2>/dev/null; then
  cat >> "$HOME/.bashrc" <<'XEOF'

# >>> HYPRIX bash >>>
export PATH="$HOME/.local/bin:$PATH"
export EDITOR=nano
export VISUAL=nano
command -v eza    >/dev/null && alias ls='eza --group-directories-first' && alias ll='eza -lh --git --group-directories-first' && alias lt='eza --tree --level=2'
command -v batcat >/dev/null && alias bat='batcat'
command -v fdfind >/dev/null && alias fd='fdfind'
command -v zoxide >/dev/null && eval "$(zoxide init bash)"
[[ -f /usr/share/doc/fzf/examples/key-bindings.bash ]] && source /usr/share/doc/fzf/examples/key-bindings.bash
alias tema='hyprix-theme'
# <<< HYPRIX bash <<<
XEOF
fi
ok ".bashrc extendido (eza, bat, fd, zoxide, fzf)"

# ----------------------------- SESIÓN ----------------------------------------
step "Arranque de Hyprland en tty1"
if ! grep -q '# >>> HYPRIX session' "$HOME/.profile" 2>/dev/null; then
  cat >> "$HOME/.profile" <<'XEOF'

# >>> HYPRIX session >>>
# Al loguearte en tty1 arranca Hyprland. Para evitarlo: touch ~/.no-hyprix
if [ -z "${WAYLAND_DISPLAY:-}" ] && [ "$(tty)" = "/dev/tty1" ] && [ ! -e "$HOME/.no-hyprix" ]; then
  exec "$HOME/.local/bin/hyprix-session"
fi
# <<< HYPRIX session <<<
XEOF
fi
if ((AUTOLOGIN)); then
  sudo mkdir -p /etc/systemd/system/getty@tty1.service.d
  sudo tee /etc/systemd/system/getty@tty1.service.d/autologin.conf >/dev/null <<XEOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $USER --noclear %I \$TERM
XEOF
  ok "Autologin activado en tty1"
fi

# ----------------------------- RED -------------------------------------------
step "Red: pasar el control a NetworkManager"
if grep -qE '^\s*(allow-hotplug|auto)\s+(en|eth|wl)' /etc/network/interfaces 2>/dev/null; then
  sudo cp /etc/network/interfaces /etc/network/interfaces.hyprix.bak
  sudo tee /etc/network/interfaces >/dev/null <<'XEOF'
# Gestionado por NetworkManager (backup en interfaces.hyprix.bak)
source /etc/network/interfaces.d/*
auto lo
iface lo inet loopback
XEOF
  ok "ifupdown liberado (backup en /etc/network/interfaces.hyprix.bak)"
else
  ok "Nada que cambiar"
fi

# ----------------------------- FONDOS EXTRA ----------------------------------
if ((WALLS)); then
  step "Fondos de Omarchy y la comunidad"
  "$BIN/hyprix-walls" || warn "No pude bajar todos los fondos; reintentá después con: hyprix-walls"
fi

# ----------------------------- FIN -------------------------------------------
echo
echo "${c_ok}=====================================================${c_0}"
echo "${c_ok}  HYPRIX instalado. Reiniciá:  sudo reboot${c_0}"
echo "${c_ok}=====================================================${c_0}"
cat <<XEOF

  Equipo:      $HW_VENDOR $HW_MODEL (CPU $CPU)
  Tema:        $THEME_DEFAULT
  Config:      $VERIFY

  Después del reinicio:
   1. Logueate en tty1 → arranca Hyprland solo.
   2. WiFi: click en el ícono de red de la barra (o Super+Alt+Espacio → "Red WiFi").

  Atajos clave (Super = Cmd ⌘):
   Super+Enter          terminal          Super+Espacio       lanzador
   Super+Alt+Espacio    menú HYPRIX       Super+Esc           energía
   Super+K              todos los atajos  Super+Ctrl+Shift+Esp  tema
   Super+W              cerrar ventana    Super+Shift+S       captura
   Super+Ctrl+Espacio   elegir fondo      Super+Ctrl+N        luz nocturna
   Super+Coma           configuración

  Actualizar HYPRIX: hyprix-update (o menú HYPRIX → Actualizar HYPRIX)
  Tus cambios: ~/.config/hypr/user.conf
  Fondos por tema: ~/.config/hyprix/backgrounds/<tema>/  (bajá más con: hyprix-walls)
  Ajustes visuales: Super+Coma · luz nocturna/batería/clima: ~/.config/hyprix/hyprix.conf
  Log completo: $LOG
XEOF
