#!/usr/bin/env bash

WORK_PATH="$HOME/.config/theme_toggle"
FILE="$WORK_PATH/theme"
FOOT_DIR="$HOME/.config/foot"
FOOT_FILE="$FOOT_DIR/foot.ini"

mkdir -p "$WORK_PATH"
mkdir -p "$FOOT_DIR"

if [ ! -f "$FILE" ]; then
   echo "light" > "$FILE"
fi


THEME=$(cat "$FILE")

function trocar_tema_gnome() {
  local gtk4=$1
  local gtk3=$2
  gsettings set org.gnome.desktop.interface color-scheme "$gtk4"
  gsettings set org.gnome.desktop.interface gtk-theme "$gtk3"
  
}

function trocar_tema_foot () {
   if [ -f "$FOOT_FILE" ]; then
	rm "$FOOT_FILE"
   fi
   local theme_file=$1
   cp "$FOOT_DIR/themes/$theme_file" "$FOOT_FILE"
}



if [ "$THEME" = "light" ]; then
   trocar_tema_gnome "prefer-dark" "Adwaita-dark"
   trocar_tema_foot "black.ini"
   THEME="dark" 
else
   trocar_tema_gnome "prefer-light" "Adwaita"
   trocar_tema_foot "white.ini"
   THEME="light"
fi

echo "$THEME" > "$FILE"
echo "Trocando para o tema $THEME"
