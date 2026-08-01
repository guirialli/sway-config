#!/bin/bash
set -e

# ==============================================================================
# Pure Sway Setup & GNOME Purge Utility
#
# Remove o ambiente de trabalho GNOME garantindo que todas as ferramentas
# essenciais do Sway (NetworkManager para Wi-Fi, Bluetooth, Áudio Pipewire,
# lightdm como Display Manager, Polkit, Waybar, Foot, etc.) sejam re-instaladas
# e ativadas no sistema.
# ==============================================================================

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
DRY_RUN=false
AUTO_CONFIRM=false

show_help() {
    cat << EOF
Pure Sway Setup & GNOME Purge Utility

Uso: $(basename "$0") [OPÇÕES]

Opções:
  -y, --yes, --assume-yes   Confirma automaticamente a remoção e instalação de pacotes.
  --dry-run                 Exibe os comandos que seriam executados sem alterá-los.
  -h, --help                Exibe esta mensagem de ajuda.
EOF
}

# Parse options
while [[ $# -gt 0 ]]; do
    case "$1" in
        -y|--yes|--assume-yes)
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
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_ID="${ID:-}"
        OS_ID_LIKE="${ID_LIKE:-}"
    else
        echo "Erro: /etc/os-release não encontrado." >&2
        exit 1
    fi

    if [[ "$OS_ID" =~ "arch" || "$OS_ID_LIKE" =~ "arch" ]]; then
        OS_FAMILY="arch"
    elif [[ "$OS_ID" =~ "debian" || "$OS_ID" =~ "ubuntu" || "$OS_ID_LIKE" =~ "debian" || "$OS_ID_LIKE" =~ "ubuntu" ]]; then
        OS_FAMILY="debian"
    else
        if command -v pacman &>/dev/null; then
            OS_FAMILY="arch"
        elif command -v apt-get &>/dev/null || command -v apt &>/dev/null; then
            OS_FAMILY="debian"
        else
            echo "Erro: Nem pacman nem apt foram encontrados no PATH." >&2
            exit 1
        fi
    fi
}

confirm_purge() {
    if [ "$AUTO_CONFIRM" = true ]; then
        return 0
    fi
    echo "================================================================="
    echo " ATENÇÃO: Este script irá remover o ambiente de trabalho GNOME"
    echo " e configurar o lightdm com um ambiente Sway puro."
    echo " Ferramentas essenciais (NetworkManager/Wi-Fi, Bluetooth, Áudio,"
    echo " Waybar, SwayFX, lightdm, etc.) serão mantidas e re-instaladas."
    echo "================================================================="
    read -p "Deseja prosseguir? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Operação cancelada pelo usuário."
        exit 1
    fi
}

