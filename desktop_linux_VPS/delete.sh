#!/bin/bash

# Определение цветовых кодов
YELLOW='\e[0;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' 

echo -e "${YELLOW}Удаление созданного пользователя и его данных...${NC}"
read -p "Введите имя пользователя, созданного для удалённого доступа: " USER

if id "$USER" &>/dev/null; then
    sudo deluser --remove-home $USER
    echo -e "${GREEN}Пользователь $USER и его данные удалены.${NC}"
else
    echo -e "${RED}Пользователь $USER не найден.${NC}"
fi

echo -e "${YELLOW}Удаление XFCE рабочего окружения...${NC}"
sudo apt remove --purge -y xfce4 xfce4-goodies
sudo apt autoremove -y
echo -e "${GREEN}XFCE удалён.${NC}"

echo -e "${YELLOW}Удаление XRDP...${NC}"
sudo apt remove --purge -y xrdp
sudo rm -rf /etc/xrdp
echo -e "${GREEN}XRDP удалён.${NC}"

echo -e "${YELLOW}Удаление Google Chrome...${NC}"
sudo apt remove --purge -y google-chrome-stable
sudo rm -rf /etc/apt/sources.list.d/google-chrome.list
sudo apt update
echo -e "${GREEN}Google Chrome удалён.${NC}"

echo -e "${YELLOW}Удаление оставшихся пакетов и очистка системы...${NC}"
sudo apt autoremove --purge -y
sudo apt clean
echo -e "${GREEN}Система очищена.${NC}"

echo -e "${GREEN}Удаление завершено. Все компоненты, установленные ранее, были успешно удалены.${NC}"
