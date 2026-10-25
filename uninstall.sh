#!/bin/bash
set -e

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$SCRIPT_DIR/src"
OUT_DIR="$HOME/.config"
CONFIGS=("foot" "mako" "sway" "swaylock" "waybar" "wofi" "kitty" "qt5ct" "qt6ct" "Kvantum" "kdeglobals" "lximage-qt" "pcmanfm-qt" "lxqt")

UNINSTALL_CONFIGS=false
UNINSTALL_SWAY_MANAGER=false
UNINSTALL_POLKIT=false
UNINSTALL_UDEV=false
UNINSTALL_SESSION=false
UNINSTALL_FONTS=false
UNINSTALL_FLATPAKS=false
UNINSTALL_BUILD_DIR=false
UNINSTALL_PACKAGES=false
DRY_RUN=false
AUTO_CONFIRM=false
FLAG_SPECIFIED=false

show_help() {
    cat << EOF
Sway & SwayFX Infrastructure and Multi-OS Uninstaller

Usage: $(basename "$0") [OPTIONS]

Options:
  -a, --all               Uninstall everything installed by install.sh (configs, SwayManager, polkit, udev rules, session entry, local fonts, build files).
  --configs-only          Remove deployed symlinks in ~/.config and restore original backups (.bak) if present.
  --sway-manager          Remove SwayManager binaries, virtualenv, desktop entries, and portal configuration overrides.
  --polkit                Stop, disable, and remove GNOME Polkit authentication systemd user service.
  --udev                  Remove battery conservation udev rules from /etc/udev/rules.d.
  --session               Remove Sway Wayland session entry from /usr/share/wayland-sessions.
  --fonts                 Remove local fonts installed in ~/.local/share/fonts.
  --flatpaks              Uninstall user Flatpak applications installed by install.sh.
  --build-dir             Remove ~/build directory (SwayFX build environment) and compiled binaries in /usr/local/bin.
  --packages              Uninstall core system packages installed by install.sh (requires sudo).
  --restore-gnome         Uninstall Sway, clean Sway home configs, revert GNOME modifications, reinstall GNOME & GDM, while keeping Flatpaks intact.
  -y, --yes               Auto-confirm prompt and proceed without interactive confirmation.
  --dry-run               Show what actions would be performed without making any changes.
  -h, --help              Show this help message.
EOF
}

# Parse options
while [[ $# -gt 0 ]]; do
    case "$1" in
        --restore-gnome|--pure-gnome)
            shift
            exec "$SCRIPT_DIR/scripts/restore-gnome.sh" "$@"
            ;;
        -a|--all)
            UNINSTALL_CONFIGS=true
            UNINSTALL_SWAY_MANAGER=true
            UNINSTALL_POLKIT=true
            UNINSTALL_UDEV=true
            UNINSTALL_SESSION=true
            UNINSTALL_FONTS=true
            UNINSTALL_FLATPAKS=true
            UNINSTALL_BUILD_DIR=true
            UNINSTALL_PACKAGES=true
            FLAG_SPECIFIED=true
            shift
            ;;
        --configs-only)
            UNINSTALL_CONFIGS=true
            FLAG_SPECIFIED=true
            shift
            ;;
        --sway-manager)
            UNINSTALL_SWAY_MANAGER=true
            FLAG_SPECIFIED=true
            shift
            ;;
        --polkit)
            UNINSTALL_POLKIT=true
            FLAG_SPECIFIED=true
            shift
            ;;
        --udev)
            UNINSTALL_UDEV=true
            FLAG_SPECIFIED=true
            shift
            ;;
        --session)
            UNINSTALL_SESSION=true
            FLAG_SPECIFIED=true
            shift
            ;;
        --fonts)
            UNINSTALL_FONTS=true
            FLAG_SPECIFIED=true
            shift
            ;;
        --flatpaks)
            UNINSTALL_FLATPAKS=true
            FLAG_SPECIFIED=true
            shift
            ;;
        --build-dir)
            UNINSTALL_BUILD_DIR=true
            FLAG_SPECIFIED=true
            shift
            ;;
        --packages)
            UNINSTALL_PACKAGES=true
            FLAG_SPECIFIED=true
            shift
            ;;
        -y|--yes)
            AUTO_CONFIRM=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Default behavior: if no specific component flag was passed, default to removing configs, SwayManager, polkit, udev rules, session entry, local fonts, and build dir.
