# HYPRIX

Entorno de escritorio tipo [Omarchy](https://github.com/basecamp/omarchy) para **Debian 13 (trixie)**, sobre Hyprland.
Hecho para una MacBook Air A1466; detecta el hardware y anda también en otras PCs (Intel o AMD).

- 17 temas que cambian todo de una vez: barra, bordes, terminal, lanzador, notificaciones, íconos, apps GTK
- Fondo de pantalla elegido por vos, con vista previa
- Panel de configuración con todo en un lugar (Super+Coma)
- Barra con clima, temperatura, RAM, VPN, actualizaciones y luz nocturna
- Lanzador con calculadora, búsqueda de archivos, comandos y web
- Se actualiza con un comando: `hyprix-update`

## Instalar en un Debian 13 nuevo

Instalá Debian 13 **sin escritorio** (en tasksel dejá sólo "utilidades estándar del sistema") y con internet por cable. Después:

```bash
sudo apt install -y git
git clone https://github.com/lu3vml/hyperix.git ~/.local/share/hyprix
bash ~/.local/share/hyprix/install.sh
sudo reboot
```

O en una sola línea:

```bash
wget -qO- https://raw.githubusercontent.com/lu3vml/hyperix/main/boot.sh | bash
```

El instalador pregunta el tema, las teclas Fn (en Mac), autologin y si compilar los extras.
Para no responder nada: `bash install.sh -y`. Opciones: `--tema NOMBRE`, `--autologin`, `--sin-compilar`, `--sin-fondos`, `--temas`, `--help`.

## Pasar una instalación existente al repo

Si ya tenés HYPRIX instalado con los scripts sueltos:

```bash
git clone https://github.com/lu3vml/hyperix.git ~/.local/share/hyprix
bash ~/.local/share/hyprix/bin/hyprix-update --aplicar
```

Tus ajustes, tu fondo y `user.conf` se mantienen. Lo que se reemplaza queda respaldado en `~/.config/hyprix/backup/`.

## Actualizar

```bash
hyprix-update            # baja lo nuevo, te muestra qué cambió y lo aplica
hyprix-update --check    # sólo avisa si hay algo nuevo
hyprix-update --volver   # vuelve a la versión anterior
hyprix-update --version
```

También desde el menú HYPRIX (Super+Alt+Espacio) → *Actualizar HYPRIX*.

## Atajos principales

| Atajo | Qué hace |
|---|---|
| Super+Enter | Terminal |
| Super+Espacio | Lanzador (`=` calcula, `/` busca archivos, `!` comando, `?` web) |
| Super+Alt+Espacio | Menú HYPRIX |
| Super+Coma | Configuración |
| Super+K | Todos los atajos |
| Super+Ctrl+Espacio | Elegir fondo |
| Super+Ctrl+Shift+Espacio | Cambiar tema |
| Super+S | Terminal flotante (scratchpad) |
| Super+Shift+S | Captura de región |
| Super+Esc | Bloquear, suspender, apagar |

## Dónde está cada cosa

```
install.sh          instalador del sistema (repos, drivers, paquetes)
boot.sh             arranque en una línea
lib/deploy.sh       copia scripts, temas y configs a tu usuario
lib/packages.txt    paquetes que hyprix-update instala si faltan
bin/                comandos hyprix-* (van a ~/.local/bin)
themes/             temas (paleta de colores, acento y color de carpetas)
templates/          plantillas de la barra
config/             configs de Hyprland, hyprlock, fuentes, GTK, udiskie
```

En tu usuario:

| Archivo | Quién lo maneja |
|---|---|
| `~/.config/hyprix/settings.conf` | Super+Coma (aspecto, barra, entrada, apps…) |
| `~/.config/hyprix/hyprix.conf` | Luz nocturna, batería, clima |
| `~/.config/hypr/user.conf` | Vos: tus atajos y reglas. HYPRIX nunca lo pisa |
| `~/Imágenes/Fondos` | Tus fondos |

## Agregar un tema

Copiá uno de `themes/` con otro nombre y cambiá los colores (hex sin `#`). `GNOME_ACCENT` es el acento de las apps GTK
(blue, teal, green, yellow, orange, red, pink, purple, slate) y `THEME_FOLDERS` el color de carpetas de Papirus.
Después `hyprix-update --aplicar` y elegilo con Super+Ctrl+Shift+Espacio.

## Créditos

Inspirado en Omarchy (paletas de varios temas tomadas de su repo, licencia MIT).
`hyprix-walls` baja fondos de Omarchy y de repos de la comunidad (nordic-wallpapers, gruvbox-wallpapers,
walls-catppuccin-mocha, dracula/wallpaper); son de sus autores, para uso personal.
