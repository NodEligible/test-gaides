#!/bin/bash

curl -s https://raw.githubusercontent.com/NodEligible/programs/refs/heads/main/display_logo.sh | bash

# Сменные для цветов
YELLOW='\e[0;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}Остановка сервиса${NC}"
if [ -d "$HOME/dill" ]; then
    sudo systemctl stop dill 
    sudo systemctl disable dill 
    sudo systemctl daemon-reload 
    cd $HOME/dill
    bash stop_dill_node.sh
    rm -f /etc/systemd/system/dill.service
fi


echo -e "${YELLOW}Обновляем Dill${NC}"
cd $HOME
wget https://raw.githubusercontent.com/DillLabs/launch-dill-node/main/upgrade.sh -O $HOME/upgrade.sh
chmod +x upgrade.sh
sed -i 's|\./start_dill_node\.sh| |' "$HOME/upgrade.sh"
./upgrade.sh 
rm -rf $HOME/upgrade.sh

# Меняем дефолтные порты
sed -i 's|monitoring-port  9080 tcp|monitoring-port  8380 tcp|' "$HOME/dill/default_ports.txt"
sed -i 's|exec-http.port 8545 tcp|exec-http.port 8945 tcp|' "$HOME/dill/default_ports.txt"
sed -i 's|exec-port 30303 tcp|exec-port 30305 tcp|g; s|exec-port 30303 udp|exec-port 30305 udp|g' "$HOME/dill/default_ports.txt"

echo -e "${GREEN}Обновление завершено!${NC}"
