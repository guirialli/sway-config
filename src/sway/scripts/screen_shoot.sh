#!/bin/bash

MODE=$1
PICTURE_DIR=$(xdg-user-dir PICTURES)
FOLDER="$PICTURE_DIR/screeshots"
FILE="$FOLDER/screenshot_$(date +%F_%T).png"
VALID_MODE=("-s" "-g" "-w")

# Tratnado os parametros
if [ -z $1 ]; then
	MODE='-s'
fi

found=false
for item in "${VALID_MODE[@]}"; do
	if [[ "$item" == "$MODE" ]]; then
		found=true
		break
	fi
done
if [[ "$found" == false ]]; then
	echo "Erro: modo $MODE é invalido!"
	echo "Use: "
	echo "    -s -> para tirar screenshot de uma tela;"
	echo "    -w -> para tirar screenshot de uma janela;"
	echo "    -g -> para tirar screenshot de uma area selecionada;"
	exit 1
fi


mkdir -p $FOLDER
if [[ "$MODE" = -g ]]; then
    grim -g "$(slurp)" "$FILE" 
elif [[ "$MODE" = -w ]]; then
	grim -g "$(swaymsg -t get_tree | jq -r '.. | select(.focused? == true).rect | "\(.x),\(.y) \(.width)x\(.height)"')" "$FILE"

elif [[ "$MODE" = -s ]]; then
	grim -g "$(slurp -o)" "$FILE"
fi

wl-copy < $FILE
