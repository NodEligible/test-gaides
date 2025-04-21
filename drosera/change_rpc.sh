#!/bin/bash

curl -s https://raw.githubusercontent.com/NodEligible/programs/refs/heads/main/display_logo.sh | bash

YELLOW='\e[0;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[38;5;81m'
NC='\033[0m'

config_file=~/drosera/drosera.toml
service_file="/etc/systemd/system/drosera.service"

echo -e "${BLUE}📡 Введите новый RPC:${NC}"
read -p "➜ " new_rpc
if [ -f "$config_file" ]; then
    sed -i "s|^ethereum_rpc = \".*\"|ethereum_rpc = \"$new_rpc\"|" "$config_file"
    echo -e "${GREEN}RPC изменен в файле $config_file${NC}"
else
    echo -e "${RED}Файл $config_file не найден${NC}"
    exit 1
fi

if [ ! -f "$service_file" ]; then
   echo -e "${RED}Файл сервиса не найден: $service_file${NC}"
    exit 1
fi

sed -i -E 's|--eth-rpc-url [^ ]+|--eth-rpc-url '"$new_rpc"'|g' "$service_file"

echo -e "${GREEN}Изменен --eth-rpc-url в файле $service_file${NC}"



systemctl daemon-reexec
systemctl daemon-reload
systemctl restart drosera.service
echo -e "${GREEN} Изменение RPC завершено! ${NC}"
