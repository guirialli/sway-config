#!/bin/bash
set -e

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$SCRIPT_DIR/src"
OUT_DIR="$HOME/.config"
CONFIGS=("foot" "mako" "sway" "swaylock" "waybar" "wofi")

# Execution mode flags
INSTALL_CORE=false
INSTALL_APPS=false
INSTALL_SWAY_MANAGER=false
INSTALL_POLKIT=false
DEPLOY_CONFIGS=false
DRY_RUN=false
FLAG_SPECIFIED=false

show_help() {
    cat << EOF
Sway & SwayFX Configuration and Multi-OS Installer

Usage: $(basename "$0") [OPTIONS]

Options:
  -a, --all               Install everything: SwayFX core, sway-manager, polkit, recommended applications, services, and deploy configs.
  --swayfx, --core        Install Sway/SwayFX core window manager, desktop dependencies, sway-manager, polkit, and services.
  --sway-manager          Install/update sway-manager PySide6 tool and launcher wrapper (~/.config/sway/bin/SwayManager).
  --install-polkit, --polkit Configure GNOME Polkit agent systemd user service (~/.config/systemd/user/polkit-gnome-authentication-agent-1.service).
  --applications, --apps  Install recommended desktop applications extracted from keybindings (Chrome, VS Code, Nautilus, Remmina, Steam, Discord/Vesktop, etc.).
  --configs-only          Skip package installation/compilation and only deploy config symlinks to ~/.config.
  --pure-sway, --purge-gnome Remove GNOME desktop environment, install LightDM, and setup pure Sway system with Wi-Fi/BT core.
  --purge-snap, --no-snap Completely purge Snapd/Snaps and lock automatic re-installation via APT pinning.
  --dry-run               Show what commands would be executed without running them.
  -h, --help              Show this help message.

Supported Distributions:
  - Arch Linux and derivatives (Manjaro, EndeavourOS, etc.)
  - Debian 13+, Ubuntu 24.04+, and derivatives (Pop!_OS, Linux Mint, etc.)
EOF
}

# Parse options
while [[ $# -gt 0 ]]; do
    case "$1" in
        --purge-snap|--no-snap)
            shift
            exec "$SCRIPT_DIR/scripts/purge-snap.sh" "$@"
            ;;
        --pure-sway|--purge-gnome)
            shift
            exec "$SCRIPT_DIR/scripts/purge-gnome-to-sway.sh" "$@"
            ;;
        -a|--all)
            INSTALL_CORE=true
            INSTALL_APPS=true
            INSTALL_SWAY_MANAGER=true
            INSTALL_POLKIT=true
            DEPLOY_CONFIGS=true
            FLAG_SPECIFIED=true
            shift
            ;;
        --swayfx|--core)
            INSTALL_CORE=true
            INSTALL_SWAY_MANAGER=true
            INSTALL_POLKIT=true
            DEPLOY_CONFIGS=true
            FLAG_SPECIFIED=true
            shift
            ;;
        --sway-manager)
            INSTALL_SWAY_MANAGER=true
            FLAG_SPECIFIED=true
            shift
            ;;
        --install-polkit|--polkit)
            INSTALL_POLKIT=true
            FLAG_SPECIFIED=true
            shift
            ;;
        --applications|--apps)
            INSTALL_APPS=true
            FLAG_SPECIFIED=true
            shift
            ;;
        --configs-only)
            DEPLOY_CONFIGS=true
            FLAG_SPECIFIED=true
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

# Default to --all if no specific action flag was provided
if [ "$FLAG_SPECIFIED" = false ]; then
    INSTALL_CORE=true
    INSTALL_APPS=true
    INSTALL_SWAY_MANAGER=true
    INSTALL_POLKIT=true
    DEPLOY_CONFIGS=true
fi

run_cmd() {
    if [ "$DRY_RUN" = true ]; then
        echo "[DRY-RUN] $*"
    else
        echo "Running: $*"
        "$@"
    fi
}

detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_ID="${ID:-}"
        OS_ID_LIKE="${ID_LIKE:-}"
    else
        echo "Error: /etc/os-release not found. Cannot determine OS distribution." >&2
        exit 1
    fi

    if [[ "$OS_ID" =~ "arch" || "$OS_ID_LIKE" =~ "arch" ]]; then
        OS_FAMILY="arch"
    elif [[ "$OS_ID" =~ "debian" || "$OS_ID" =~ "ubuntu" || "$OS_ID_LIKE" =~ "debian" || "$OS_ID_LIKE" =~ "ubuntu" ]]; then
        OS_FAMILY="debian"
    else
        echo "Warning: Unrecognized OS ID '$OS_ID'. Inspecting available system tools..." >&2
        if command -v pacman &>/dev/null; then
            OS_FAMILY="arch"
        elif command -v apt-get &>/dev/null || command -v apt &>/dev/null; then
            OS_FAMILY="debian"
        else
            echo "Warning: Neither pacman nor apt was found in PATH. Defaulting to 'debian'." >&2
            OS_FAMILY="debian"
        fi
    fi

    echo "Detected OS distribution family: $OS_FAMILY (${NAME:-$OS_ID})"
}

install_arch_core() {
    echo "=== [Arch] Installing Sway/SwayFX Core & Desktop Infrastructure ==="
    
    ARCH_CORE_PKGS=(
        python python-pip python-virtualenv python-gobject xorg-xwayland waybar
        swayidle brightnessctl wofi cliphist pavucontrol blueman networkmanager mako
        swaybg grim slurp wl-clipboard pipewire pipewire-pulse pipewire-alsa
        xdg-desktop-portal-wlr xdg-desktop-portal-gtk foot gnome-keyring jq
        ttf-meslo-nerd-font-powerlevel10k polkit-gnome xorg-xhost btrfs-progs snapper btrfs-assistant
        qt5ct qt6ct adwaita-qt5 adwaita-qt6 kvantum
    )

    run_cmd sudo pacman -S --needed --noconfirm "${ARCH_CORE_PKGS[@]}"

    AUR_HELPER=""
    if command -v yay &>/dev/null; then
        AUR_HELPER="yay"
    elif command -v paru &>/dev/null; then
        AUR_HELPER="paru"
    fi

    if [ -n "$AUR_HELPER" ]; then
        echo "Using AUR helper for Core packages: $AUR_HELPER"
        AUR_CORE_PKGS=(swayfx swaylock-effects)
        run_cmd "$AUR_HELPER" -S --needed --noconfirm "${AUR_CORE_PKGS[@]}"
    else
        echo "Warning: Neither yay nor paru was found. Skipping AUR SwayFX installation."
        echo "Please install an AUR helper or manually install: swayfx swaylock-effects"
    fi

    install_local_fonts
    setup_gnome_polkit
    setup_wayland_session
    enable_services
}

setup_wayland_session() {
    echo "=== Configuring LightDM / Display Manager Wayland Session Entry ==="
    SWAY_BIN="$(command -v sway || echo "/usr/local/bin/sway")"

    if [ "$DRY_RUN" = true ]; then
        echo "[DRY-RUN] Would create /usr/share/wayland-sessions/sway.desktop pointing to $SWAY_BIN"
        return 0
    fi

    sudo mkdir -p /usr/share/wayland-sessions
    sudo bash -c "cat << EOF > /usr/share/wayland-sessions/sway.desktop
[Desktop Entry]
Name=Sway
Comment=An i3-compatible Wayland compositor
Exec=$SWAY_BIN
Type=Application
DesktopNames=sway
EOF"
    echo "Wayland session entry configured successfully (/usr/share/wayland-sessions/sway.desktop)."
}

build_meson_tarball() {
    local name="$1"
    local version="$2"
    local url="$3"
    local tarball="$4"
    local src_dir="$5"
    local pkg_name="$6"
    local pkg_version="$7"
    shift 7
    local meson_opts=("$@")

    if [ "$DRY_RUN" = true ]; then
        echo "[DRY-RUN] Would download and build $name $version from $url and install to /usr/local"
        return 0
    fi

    if pkg-config --exists "$pkg_name >= $pkg_version" 2>/dev/null; then
        echo "$name $version (or newer) already installed: $(pkg-config --modversion "$pkg_name")"
        return 0
    fi

    mkdir -p "$BUILD_DIR"
    cd "$BUILD_DIR"

    rm -rf "$src_dir"
    if [ ! -f "$tarball" ]; then
        echo "Downloading $name $version..."
        wget -q "$url" -O "$tarball"
    fi
    tar -xf "$tarball"
    cd "$src_dir"

    echo "Building $name $version..."
    meson setup build/ --prefix=/usr/local "${meson_opts[@]}"
    ninja -C build/

    echo "Installing $name $version..."
    sudo ninja -C build/ install
    sudo ldconfig
    echo "$name installed: $(pkg-config --modversion "$pkg_name")"
}

