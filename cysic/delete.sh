#!/bin/bash

YELLOW='\e[0;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}Остановка сервиса Cysic Verifier...${NC}"
sudo systemctl stop cysic-verifier.service &>/dev/null

echo -e "${YELLOW}Отключение автозапуска сервиса...${NC}"
sudo systemctl disable cysic-verifier.service &>/dev/null

echo -e "${YELLOW}Удаление сервисного файла...${NC}"
sudo rm -f /etc/systemd/system/cysic-verifier.service
sudo systemctl daemon-reload

echo -e "${YELLOW}Завершение процесса verifier...${NC}"
pkill -f "./verifier"

echo -e "${YELLOW}Удаление файлов ноды...${NC}"
rm -rf ~/cysic-verifier
rm -f ~/cysic-verifier/logs.txt
rm -f ~/cysic-verifier/manage_verifier.sh
rm -rf $HOME/.cysic

echo -e "${GREEN}Нода Cysic успешно удалена!${NC}"
