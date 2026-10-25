#!/bin/bash
set -e

# ==============================================================================
# Pure GNOME Restoration & Sway Purge Utility
#
# Desinstala o Sway, SwayFX e suas ferramentas (waybar, wofi, mako, foot, etc.),
# remove as configurações do Sway da pasta home (~/.config), reverte todas as
# alterações feitas no GNOME, reinstala o ambiente GNOME limpo com GDM3/GDM
# e PRESERVA todos os pacotes e aplicativos Flatpak instalados.
# ==============================================================================

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
DRY_RUN=false
AUTO_CONFIRM=false

show_help() {
    cat << EOF
Pure GNOME Restoration & Sway Purge Utility

Uso: $(basename "$0") [OPÇÕES]

Opções:
  -y, --yes      Aprova a desinstalação do Sway e restauração do GNOME sem confirmação interativa.
  --dry-run      Exibe os comandos que seriam executados sem alterar o sistema.
  -h, --help     Exibe esta mensagem de ajuda.
EOF
}

# Parse options
while [[ $# -gt 0 ]]; do
    case "$1" in
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
            echo "Opção desconhecida: $1"
            show_help
            exit 1
            ;;
    esac
done

run_cmd() {
    if [ "$DRY_RUN" = true ]; then
        echo "[DRY-RUN] $*"
    else
        echo "Executando: $*"
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
    echo "Distribuição detectada: $OS_FAMILY (${NAME:-$OS_ID})"
}

confirm_restore() {
    if [ "$AUTO_CONFIRM" = true ] || [ "$DRY_RUN" = true ]; then
        return 0
    fi
    echo ""
    echo "================================================================="
    echo " ATENÇÃO: RESTAURAÇÃO DO GNOME LIMPO E PURGA DO SWAY"
    echo "================================================================="
    echo " Este script irá:"
    echo "  1. Desinstalar o Sway/SwayFX, Waybar, Wofi, Mako, Foot e ferramentas."
    echo "  2. Remover as pastas de configuração do Sway em ~/.config/."
    echo "  3. Reinstalar o ambiente GNOME completo e reativar o GDM (Display Manager)."
    echo "  4. MANTER todos os seus aplicativos Flatpak intactos."
    echo "================================================================="
    echo ""
    read -p "Deseja continuar com a restauração do GNOME? [y/N]: " choice
    case "$choice" in
        y|Y|yes|YES)
            return 0
            ;;
        *)
            echo "Operação cancelada pelo usuário."
            exit 0
            ;;
    esac
}

restore_debian_gnome() {
    echo "=== [Debian/Ubuntu] Reinstalando o Ambiente de Trabalho GNOME Completo ==="

    GNOME_DEBIAN_PKGS=(
        task-gnome-desktop gnome gnome-core gnome-shell gdm3 gnome-control-center
        gnome-session mutter gnome-terminal gnome-calculator gnome-system-monitor
        gnome-text-editor gnome-tweaks gnome-software gnome-software-plugin-flatpak
        gnome-software-plugin-deb gnome-disk-utility gnome-logs gnome-font-viewer
        gnome-clocks gnome-weather gnome-calendar gnome-characters gnome-maps
        gnome-snapshot eog evince file-roller nautilus network-manager-gnome
        gnome-settings-daemon gnome-initial-setup gnome-keyring libpam-gnome-keyring
        dconf-cli dconf-gsettings-backend
    )

    run_cmd sudo apt update
    run_cmd sudo apt install -y "${GNOME_DEBIAN_PKGS[@]}" || true

    echo "=== [Debian/Ubuntu] Removendo Ferramentas e Pacotes Específicos do Sway ==="
    SWAY_DEBIAN_PKGS=(
        foot foot-terminfo sway swaylock swayidle brightnessctl wofi cliphist mako-notifier swaybg
        grim slurp wl-clipboard autotiling lightdm lightdm-gtk-greeter
        xdg-desktop-portal-wlr xdg-desktop-portal-lxqt lxqt-policykit mate-polkit gammastep
        qt5ct qt6ct adwaita-qt qt-style-kvantum qt-style-kvantum-themes qt-style-kvantum-l10n
        lximage-qt lximage-qt-l10n pcmanfm-qt pcmanfm-qt-l10n libfm-qt6-15 lxqt-config lxqt-config-l10n
        lxqt-notificationd lxqt-notificationd-l10n lxqt-qtplugin lxqt-session lxqt-session-l10n
        lxqt-sudo lxqt-sudo-l10n lxqt-system-theme lxqt-themes lxqt-menu-data liblxqt2 liblxqt-l10n
        liblxqt-backlight-helper
    )
    # Desativa LightDM antes de remover
    run_cmd sudo systemctl disable lightdm 2>/dev/null || true
    run_cmd sudo systemctl stop lightdm 2>/dev/null || true

    run_cmd sudo apt remove --purge -y "${SWAY_DEBIAN_PKGS[@]}" || true
    run_cmd sudo apt autoremove --purge -y || true

    echo "=== Reativando o GDM3 (Display Manager do GNOME) ==="
    run_cmd sudo systemctl enable gdm3 || run_cmd sudo systemctl enable gdm || true
}

