#!/bin/bash


PROFILE_ACTIVE=$(powerprofilesctl get)
PROFILES=("power-saver" "balanced" "performance")
LENGTH=${#PROFILES[@]}

current=0
if [ -z $1 ]; then
  for (( I=0; I<$LENGTH; I++ )); do
     if [[ "$PROFILE_ACTIVE" = "${PROFILES[I]}" ]]; then
        current=$((I+1))
        break 
     fi 
  done	
else
  if [[ $1 = "-p" ]]; then
     current=2
  elif [[ $1 = "-s" ]]; then
     current=0
  elif [[ $1 = "-b" ]]; then
     current=1	  
  else
     if [[ "$1" != "-h" ]]; then
       echo "O parametro $1 informado está incorreto!"
     fi
     echo "Use:"
     echo "    -p -> para setar no modo perfomace"
     echo "    -b -> para setar no modo balanceado"
     echo "    -s -> para setar no modo econômia de energia"
     exit 1
  fi
fi

if [[ "$current" = "$LENGTH" ]]; then
   current=0
fi

powerprofilesctl set "${PROFILES[current]}"
notify-send "${PROFILES[current]} setado"