if [ "$FLAG_SPECIFIED" = false ]; then
    UNINSTALL_CONFIGS=true
    UNINSTALL_SWAY_MANAGER=true
    UNINSTALL_POLKIT=true
    UNINSTALL_UDEV=true
    UNINSTALL_SESSION=true
    UNINSTALL_FONTS=true
    UNINSTALL_BUILD_DIR=true
fi

run_cmd() {
    if [ "$DRY_RUN" = true ]; then
        echo "[DRY-RUN] $*"
    else
        echo "Executing: $*"
        "$@"
    fi
}

detect_os() {
    OS_FAMILY="unknown"
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case "$ID" in
            arch|manjaro|endeavouros|garuda)
                OS_FAMILY="arch"
                ;;
            debian|ubuntu|pop|mint|elementary)
                OS_FAMILY="debian"
                ;;
            *)
                if [[ "$ID_LIKE" == *"arch"* ]]; then
                    OS_FAMILY="arch"
                elif [[ "$ID_LIKE" == *"debian"* ]] || [[ "$ID_LIKE" == *"ubuntu"* ]]; then
                    OS_FAMILY="debian"
                fi
                ;;
        esac
    fi
    echo "Detected OS distribution family: $OS_FAMILY (${NAME:-$OS_ID})"
}

confirm_action() {
    if [ "$AUTO_CONFIRM" = true ] || [ "$DRY_RUN" = true ]; then
        return 0
    fi
    echo ""
    read -p "Are you sure you want to proceed with uninstallation? [y/N]: " choice
    case "$choice" in
        y|Y|yes|YES)
            return 0
            ;;
        *)
            echo "Uninstallation canceled by user."
            exit 0
            ;;
    esac
}

uninstall_configs() {
    echo "=== Removing Configuration Symlinks & Restoring Backups ==="
    for item in "${CONFIGS[@]}"; do
        OUT="$OUT_DIR/$item"
        BACKUP="${OUT}.bak"

        if [ -L "$OUT" ]; then
            TARGET="$(readlink "$OUT" 2>/dev/null || true)"
            echo "Removing configuration symlink: $OUT (points to: $TARGET)"
            run_cmd rm -f "$OUT"
        elif [ -e "$OUT" ]; then
            echo "Notice: $OUT is a regular directory/file (not a symlink). Skipping removal to prevent data loss."
        fi

        if [ -e "$BACKUP" ] || [ -L "$BACKUP" ]; then
            echo "Restoring original configuration backup: $BACKUP -> $OUT"
            run_cmd mv "$BACKUP" "$OUT"
        fi
    done
}

uninstall_sway_manager() {
    echo "=== Uninstalling SwayManager & Resetting Portal Configs ==="

    BIN_DIR="$OUT_DIR/sway/bin"
    MGR_DEST="$BIN_DIR/sway-manager-src"
    VENV_DIR="$BIN_DIR/sway-manager-venv"
    MGR_DIR="$BIN_DIR/sway-manager"
    WRAPPER_SCRIPT="$BIN_DIR/SwayManager"
    DESKTOP_FILE="$HOME/.local/share/applications/sway-manager.desktop"

    PATHS_TO_REMOVE=(
        "$MGR_DIR"
        "$MGR_DEST"
        "$VENV_DIR"
        "$WRAPPER_SCRIPT"
        "$BIN_DIR/sway-manager"
        "$BIN_DIR/SwayManagerGUI"
        "$BIN_DIR/sway-manager-gui"
        "$BIN_DIR/SwayManagerDaemon"
        "$DESKTOP_FILE"
    )

    for path in "${PATHS_TO_REMOVE[@]}"; do
        if [ -e "$path" ] || [ -L "$path" ]; then
            echo "Removing SwayManager entry: $path"
            run_cmd rm -rf "$path"
        fi
    done

    # Reset/restore xdg-desktop-portal configurations if backups exist
    PORTAL_DIR="$HOME/.config/xdg-desktop-portal"
    for filename in "portals.conf" "sway-portals.conf"; do
        CONF_FILE="$PORTAL_DIR/$filename"
        CONF_BAK="${CONF_FILE}.bak"
        if [ -f "$CONF_BAK" ]; then
            echo "Restoring backup: $CONF_BAK -> $CONF_FILE"
            run_cmd mv "$CONF_BAK" "$CONF_FILE"
        fi
    done

    WLR_CONF="$HOME/.config/xdg-desktop-portal-wlr/config"
    WLR_BAK="${WLR_CONF}.bak"
    if [ -f "$WLR_BAK" ]; then
        echo "Restoring backup: $WLR_BAK -> $WLR_CONF"
        run_cmd mv "$WLR_BAK" "$WLR_CONF"
    fi
}

