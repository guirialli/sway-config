#!/bin/bash
# Polkit Authentication Agent Launcher for Sway / Wayland

# Terminate any duplicate running polkit agents to avoid D-Bus conflicts
pkill -x -u "$USER" polkit-gnome-authentication-agent-1 lxqt-policykit-agent polkit-kde-authentication-agent-1 hyprpolkitagent mate-polkit 2>/dev/null || true
sleep 0.2

# Update D-Bus & systemd user environment cleanly
ENV_VARS=("WAYLAND_DISPLAY" "SWAYSOCK" "XDG_CURRENT_DESKTOP=sway")
if [ -n "$DISPLAY" ]; then
    ENV_VARS+=("DISPLAY")
fi

if command -v dbus-update-activation-environment &>/dev/null; then
    dbus-update-activation-environment --systemd "${ENV_VARS[@]}" &>/dev/null || true
fi
if command -v systemctl &>/dev/null; then
    systemctl --user import-environment WAYLAND_DISPLAY SWAYSOCK XDG_CURRENT_DESKTOP DISPLAY &>/dev/null || true
fi

# List of known polkit agent paths across distros (Arch, Debian, Ubuntu, Fedora, etc.)
POLKIT_AGENTS=(
    "/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1"
    "/usr/libexec/polkit-gnome-authentication-agent-1"
    "/usr/lib/policykit-1-gnome/polkit-gnome-authentication-agent-1"
    "/usr/lib/polkit-kde-authentication-agent-1"
    "/usr/libexec/polkit-kde-authentication-agent-1"
    "/usr/lib/x86_64-linux-gnu/polkit-kde-authentication-agent-1"
    "/usr/bin/lxqt-policykit-agent"
    "/usr/libexec/lxqt-policykit-agent"
    "/usr/lib/mate-polkit/polkit-mate-authentication-agent-1"
    "/usr/libexec/polkit-mate-authentication-agent-1"
    "/usr/bin/hyprpolkitagent"
    "/usr/libexec/hyprpolkitagent"
    "/usr/lib/hyprpolkitagent/hyprpolkitagent"
)

# 1. Try explicit list
for agent in "${POLKIT_AGENTS[@]}"; do
    if [ -x "$agent" ]; then
        echo "Launching Polkit Agent: $agent"
        exec "$agent"
    fi
done

# 2. Dynamic search fallback excluding helpers
DYNAMIC_AGENT=$(find /usr/lib /usr/libexec /usr/bin -maxdepth 3 \( -name "*polkit*agent*" -o -name "*policykit*agent*" \) ! -name "*helper*" -type f -executable 2>/dev/null | head -n 1)

if [ -n "$DYNAMIC_AGENT" ] && [ -x "$DYNAMIC_AGENT" ]; then
    echo "Launching dynamically discovered Polkit Agent: $DYNAMIC_AGENT"
    exec "$DYNAMIC_AGENT"
fi

echo "Error: No GUI Polkit authentication agent binary found on system!" >&2
echo "Please run: ./install.sh --install-polkit (or install 'polkit-gnome' / 'lxqt-policykit' package)." >&2
exit 1