restore_arch_gnome() {
    echo "=== [Arch Linux] Reinstalando o Ambiente GNOME e GDM ==="

    GNOME_ARCH_PKGS=(
        gnome gnome-extra gdm gnome-terminal nautilus gnome-control-center
        gnome-calculator gnome-system-monitor gnome-text-editor gnome-tweaks
        gnome-software network-manager-applet
    )

    run_cmd sudo pacman -S --needed --noconfirm "${GNOME_ARCH_PKGS[@]}"

    echo "=== [Arch Linux] Removendo Ferramentas do Sway ==="
    SWAY_ARCH_PKGS=(
        foot foot-terminfo sway swayfx swaylock-effects swayidle brightnessctl wofi cliphist mako swaybg
        grim slurp wl-clipboard autotiling lightdm lightdm-gtk-greeter
        xdg-desktop-portal-wlr xdg-desktop-portal-lxqt gammastep
        qt5ct qt6ct adwaita-qt5 adwaita-qt6 kvantum
        lximage-qt pcmanfm-qt lxqt-config lxqt-notificationd lxqt-policykit lxqt-session lxqt-sudo lxqt-themes
    )
    run_cmd sudo systemctl disable lightdm 2>/dev/null || true
    run_cmd sudo pacman -Rns --noconfirm "${SWAY_ARCH_PKGS[@]}" || true

    echo "=== Reativando o GDM (Display Manager do GNOME) ==="
    run_cmd sudo systemctl enable gdm || true
}

clean_sway_home_configs() {
    echo "=== Apagando Configurações do Sway na Home (~/.config) ==="

    CONFIG_DIRS=(
        "$HOME/.config/sway"
        "$HOME/.config/waybar"
        "$HOME/.config/wofi"
        "$HOME/.config/mako"
        "$HOME/.config/foot"
        "$HOME/.config/swaylock"
        "$HOME/.config/sway-manager"
        "$HOME/.config/qt5ct"
        "$HOME/.config/qt6ct"
        "$HOME/.config/Kvantum"
        "$HOME/.config/kdeglobals"
        "$HOME/.config/lximage-qt"
        "$HOME/.config/pcmanfm-qt"
        "$HOME/.config/lxqt"
    )
    for item in "${CONFIG_DIRS[@]}"; do
        BACKUP="${item}.bak"

        if [ -L "$item" ]; then
            echo "Removendo link simbólico de configuração: $item"
            run_cmd rm -f "$item"
        elif [ -d "$item" ]; then
            echo "Removendo diretório de configuração do Sway: $item"
            run_cmd rm -rf "$item"
        fi

        # Se houver backup prévio do GNOME/sistema antigo, restaura
        if [ -e "$BACKUP" ]; then
            echo "Restaurando backup original de configuração: $BACKUP -> $item"
            run_cmd mv "$BACKUP" "$item"
        fi
    done

    # Remove o atalho do SwayManager do menu
    SWAY_MGR_DESKTOP="$HOME/.local/share/applications/sway-manager.desktop"
    if [ -f "$SWAY_MGR_DESKTOP" ]; then
        echo "Removendo atalho do SwayManager: $SWAY_MGR_DESKTOP"
        run_cmd rm -f "$SWAY_MGR_DESKTOP"
    fi

    # Restaura configurações padrão de portal XDG
    PORTAL_DIR="$HOME/.config/xdg-desktop-portal"
    for conf in "portals.conf" "sway-portals.conf"; do
        if [ -f "$PORTAL_DIR/$conf.bak" ]; then
            echo "Restaurando $PORTAL_DIR/$conf a partir do backup..."
            run_cmd mv "$PORTAL_DIR/$conf.bak" "$PORTAL_DIR/$conf"
        fi
    done
    if [ -f "$HOME/.config/xdg-desktop-portal-wlr/config.bak" ]; then
        run_cmd mv "$HOME/.config/xdg-desktop-portal-wlr/config.bak" "$HOME/.config/xdg-desktop-portal-wlr/config"
    fi

    echo "Removendo serviço polkit temporário do systemd user..."
    POLKIT_SVC="$HOME/.config/systemd/user/polkit-gnome-authentication-agent-1.service"
    if [ -f "$POLKIT_SVC" ]; then
        run_cmd systemctl --user stop polkit-gnome-authentication-agent-1.service 2>/dev/null || true
        run_cmd systemctl --user disable polkit-gnome-authentication-agent-1.service 2>/dev/null || true
        run_cmd rm -f "$POLKIT_SVC"
        run_cmd systemctl --user daemon-reload 2>/dev/null || true
    fi
}

