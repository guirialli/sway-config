#!/bin/bash

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$SCRIPT_DIR/src"
OUT_DIR="$HOME/.config"
CONFIGS=("foot"  "mako"  "sway"  "swaylock"  "waybar"  "wofi")

# pacotes
sudo pacman -S python-gobject xorg-xwayland waybar swayidle brightnessctl wofi pavucontrol blueman networkmanager mako swaybg grim slurp wl-clipboard pipewire pipewire-pulse xdg-desktop-portal-wlr xdg-desktop-portal-gtk  foot pipewire-alsa gnome-keyring steam nautilus mpv celluloid 

# Serviços
sudo systemctl enable --now NetworkManager.service bluetooth.service

# Pacotes do Aur
yay -S swayfx swaylock-effects ulauncher heroic-games-launcher-bin bottles vesktop-bin

for item in "${CONFIGS[@]}"; do
   CONFIG="$SRC_DIR/$item"
   OUT="$OUT_DIR/$item"
   if [[ -f "$OUT" ||  -d "$OUT" ]]; then
      rm -rf "$OUT"
   fi

   ln -s "$CONFIG" "$OUT"
done
