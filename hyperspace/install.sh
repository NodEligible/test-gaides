#!/bin/bash

# Коды цветов для вывода
YELLOW='\e[0;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Установка необходимых инструментов
echo -e "${YELLOW}Установка базовых инструментов...${NC}"
sudo apt-get install -f

# Установка Docker
echo -e "${YELLOW}Установка Docker...${NC}"
if bash <(curl -s https://raw.githubusercontent.com/NodEligible/programs/refs/heads/main/docker.sh); then
    echo -e "${GREEN}Docker успешно установлен!${NC}"
else
    echo -e "${RED}Ошибка при установке Docker!${NC}"
    exit 1
fi

# Установка Ufw
echo -e "${YELLOW}Установка Ufw...${NC}"
if bash <(curl -s https://raw.githubusercontent.com/NodEligible/programs/refs/heads/main/ufw.sh); then
    echo -e "${GREEN}Ufw успешно установлен!${NC}"
else
    echo -e "${RED}Ошибка при установке Ufw!${NC}"
    exit 1
fi

# Установка wget і unzip
echo -e "${YELLOW}Установка дополнительных пакетов...${NC}"
if sudo apt install -y wget unzip; then
    echo -e "${GREEN}Дополнительные пакеты успешно установлены!${NC}"
else
    echo -e "${RED}Ошибка при установке пакетов!${NC}"
    exit 1
fi

# Завантаження та установка Hyperspace
echo -e "${YELLOW}Установка Hyperspace...${NC}"
if wget https://github.com/hyperspaceai/hyperspace-node/releases/download/v0.2.1/hyperspace_0.2.1_amd64.deb
 && sudo dpkg -i hyperspace_0.2.1_amd64.dep; then
    echo -e "${GREEN}Hyperspace успешно установлен!${NC}"
else
    echo -e "${RED}Ошибка при установке Hyperspace!${NC}"
    exit 1
fi

# Получаем имя текущего пользователя из переменной окружения $USER
MY_USER=$USER

# Проверяем, пустое ли имя пользователя или переменная не установлена
if [ -z "$MY_USER" ]; then
    echo "Ошибка: Переменная окружения \$USER не установлена."
    exit 1
fi

# Добавляем пользователя в группу docker
sudo usermod -aG docker "$MY_USER"

# Обновляем права доступа для сокета Docker
sudo chown root:docker /var/run/docker.sock
sudo chmod 660 /var/run/docker.sock

# Удаляем файл
rm -f hyperspace_0.2.1_amd64.dep


echo -e "${GREEN}Установка завершена!${NC}"
echo "Нажмите Enter, чтобы выйти..."
read -r