install_debian_core() {
    echo "=== [Debian/Ubuntu] Installing Core Dependencies & Building SwayFX ==="

    echo "1. Installing build dependencies via apt..."
    BUILD_DEPS=(
        meson pkg-config cmake git scdoc wayland-protocols libwayland-dev
        bison libpcre2-dev libjson-c-dev libpango1.0-dev libcairo2-dev
        libgdk-pixbuf-2.0-dev libdrm-dev libgbm-dev libinput-dev libseat-dev
        libxkbcommon-dev libxcb-dri3-dev libxcb-present-dev libxcb-res0-dev
        libxcb-render-util0-dev libxcb-ewmh-dev libxcb-icccm4-dev
        libliftoff-dev libdisplay-info-dev liblcms2-dev libpixman-1-dev
        libgles2-mesa-dev hwdata libudev-dev libffi-dev libexpat1-dev
    )

    run_cmd sudo apt update
    run_cmd sudo apt install -y "${BUILD_DEPS[@]}"

    echo "2. Installing desktop core utilities via apt..."
    RUNTIME_CORE=(
        waybar swayidle swaylock brightnessctl wofi cliphist pavucontrol blueman
        network-manager mako-notifier swaybg grim slurp wl-clipboard pipewire
        pipewire-pulse xdg-desktop-portal-wlr xdg-desktop-portal-gtk
        foot gnome-keyring libpam-gnome-keyring gnome-themes-extra gnome-themes-extra-data gnome-icon-theme gnome-desktop3-data gnome-menus python3 python3-pip python3-venv python3-gi xwayland jq
        lxqt-policykit mate-polkit x11-xserver-utils btrfs-progs snapper
        qt5ct qt6ct adwaita-qt qt-style-kvantum qt-style-kvantum-themes qt-style-kvantum-l10n
    )
    run_cmd sudo apt install -y "${RUNTIME_CORE[@]}"

    BUILD_DIR="$HOME/build"

    echo "3. Installing dependencies newer than Debian Trixie packages..."

    build_meson_tarball "Wayland" "1.24.0" \
        "https://gitlab.freedesktop.org/wayland/wayland/-/releases/1.24.0/downloads/wayland-1.24.0.tar.xz" \
        "wayland-1.24.0.tar.xz" "$BUILD_DIR/wayland-1.24.0" \
        "wayland-server" "1.24.0" \
        -Ddocumentation=false -Dtests=false -Ddtd_validation=false

    build_meson_tarball "Wayland Protocols" "1.47" \
        "https://gitlab.freedesktop.org/wayland/wayland-protocols/-/releases/1.47/downloads/wayland-protocols-1.47.tar.xz" \
        "wayland-protocols-1.47.tar.xz" "$BUILD_DIR/wayland-protocols-1.47" \
        "wayland-protocols" "1.47" \
        -Dtests=false

    build_meson_tarball "libdrm" "2.4.129" \
        "https://dri.freedesktop.org/libdrm/libdrm-2.4.129.tar.xz" \
        "libdrm-2.4.129.tar.xz" "$BUILD_DIR/libdrm-2.4.129" \
        "libdrm" "2.4.129" \
        -Dintel=disabled -Dradeon=disabled -Damdgpu=disabled -Dnouveau=disabled \
        -Dvmwgfx=disabled -Domap=disabled -Dexynos=disabled -Dfreedreno=disabled \
        -Dtegra=disabled -Dvc4=disabled -Detnaviv=disabled -Dcairo-tests=disabled \
        -Dman-pages=disabled -Dvalgrind=disabled -Dtests=false

    build_meson_tarball "libxkbcommon" "1.8.0" \
        "https://github.com/xkbcommon/libxkbcommon/archive/refs/tags/xkbcommon-1.8.0.tar.gz" \
        "xkbcommon-1.8.0.tar.gz" "$BUILD_DIR/libxkbcommon-xkbcommon-1.8.0" \
        "xkbcommon" "1.8.0" \
        -Denable-tools=false -Denable-x11=false -Denable-docs=false -Denable-wayland=false

    build_meson_tarball "pixman" "0.46.0" \
        "https://www.cairographics.org/releases/pixman-0.46.0.tar.gz" \
        "pixman-0.46.0.tar.gz" "$BUILD_DIR/pixman-0.46.0" \
        "pixman-1" "0.46.0" \
        -Dtests=disabled -Ddemos=disabled -Dgtk=disabled -Dlibpng=disabled

    echo "4. Building SwayFX v0.6 from source..."
    if [ "$DRY_RUN" = true ]; then
        echo "[DRY-RUN] Would clone and build SwayFX (v0.6), SceneFX (v0.5), and wlroots (v0.20.2) in $BUILD_DIR/swayfx"
    else
        mkdir -p "$BUILD_DIR"
        cd "$BUILD_DIR"

        if [ -d "swayfx" ]; then
            echo "Cleaning up previous SwayFX build directory..."
            rm -rf swayfx
        fi

        echo "Cloning SwayFX v0.6..."
        git clone https://github.com/WillPower3309/swayfx.git
        cd swayfx
        git checkout 0.6

        mkdir subprojects
        cd subprojects

        echo "Cloning SceneFX v0.5 subproject..."
        git clone https://github.com/wlrfx/scenefx.git
        cd scenefx
        git checkout 0.5
        cd ..

        echo "Cloning wlroots v0.20.2 subproject..."
        git clone https://gitlab.freedesktop.org/wlroots/wlroots.git
        cd wlroots
        git checkout 0.20.2
        cd ../..

        echo "Compiling SwayFX..."
        meson setup build/
        ninja -C build/

        echo "Installing SwayFX..."
        sudo ninja -C build/ install
        sudo ldconfig

        echo "SwayFX compilation & installation complete."
        sway --version || true
    fi

    install_local_fonts
    setup_gnome_polkit
    setup_wayland_session
    enable_services
}