clean_system_modifications() {
    echo "=== Apagando Modificações do Sistema e Regras Customizadas ==="

    UDEV_RULES="/etc/udev/rules.d/99-battery-conservation.rules"
    if [ -f "$UDEV_RULES" ]; then
        echo "Removendo regra de udev: $UDEV_RULES"
        run_cmd sudo rm -f "$UDEV_RULES"
        run_cmd sudo udevadm control --reload || true
        run_cmd sudo udevadm trigger || true
    fi

    SWAY_SESSION="/usr/share/wayland-sessions/sway.desktop"
    if [ -f "$SWAY_SESSION" ]; then
        echo "Removendo entrada de sessão do Sway: $SWAY_SESSION"
        run_cmd sudo rm -f "$SWAY_SESSION"
    fi

    BUILD_DIR="$HOME/build"
    if [ -d "$BUILD_DIR" ]; then
        echo "Removendo diretório de compilações em $BUILD_DIR..."
        run_cmd rm -rf "$BUILD_DIR"
    fi

    COMPILED_BINS=(
        "/usr/local/bin/sway"
        "/usr/local/bin/swaymsg"
        "/usr/local/bin/swaybar"
        "/usr/local/bin/swaynag"
    )
    for bin in "${COMPILED_BINS[@]}"; do
        if [ -f "$bin" ]; then
            echo "Removendo binário compilado: $bin"
            run_cmd sudo rm -f "$bin"
        fi
    done
}

reset_gnome_defaults() {
    echo "=== Resetando Configurações do GNOME para os Padrões de Fábrica ==="

    if command -v dconf &>/dev/null; then
        echo "Resetando temas e preferências de interface do GNOME via dconf..."
        run_cmd dconf reset -f /org/gnome/desktop/interface/ || true
        run_cmd dconf reset -f /org/gnome/desktop/wm/preferences/ || true
    fi

    echo "Verificando pacotes Flatpak..."
    echo "INFO: Todos os seus aplicativos e dados do Flatpak em ~/.var/app foram MANTIDOS intactos."
}

main() {
    detect_os
    confirm_restore

    if [ "$OS_FAMILY" = "debian" ]; then
        restore_debian_gnome
    else
        restore_arch_gnome
    fi

    clean_sway_home_configs
    clean_system_modifications
    reset_gnome_defaults

    echo ""
    echo "================================================================="
    echo " 🎉 Restauração do GNOME concluída com sucesso!"
    echo " - Sway e suas ferramentas foram desinstalados."
    echo " - As configurações do Sway na Home foram removidas."
    echo " - O GNOME Desktop e o GDM foram re-instalados e ativados."
    echo " - Seus aplicativos Flatpak permanecem intactos."
    echo ""
    echo " Por favor, reinicie o computador para entrar no ambiente GNOME limpo:"
    echo "   sudo reboot"
    echo "================================================================="
}

main "$@"
