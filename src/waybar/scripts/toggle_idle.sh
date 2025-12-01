#!/bin/bash

STATE_FILE="$HOME/.cache/swayidle_enabled"
TIMEOUT_LOCK=$((3*60))
TIMEOUT_SLEEP=$((5*60))

if [ ! -f "$STATE_FILE" ]; then
    echo "off" > "$STATE_FILE"
fi

STATE=$(cat "$STATE_FILE")

if [[ "$1" = "-s" ]]; then
     STATE="off"
fi


killall swayidle
if [ "$STATE" = "on" ]; then
    # DESATIVAR suspensão
    echo "off" > "$STATE_FILE"
    MESSAGE="Supensão desativada!"
else
    swayidle -w \
    	timeout "$TIMEOUT_LOCK" 'swaylock -f' \
    	timeout "$TIMEOUT_SLEEP" 'swaymsg "output * dpms off"' \
    	resume 'swaymsg "output * dpms on"' \
    	before-sleep 'swaylock -f' &
    echo "on" > "$STATE_FILE"
    MESSAGE="Supensão ativada!"
fi

if [[ ! "$1" = '-s' ]]; then
    notify-send "$MESSAGE"
fi