setup_gnome_polkit() {
    echo "=== Configuring GNOME Polkit Authentication Agent ==="

    POLKIT_BIN=""
    POSSIBLE_PATHS=(
        "/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1"
        "/usr/libexec/polkit-gnome-authentication-agent-1"
        "/usr/lib/policykit-1-gnome/polkit-gnome-authentication-agent-1"
        "/usr/bin/lxqt-policykit-agent"
        "/usr/libexec/lxqt-policykit-agent"
        "/usr/libexec/polkit-mate-authentication-agent-1"
        "/usr/lib/mate-polkit/polkit-mate-authentication-agent-1"
    )

    for path in "${POSSIBLE_PATHS[@]}"; do
        if [ -x "$path" ]; then
            POLKIT_BIN="$path"
            break
        fi
    done

    if [ -z "$POLKIT_BIN" ]; then
        echo "Polkit agent package not found. Attempting package installation..."
        if [ "$OS_FAMILY" = "arch" ]; then
            run_cmd sudo pacman -S --needed --noconfirm polkit-gnome lxqt-policykit || true
        elif [ "$OS_FAMILY" = "debian" ]; then
            run_cmd sudo apt install -y lxqt-policykit mate-polkit || true
        fi

        for path in "${POSSIBLE_PATHS[@]}"; do
            if [ -x "$path" ]; then
                POLKIT_BIN="$path"
                break
            fi
        done
    fi

    if [ -z "$POLKIT_BIN" ]; then
        POLKIT_BIN="/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1"
    fi

    SERVICE_DIR="$HOME/.config/systemd/user"
    SERVICE_FILE="$SERVICE_DIR/polkit-gnome-authentication-agent-1.service"

    if [ "$DRY_RUN" = true ]; then
        echo "[DRY-RUN] Would create systemd user service at $SERVICE_FILE pointing to $POLKIT_BIN"
        echo "[DRY-RUN] Would run systemctl --user enable --now polkit-gnome-authentication-agent-1.service"
        return 0
    fi

    mkdir -p "$SERVICE_DIR"

    cat << EOF > "$SERVICE_FILE"
[Unit]
Description=GNOME Polkit Authentication Agent
Documentation=man:polkit(8)
After=graphical-session-pre.target
PartOf=graphical-session.target

[Service]
Type=simple
ExecStart=$POLKIT_BIN
Restart=on-failure
RestartSec=1

[Install]
WantedBy=graphical-session.target
EOF

    if command -v systemctl &>/dev/null; then
        systemctl --user daemon-reload || true
        systemctl --user enable --now polkit-gnome-authentication-agent-1.service || true
    fi

    echo "GNOME Polkit user service configured successfully ($POLKIT_BIN)."
}