purge_debian_gnome() {
    echo "=== [Debian/Ubuntu] Removendo Pacotes do GNOME ==="
    CANDIDATE_PKGS=(
        # Shell, sessão e gerenciadores do GNOME
        gnome-shell gnome-session gdm3 gnome-control-center
        task-gnome-desktop gnome gnome-core ubuntu-desktop ubuntu-desktop-minimal
        gnome-initial-setup mutter

        # Central de Software
        gnome-software gnome-software-common gnome-software-plugin-deb
        gnome-software-plugin-flatpak gnome-software-plugin-fwupd

        # Apps com equivalentes no Sway (foot, sway-manager screenshot, etc.)
        gnome-terminal gnome-terminal-data gnome-snapshot gnome-system-monitor gnome-text-editor

        # Apps e serviços exclusivos do GNOME
        gnome-calculator gnome-clocks gnome-weather gnome-music gnome-sound-recorder
        gnome-tour gnome-user-docs gnome-user-share gnome-remote-desktop
        gnome-settings-daemon gnome-settings-daemon-common gnome-online-accounts
        gnome-backgrounds gnome-characters gnome-connections gnome-font-viewer
        gnome-logs gnome-sushi gnome-disk-utility
    )

    INSTALLED_GNOME=()
    for pkg in "${CANDIDATE_PKGS[@]}"; do
        if dpkg -s "$pkg" &>/dev/null; then
            INSTALLED_GNOME+=("$pkg")
        fi
    done

    # Desativa GDM caso esteja rodando
    run_cmd sudo systemctl disable gdm3 gdm 2>/dev/null || true

    if [ ${#INSTALLED_GNOME[@]} -gt 0 ]; then
        echo "Removendo pacotes do GNOME instalados: ${INSTALLED_GNOME[*]}"
        run_cmd sudo apt remove --purge -y "${INSTALLED_GNOME[@]}"
    else
        echo "Nenhum meta-pacote ou app GNOME da lista foi encontrado instalado."
    fi

    run_cmd sudo apt autoremove --purge -y

    echo "=== [Debian/Ubuntu] Re-instalando Ferramentas Essenciais do Sway, Wi-Fi e Bluetooth ==="
    ESSENTIAL_DEBIAN=(
        lightdm lightdm-gtk-greeter
        network-manager network-manager-gnome wpasupplicant rfkill
        bluez bluez-tools blueman
        pipewire pipewire-pulse wireplumber pavucontrol
        waybar swayidle brightnessctl wofi mako-notifier swaybg grim slurp wl-clipboard
        foot nautilus gnome-keyring libpam-gnome-keyring gnome-themes-extra gnome-themes-extra-data gnome-icon-theme gnome-desktop3-data gnome-menus gvfs gvfs-backends gvfs-fuse file-roller seahorse xdg-user-dirs xdg-utils adwaita-icon-theme dconf-cli dconf-gsettings-backend python3 python3-pip python3-venv python3-gi xwayland jq
        lxqt-policykit mate-polkit x11-xserver-utils btrfs-progs snapper
        qt5ct qt6ct adwaita-qt qt-style-kvantum qt-style-kvantum-themes qt-style-kvantum-l10n
        xdg-desktop-portal-wlr xdg-desktop-portal-gtk xdg-desktop-portal
    )
    run_cmd sudo apt update
    run_cmd sudo apt install -y "${ESSENTIAL_DEBIAN[@]}"
}

purge_arch_gnome() {
    echo "=== [Arch Linux] Removendo Pacotes do GNOME ==="
    GNOME_PKGS=(
        gnome-shell gnome-session gdm gnome-control-center mutter gnome-desktop
    )

    run_cmd sudo systemctl disable gdm 2>/dev/null || true

    echo "Removendo pacotes do GNOME..."
    run_cmd sudo pacman -Rns --noconfirm "${GNOME_PKGS[@]}" || true

    echo "=== [Arch Linux] Re-instalando Ferramentas Essenciais do Sway, Wi-Fi e Bluetooth ==="
    ESSENTIAL_ARCH=(
        lightdm lightdm-gtk-greeter
        networkmanager nm-connection-editor wpa_supplicant rfkill
        bluez bluez-utils blueman
        pipewire pipewire-pulse pipewire-alsa wireplumber pavucontrol
        waybar swayidle brightnessctl wofi mako swaybg grim slurp wl-clipboard
        foot nautilus gnome-keyring gvfs gvfs-mtp gvfs-smb file-roller seahorse xdg-user-dirs xdg-utils adwaita-icon-theme dconf jq polkit-gnome xorg-xhost btrfs-progs snapper
        qt5ct qt6ct adwaita-qt5 adwaita-qt6 kvantum
        xdg-desktop-portal-wlr xdg-desktop-portal-gtk xdg-desktop-portal
    )
    run_cmd sudo pacman -S --needed --noconfirm "${ESSENTIAL_ARCH[@]}"
}

configure_services() {
    echo "=== Ativando Serviços Essenciais (NetworkManager, Bluetooth, LightDM) ==="
    run_cmd sudo systemctl enable NetworkManager
    run_cmd sudo systemctl start NetworkManager || true

    run_cmd sudo systemctl enable bluetooth
    run_cmd sudo systemctl start bluetooth || true

    run_cmd sudo systemctl enable lightdm

    echo "=== Garantindo Entrada de Sessão Wayland para o LightDM ==="
    if [ ! -f /usr/share/wayland-sessions/sway.desktop ] && [ ! -f /usr/share/wayland-sessions/swayfx.desktop ]; then
        if command -v sway &>/dev/null; then
            SWAY_BIN="$(command -v sway)"
            if [ "$DRY_RUN" = true ]; then
                echo "[DRY-RUN] Criando /usr/share/wayland-sessions/sway.desktop para $SWAY_BIN"
            else
                sudo mkdir -p /usr/share/wayland-sessions
                sudo bash -c "cat << EOF > /usr/share/wayland-sessions/sway.desktop
[Desktop Entry]
Name=Sway
Comment=An i3-compatible Wayland compositor
Exec=$SWAY_BIN
Type=Application
DesktopNames=sway
EOF"
            fi
        fi
    fi
}

main() {
    detect_os
    confirm_purge

    if [ "$OS_FAMILY" = "debian" ]; then
        purge_debian_gnome
    else
        purge_arch_gnome
    fi

    configure_services

    echo
    echo "================================================================="
    echo " 🎉 GNOME removido e sistema Sway Puro configurado com sucesso!"
    echo " Serviços ativados no systemd:"
    echo "   - NetworkManager (Wi-Fi)"
    echo "   - Bluetooth (BlueZ + Blueman)"
    echo "   - lightdm Display Manager"
    echo " Você já pode reiniciar para entrar no seu ambiente Sway Puro via lightdm."
    echo "================================================================="
}

main "$@"
