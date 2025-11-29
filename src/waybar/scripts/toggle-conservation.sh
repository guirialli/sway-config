#!/bin/bash

# Caminho para o arquivo de controle do Conservation Mode (pode variar ligeiramente)
CONTROL_FILE="/sys/bus/platform/drivers/ideapad_acpi/VPC2004:00/conservation_mode"

#Verifica se o arquivo existe e se temos permissão de escrita
if [ ! -f "$CONTROL_FILE" ] || [ ! -w "$CONTROL_FILE" ]; then
    echo "ERROR: Arquivo de controle não encontrado ou sem permissão de escrita."
    # Tente o caminho alternativo se necessário (ex: legacy_mode)
   exit 1
fi

# Le o estado atual (0 ou 1)
CURRENT_STATE=$(cat "$CONTROL_FILE")

# Alterna o estado (Toggle)
if [ "$CURRENT_STATE" -eq 1 ]; then
    # Se estiver ligado (1), desliga (0)
    NEW_STATE=0
    echo "Conservation Mode desligado."
else
    # Se estiver desligado (0), liga (1)
    NEW_STATE=1
    echo "Conservation Mode ligado."
fi

# Escreve o novo estado no arquivo do sistema
echo $NEW_STATE | tee "$CONTROL_FILE" > /dev/null