install_local_fonts() {
    echo "=== Installing Fonts from ./fonts ==="
    FONTS_SRC="$SCRIPT_DIR/fonts"
    DEST_FONT_DIR="$HOME/.local/share/fonts"

    if [ ! -d "$FONTS_SRC" ]; then
        echo "Warning: fonts directory not found at '$FONTS_SRC'. Skipping local font installation." >&2
        return 0
    fi

    if [ "$DRY_RUN" = true ]; then
        echo "[DRY-RUN] Would copy font files from $FONTS_SRC to $DEST_FONT_DIR and run fc-cache -f"
        return 0
    fi

    mkdir -p "$DEST_FONT_DIR"
    echo "Copying font files from ./fonts to $DEST_FONT_DIR..."
    cp -rf "$FONTS_SRC"/* "$DEST_FONT_DIR/" 2>/dev/null || true

    if command -v fc-cache &>/dev/null; then
        echo "Updating system font cache..."
        fc-cache -f "$DEST_FONT_DIR" || true
    fi
    echo "Local fonts installed successfully."
}

install_flatpak_user_apps() {
    echo "=== Installing 3rd-Party Applications via Flatpak (--user) ==="
    
    FLATPAK_APPS=(
        com.usebottles.bottles
        com.rtosta.zapzap
        com.valvesoftware.Steam
        dev.vencord.Vesktop
        com.discordapp.Discord
        com.heroicgameslauncher.hgl
    )

    run_cmd flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    run_cmd flatpak install --user -y flathub "${FLATPAK_APPS[@]}"
}

install_arch_apps() {
    echo "=== [Arch] Installing Recommended Desktop Applications ==="

    ARCH_OFFICIAL_APPS=(
        nautilus remmina gammastep power-profiles-daemon
        cliphist autotiling mpv celluloid flatpak
    )
    run_cmd sudo pacman -S --needed --noconfirm "${ARCH_OFFICIAL_APPS[@]}"

    AUR_HELPER=""
    if command -v yay &>/dev/null; then
        AUR_HELPER="yay"
    elif command -v paru &>/dev/null; then
        AUR_HELPER="paru"
    fi

    if [ -n "$AUR_HELPER" ]; then
        echo "Installing native Google Chrome, VS Code, and Ulauncher via AUR ($AUR_HELPER)..."
        run_cmd "$AUR_HELPER" -S --needed --noconfirm google-chrome visual-studio-code-bin ulauncher
    else
        echo "Warning: Neither yay nor paru was found. Please install an AUR helper to install google-chrome, visual-studio-code-bin, and ulauncher."
    fi

    install_flatpak_user_apps
}

install_debian_apps() {
    echo "=== [Debian/Ubuntu] Installing Recommended Desktop Applications ==="

    DEBIAN_APPS=(
        nautilus remmina gammastep power-profiles-daemon
        cliphist autotiling mpv celluloid flatpak wget
        libnotify-bin swaylock
    )
    run_cmd sudo apt update
    run_cmd sudo apt install -y "${DEBIAN_APPS[@]}" || true

    if ! command -v google-chrome &>/dev/null && ! command -v google-chrome-stable &>/dev/null; then
        echo "Installing native Google Chrome package on Debian/Ubuntu..."
        if [ "$DRY_RUN" = true ]; then
            echo "[DRY-RUN] wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -O /tmp/google-chrome.deb && sudo apt install -y /tmp/google-chrome.deb"
        else
            wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -O /tmp/google-chrome.deb || true
            if [ -f /tmp/google-chrome.deb ]; then
                sudo apt install -y /tmp/google-chrome.deb || true
                rm -f /tmp/google-chrome.deb
            fi
        fi
    fi

    if ! command -v code &>/dev/null; then
        echo "Installing native VS Code package on Debian/Ubuntu..."
        if [ "$DRY_RUN" = true ]; then
            echo "[DRY-RUN] wget 'https://go.microsoft.com/fwlink/?LinkID=760868' -O /tmp/vscode.deb && sudo apt install -y /tmp/vscode.deb"
        else
            wget -q 'https://go.microsoft.com/fwlink/?LinkID=760868' -O /tmp/vscode.deb || true
            if [ -f /tmp/vscode.deb ]; then
                sudo apt install -y /tmp/vscode.deb || true
                rm -f /tmp/vscode.deb
            fi
        fi
    fi

    install_flatpak_user_apps
}

install_sway_manager() {
    echo "=== Setting up SwayManager ==="

    SWAY_MGR_SRC="$SCRIPT_DIR/sway-manager"
    BIN_DIR="$OUT_DIR/sway/bin"
    MGR_DEST="$BIN_DIR/sway-manager-src"
    VENV_DIR="$BIN_DIR/sway-manager-venv"
    WRAPPER_SCRIPT="$BIN_DIR/SwayManager"

    if [ ! -d "$SWAY_MGR_SRC" ]; then
        echo "Warning: sway-manager directory not found at '$SWAY_MGR_SRC'. Skipping SwayManager installation." >&2
        return 0
    fi

    if [ "$DRY_RUN" = true ]; then
        echo "[DRY-RUN] Would create directory $BIN_DIR"
        echo "[DRY-RUN] Would sync $SWAY_MGR_SRC to $MGR_DEST"
        echo "[DRY-RUN] Would create Python virtual environment at $VENV_DIR"
        echo "[DRY-RUN] Would install PySide6 & requirements in $VENV_DIR"
        echo "[DRY-RUN] Would compile and generate executable via Nuitka at $WRAPPER_SCRIPT"
        return 0
    fi

    mkdir -p "$BIN_DIR"

    echo "Deploying SwayManager source code..."
    rm -rf "$MGR_DEST"
    cp -rf "$SWAY_MGR_SRC" "$MGR_DEST"

    if [ ! -d "$VENV_DIR" ]; then
        echo "Creating Python virtual environment for SwayManager..."
        python3 -m venv "$VENV_DIR"
    fi

    echo "Installing Python dependencies for SwayManager..."
    "$VENV_DIR/bin/pip" install --upgrade pip setuptools wheel --quiet || true
    if [ -f "$MGR_DEST/requirements.txt" ]; then
        grep -v -i "^distutils" "$MGR_DEST/requirements.txt" > "$MGR_DEST/reqs_clean.txt" || cp "$MGR_DEST/requirements.txt" "$MGR_DEST/reqs_clean.txt"
        "$VENV_DIR/bin/pip" install -r "$MGR_DEST/reqs_clean.txt" --quiet || "$VENV_DIR/bin/pip" install PySide6 --quiet || true
        rm -f "$MGR_DEST/reqs_clean.txt"
    else
        "$VENV_DIR/bin/pip" install PySide6 --quiet || true
    fi

    echo "Compiling SwayManager with Nuitka..."
    (
        cd "$SWAY_MGR_SRC"
        chmod +x build.sh install.sh 2>/dev/null || true
        ./install.sh --no-udev || true
    )

    if [ ! -f "$WRAPPER_SCRIPT" ]; then
        echo "Generating SwayManager executable fallback wrapper..."
        rm -f "$WRAPPER_SCRIPT"
        cat << 'EOF' > "$WRAPPER_SCRIPT"
#!/bin/bash
BIN_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
VENV_PYTHON="$BIN_DIR/sway-manager-venv/bin/python"
MAIN_SCRIPT="$BIN_DIR/sway-manager-src/src/main.py"

if [ -f "$VENV_PYTHON" ] && [ -f "$MAIN_SCRIPT" ]; then
    exec "$VENV_PYTHON" "$MAIN_SCRIPT" "$@"
else
    echo "Error: SwayManager Python environment or source script is missing." >&2
    exit 1
fi
EOF
        chmod +x "$WRAPPER_SCRIPT"
    fi

    echo "Generating SwayManager desktop entry..."
    DESKTOP_DIR="$HOME/.local/share/applications"
    mkdir -p "$DESKTOP_DIR"
    cat << EOF > "$DESKTOP_DIR/sway-manager.desktop"
[Desktop Entry]
Name=SwayManager Control Center
Comment=Sway & SwayFX Desktop Control Center
Exec=$WRAPPER_SCRIPT settings
Icon=preferences-desktop
Terminal=false
Type=Application
Categories=Settings;DesktopSettings;
EOF

    echo "SwayManager successfully installed at: $WRAPPER_SCRIPT"
}

enable_services() {
    if command -v systemctl &>/dev/null; then
        echo "=== Enabling System Services ==="
        run_cmd sudo systemctl enable --now NetworkManager.service bluetooth.service
        setup_battery_udev
    fi
}

setup_battery_udev() {
    echo "=== Setting up Udev Rules for Battery Conservation ==="
    UDEV_FILE="/etc/udev/rules.d/99-battery-conservation.rules"

    if [ "$DRY_RUN" = true ]; then
        echo "[DRY-RUN] Would create $UDEV_FILE allowing user write access to sysfs battery conservation files"
        return 0
    fi

    run_cmd sudo sh -c "cat << 'EOF' > $UDEV_FILE
# Allow non-root users to toggle Lenovo IdeaPad & generic battery conservation mode
SUBSYSTEM==\"platform\", DRIVER==\"ideapad_acpi\", ATTR{conservation_mode}=\"0666\"
SUBSYSTEM==\"power_supply\", ATTR{charge_control_end_threshold}=\"0666\"
SUBSYSTEM==\"power_supply\", ATTR{charge_stop_threshold}=\"0666\"
EOF"

    run_cmd sudo udevadm control --reload || true
    run_cmd sudo udevadm trigger || true
}

setup_configs() {
    echo "=== Deploying Configuration Symlinks ==="
    mkdir -p "$OUT_DIR"

    for item in "${CONFIGS[@]}"; do
        CONFIG="$SRC_DIR/$item"
        OUT="$OUT_DIR/$item"

        if [ ! -d "$CONFIG" ] && [ ! -f "$CONFIG" ]; then
            echo "Warning: Source configuration '$CONFIG' does not exist. Skipping."
            continue
        fi

        if [ -e "$OUT" ] || [ -L "$OUT" ]; then
            BACKUP="${OUT}.bak"
            echo "Existing configuration found at '$OUT'. Backing up to '$BACKUP'..."
            if [ "$DRY_RUN" = true ]; then
                echo "[DRY-RUN] rm -rf $BACKUP && mv $OUT $BACKUP"
            else
                rm -rf "$BACKUP"
                mv "$OUT" "$BACKUP"
            fi
        fi

        if [ "$DRY_RUN" = true ]; then
            echo "[DRY-RUN] ln -s $CONFIG $OUT"
        else
            echo "Creating symlink: $OUT -> $CONFIG"
            ln -s "$CONFIG" "$OUT"
        fi
    done
}

main() {
    detect_os

    if [ "$INSTALL_CORE" = true ]; then
        case "$OS_FAMILY" in
            arch)
                install_arch_core
                ;;
            debian)
                install_debian_core
                ;;
            *)
                echo "Unsupported OS family for Core: $OS_FAMILY" >&2
                exit 1
                ;;
        esac
    fi

    if [ "$INSTALL_SWAY_MANAGER" = true ]; then
        install_sway_manager
    fi

    if [ "$INSTALL_POLKIT" = true ]; then
        setup_gnome_polkit
    fi

    if [ "$INSTALL_APPS" = true ]; then
        case "$OS_FAMILY" in
            arch)
                install_arch_apps
                ;;
            debian)
                install_debian_apps
                ;;
            *)
                echo "Unsupported OS family for Applications: $OS_FAMILY" >&2
                exit 1
                ;;
        esac
    fi

    if [ "$DEPLOY_CONFIGS" = true ]; then
        setup_configs
    fi

    echo "=== Sway & SwayFX setup complete! ==="
}

main
