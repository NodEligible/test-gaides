#!/bin/bash

# Коды цветов для вывода
YELLOW='\e[0;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Установка необходимых инструментов
echo -e "${YELLOW}Установка базовых инструментов...${NC}"
sudo apt-get update && sudo apt-get install -y wget unzip || {
    echo -e "${RED}Ошибка при установке базовых инструментов!${NC}"
    exit 1
}

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
if command -v ufw >/dev/null 2>&1; then
    echo -e "${GREEN}Ufw уже установлен, пропускаем установку.${NC}"
else
    if bash <(curl -s https://raw.githubusercontent.com/NodEligible/programs/refs/heads/main/ufw.sh); then
        echo -e "${GREEN}Ufw успешно установлен!${NC}"
    else
        echo -e "${RED}Ошибка при установке Ufw!${NC}"
        exit 1
    fi
fi

# Установка Hyperspace
echo -e "${YELLOW}Установка Hyperspace...${NC}"
if wget https://download.hyper.space/aios/linux -O hyperspace_0.2.1-cuda_amd64.dep; then
    sudo dpkg -i hyperspace_0.2.1-cuda_amd64.dep || {
        echo -e "${RED}Ошибка при установке Hyperspace! Попытка исправить зависимости...${NC}"
        sudo apt-get install -f -y && sudo dpkg -i hyperspace_0.2.1-cuda_amd64.dep || {
            echo -e "${RED}Ошибка при установке Hyperspace после исправления зависимостей!${NC}"
            rm -f hyperspace_0.2.1-cuda_amd64.dep
            exit 1
        }
    }
    echo -e "${GREEN}Hyperspace успешно установлен!${NC}"
    rm -f hyperspace_0.2.1-cuda_amd64.dep
else
    echo -e "${RED}Ошибка при загрузке файла Hyperspace!${NC}"
    exit 1
fi

# Налаштування Docker
MY_USER=$USER
if [ -z "$MY_USER" ]; then
    echo -e "${RED}Ошибка: Переменная окружения \$USER не установлена.${NC}"
    exit 1
fi

echo -e "${YELLOW}Настройка Docker для текущего пользователя...${NC}"
if sudo usermod -aG docker "$MY_USER" && sudo chown root:docker /var/run/docker.sock && sudo chmod 660 /var/run/docker.sock; then
    echo -e "${GREEN}Docker успешно настроен для пользователя ${MY_USER}!${NC}"
    echo -e "${YELLOW}Перезапустите терминал или выполните ${RED}newgrp docker${YELLOW} для применения изменений.${NC}"
else
    echo -e "${RED}Ошибка при настройке Docker!${NC}"
    exit 1
fi

echo -e "${GREEN}Установка завершена!${NC}"
echo "Нажмите Enter, чтобы выйти..."
read -r
