actual=$(powerprofilesctl get)

if [[ "$actual" = "power-saver" ]]; then
   icon=""
elif [[ "$actual" = "balanced" ]]; then
   icon=""
else
   icon=""
fi

echo "{\"text\": \"$icon\", \"tooltip\": \"Power Profile: $actual\"}"

