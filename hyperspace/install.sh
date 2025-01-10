#!/bin/bash

# Завантаження логотипу
curl -s https://raw.githubusercontent.com/NodEligible/programs/refs/heads/main/display_logo.sh | bash

# Коди кольорів для виводу
YELLOW='\e[0;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

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
if wget https://download.hyper.space/aios/linux -O hyperspace_0.2.1-cuda_amd64.dep && sudo dpkg -i hyperspace_0.2.1-cuda_amd64.dep; then
    echo -e "${GREEN}Hyperspace успешно установлен!${NC}"
else
    echo -e "${RED}Ошибка при установке Hyperspace!${NC}"
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