uninstall_polkit() {
    echo "=== Disabling & Removing GNOME Polkit User Service ==="

    SERVICE_FILE="$HOME/.config/systemd/user/polkit-gnome-authentication-agent-1.service"

    if command -v systemctl &>/dev/null; then
        echo "Stopping systemd user service..."
        run_cmd systemctl --user stop polkit-gnome-authentication-agent-1.service 2>/dev/null || true
        run_cmd systemctl --user disable polkit-gnome-authentication-agent-1.service 2>/dev/null || true
    fi

    if [ -f "$SERVICE_FILE" ]; then
        echo "Removing service file: $SERVICE_FILE"
        run_cmd rm -f "$SERVICE_FILE"
    fi

    if command -v systemctl &>/dev/null; then
        run_cmd systemctl --user daemon-reload 2>/dev/null || true
    fi
}

uninstall_udev() {
    echo "=== Removing Battery Conservation Udev Rules ==="
    UDEV_FILE="/etc/udev/rules.d/99-battery-conservation.rules"

    if [ -f "$UDEV_FILE" ]; then
        echo "Removing udev rules: $UDEV_FILE (sudo required)"
        run_cmd sudo rm -f "$UDEV_FILE"
        run_cmd sudo udevadm control --reload || true
        run_cmd sudo udevadm trigger || true
    else
        echo "Udev rule file $UDEV_FILE not found."
    fi
}

uninstall_session() {
    echo "=== Removing Wayland Session Desktop Entry ==="
    SESSION_FILE="/usr/share/wayland-sessions/sway.desktop"

    if [ -f "$SESSION_FILE" ]; then
        echo "Removing Wayland session entry: $SESSION_FILE (sudo required)"
        run_cmd sudo rm -f "$SESSION_FILE"
    else
        echo "Session file $SESSION_FILE not found."
    fi
}

