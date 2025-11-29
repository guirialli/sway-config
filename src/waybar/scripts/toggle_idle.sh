#!/bin/bash

STATE_FILE="$HOME/.cache/swayidle_enabled"

# Estado inicial: suspensão ATIVADA
if [ ! -f "$STATE_FILE" ]; then
    echo "off" > "$STATE_FILE"
fi

STATE=$(cat "$STATE_FILE")

if [ "$STATE" = "on" ]; then
    # DESATIVAR suspensão
    killall swayidle
    echo "off" > "$STATE_FILE"
    notify-send "Supensão desativada!"
else
    # ATIVAR suspensão
    swayidle -w \
    	timeout 300 'swaylock -f' \
    	timeout 600 'swaymsg "output * dpms off"' \
    	resume 'swaymsg "output * dpms on"' \
    	before-sleep 'swaylock -f' &
    echo "on" > "$STATE_FILE"
    notify-send "Supensão ativa!"
fi
