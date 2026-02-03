#!/usr/bin/env bash

WORK_PATH="$HOME/.config/theme_toggle"
FILE="$WORK_PATH/theme"

mkdir -p "$WORK_PATH"

if [ ! -f "$FILE" ]; then
   echo "light" > "$FILE"
fi

THEME=$(cat "$FILE")



if [ "$THEME" = "light" ]; then
   gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
   gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark'

   echo "dark" > "$FILE"
else
   gsettings set org.gnome.desktop.interface color-scheme 'prefer-light'
   gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita'

   echo "light" > "$FILE"
fi

THEME=$(cat "$FILE")

echo "Trocando para o tema $THEME"
