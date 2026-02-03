#!/bin/bash

WORK_PATH="$HOME/.config/theme_toggle"
FILE="$WORK_PATH/theme"

THEME="light"
if [ -f "$FILE" ]; then
  THEME=$(cat "$FILE")
fi


DARK='{"text": "🌕", "tooltip": "Tema Dark", "class": "theme-dark"}' 
LIGHT='{"text": "☀️", "tooltip": "Tema Light", "class": "theme-light"}' 

if [ "$THEME" = "light" ]; then 
	echo "$LIGHT" 
else 
	echo "$DARK" 
fi
