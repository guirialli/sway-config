#!/bin/bash
CONTROL_FILE="/sys/bus/platform/drivers/ideapad_acpi/VPC2004:00/conservation_mode"

# Verifica o estado
if [ -f "$CONTROL_FILE" ]; then
    CURRENT_STATE=$(cat "$CONTROL_FILE")
else
    # Retorna erro se o arquivo nao existir (ex: nao e um Lenovo IdeaPad)
    echo '{"text": "ERR", "class": "error", "tooltip": "Conservation File missing"}'
    exit 1
fi

if [ "$CURRENT_STATE" -eq 1 ]; then
    # Estado: LIGADO
    echo '{"text": "", "class": "conservation-on", "tooltip": "Conservação: LIGADO"}'
else
    # Estado: DESLIGADO
    echo '{"text": "", "class": "conservation-off", "tooltip": "Conservação: DESLIGADO"}'
fi