uninstall_fonts() {
    echo "=== Removing Local Installed Fonts ==="
    FONTS_SRC="$SCRIPT_DIR/fonts"
    DEST_FONT_DIR="$HOME/.local/share/fonts"

    if [ -d "$FONTS_SRC" ] && [ -d "$DEST_FONT_DIR" ]; then
        echo "Removing copied fonts from $DEST_FONT_DIR..."
        for font_file in "$FONTS_SRC"/*; do
            if [ -f "$font_file" ]; then
                font_name="$(basename "$font_file")"
                target_font="$DEST_FONT_DIR/$font_name"
                if [ -f "$target_font" ]; then
                    echo "Removing font: $target_font"
                    run_cmd rm -f "$target_font"
                fi
            fi
        done

        if command -v fc-cache &>/dev/null; then
            echo "Refreshing system font cache..."
            run_cmd fc-cache -f "$DEST_FONT_DIR" || true
        fi
    else
        echo "No local fonts to remove or target directory missing."
    fi
}

uninstall_flatpaks() {
    echo "=== Uninstalling User Flatpak Applications ==="
    FLATPAK_APPS=(
        com.usebottles.bottles
        com.rtosta.zapzap
        com.valvesoftware.Steam
        dev.vencord.Vesktop
        com.discordapp.Discord
        com.heroicgameslauncher.hgl
    )

    if command -v flatpak &>/dev/null; then
        for app in "${FLATPAK_APPS[@]}"; do
            if flatpak list --user --app 2>/dev/null | grep -q "$app"; then
                echo "Uninstalling Flatpak app: $app"
                run_cmd flatpak uninstall --user -y "$app" || true
            fi
        done
    else
        echo "Flatpak command not found. Skipping."
    fi
}

uninstall_build_dir() {
    echo "=== Removing Build Artifacts & Compiled Binaries ==="

    BUILD_DIR="$HOME/build"
    if [ -d "$BUILD_DIR" ]; then
        echo "Removing build directory: $BUILD_DIR"
        run_cmd rm -rf "$BUILD_DIR"
    fi

    # Remove compiled Sway/SwayFX binaries in /usr/local/bin if present
    COMPILED_BINS=(
        "/usr/local/bin/sway"
        "/usr/local/bin/swaymsg"
        "/usr/local/bin/swaybar"
        "/usr/local/bin/swaynag"
    )

    for bin in "${COMPILED_BINS[@]}"; do
        if [ -f "$bin" ]; then
            echo "Removing compiled binary: $bin (sudo required)"
            run_cmd sudo rm -f "$bin"
        fi
    done
}

uninstall_packages() {
    echo "=== Removing Installed System Core & App Packages ==="

    if [ "$OS_FAMILY" = "debian" ]; then
        DEBIAN_PKGS=(
            foot foot-terminfo waybar swayidle swaylock brightnessctl wofi cliphist pavucontrol blueman
            mako-notifier swaybg grim slurp wl-clipboard pipewire-pulse xdg-desktop-portal-wlr
            xdg-desktop-portal-gtk xdg-desktop-portal-lxqt gnome-keyring lxqt-policykit mate-polkit nautilus remmina
            gammastep power-profiles-daemon autotiling mpv celluloid
            qt5ct qt6ct adwaita-qt qt-style-kvantum qt-style-kvantum-themes qt-style-kvantum-l10n
            lximage-qt lximage-qt-l10n pcmanfm-qt pcmanfm-qt-l10n libfm-qt6-15 lxqt-config lxqt-config-l10n
            lxqt-notificationd lxqt-notificationd-l10n lxqt-qtplugin lxqt-session lxqt-session-l10n
            lxqt-sudo lxqt-sudo-l10n lxqt-system-theme lxqt-themes lxqt-menu-data liblxqt2 liblxqt-l10n
            liblxqt-backlight-helper
        )
        run_cmd sudo apt remove --purge -y "${DEBIAN_PKGS[@]}" || true
        run_cmd sudo apt autoremove -y || true
    elif [ "$OS_FAMILY" = "arch" ]; then
        ARCH_PKGS=(
            foot foot-terminfo waybar swayidle brightnessctl wofi cliphist pavucontrol blueman mako
            swaybg grim slurp wl-clipboard xdg-desktop-portal-wlr xdg-desktop-portal-gtk xdg-desktop-portal-lxqt
            polkit-gnome nautilus remmina gammastep power-profiles-daemon autotiling mpv celluloid
            qt5ct qt6ct adwaita-qt5 adwaita-qt6 kvantum
            lximage-qt pcmanfm-qt lxqt-config lxqt-notificationd lxqt-policykit lxqt-session lxqt-sudo lxqt-themes
        )
        run_cmd sudo pacman -Rns --noconfirm "${ARCH_PKGS[@]}" || true
    else
        echo "Package uninstallation unsupported for OS family: $OS_FAMILY"
    fi
}

main() {
    detect_os
    confirm_action

    if [ "$UNINSTALL_CONFIGS" = true ]; then
        uninstall_configs
    fi

    if [ "$UNINSTALL_SWAY_MANAGER" = true ]; then
        uninstall_sway_manager
    fi

    if [ "$UNINSTALL_POLKIT" = true ]; then
        uninstall_polkit
    fi

    if [ "$UNINSTALL_UDEV" = true ]; then
        uninstall_udev
    fi

    if [ "$UNINSTALL_SESSION" = true ]; then
        uninstall_session
    fi

    if [ "$UNINSTALL_FONTS" = true ]; then
        uninstall_fonts
    fi

    if [ "$UNINSTALL_FLATPAKS" = true ]; then
        uninstall_flatpaks
    fi

    if [ "$UNINSTALL_BUILD_DIR" = true ]; then
        uninstall_build_dir
    fi

    if [ "$UNINSTALL_PACKAGES" = true ]; then
        uninstall_packages
    fi

    echo "=== Uninstallation complete! ==="
}

main
