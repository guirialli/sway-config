
#!/bin/bash 
PROCESSO=$(pgrep swayidle) 
DESATIVADO='{"text": "", "tooltip": "Suspensão desativada", "class": "idle-off"}' 
ATIVO='{"text": "", "tooltip": "Suspensão ativada", "class": "idle-on"}' 
if [ -z "$PROCESSO" ]; then 
	echo "$DESATIVADO" 
else 
	echo "$ATIVO" 
fi
