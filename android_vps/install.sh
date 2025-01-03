#!/bin/bash

# Кольорові коди для виведення
YELLOW='\e[0;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Встановлення необхідних модулів
echo -e "${YELLOW}Встановлення додаткових модулів ядра...${NC}"
sudo apt install -y linux-modules-extra-$(uname -r)
if [ $? -ne 0 ]; then
    echo -e "${RED}Не вдалося встановити додаткові модулі ядра.${NC}"
    exit 1
fi

echo -e "${YELLOW}Завантаження модуля binder_linux...${NC}"
sudo modprobe binder_linux devices="binder,hwbinder,vndbinder"
if [ $? -ne 0 ]; then
    echo -e "${RED}Не вдалося завантажити модуль binder_linux.${NC}"
    exit 1
fi

# Збереження облікових даних
CREDENTIALS_FILE="$HOME/vps-android-credentials.json"
echo -e "${YELLOW}Збереження облікових даних у $CREDENTIALS_FILE...${NC}"
cat <<EOL > "$CREDENTIALS_FILE"
{
  "username": "${USERNAME:-default_user}",
  "password": "${PASSWORD:-default_password}"
}
EOL
chmod 600 "$CREDENTIALS_FILE"

# Завантаження останнього образу Docker з Redroid
echo -e "${YELLOW}Завантаження останнього образу Docker з Redroid...${NC}"
if ! docker pull kasmweb/redroid:develop; then
    echo -e "${RED}Не вдалося завантажити образ Docker з Redroid.${NC}"
    exit 1
else
    echo -e "${GREEN}Образ Docker з Redroid успішно завантажено.${NC}"
fi

# Створення конфігураційної папки
CONFIG_DIR="$HOME/android/config"
echo -e "${YELLOW}Створення конфігураційної папки: $CONFIG_DIR...${NC}"
mkdir -p "$CONFIG_DIR"

# Назва контейнера
container_name="android"

# Запуск контейнера з Android
if [ "$(docker ps -a -q -f name=$container_name)" ]; then
    echo -e "${GREEN}Контейнер $container_name вже існує. Запуск...${NC}"
    docker start "$container_name"
else
    echo -e "${YELLOW}Запуск нового контейнера з Android...${NC}"
    docker run -d --name "$container_name" \
        --privileged \
        -e TITLE=NodEligible \
        -e VNC_PW=password \
        -e REDROID_GPU_GUEST_MODE=guest \
        -e REDROID_WIDTH=1280 \
        -e REDROID_HEIGHT=720 \
        -e REDROID_FPS=30 \
        -e CUSTOM_USER="${USERNAME:-default_user}" \
        -e PASSWORD="${PASSWORD:-default_password}" \
        -e LANGUAGE=ru_RU.UTF-8 \
        -v "$CONFIG_DIR:/config" \
        -p 6901:6901 \
        -p 5901:5901 \
        -p 4901:4901 \
        --shm-size="2gb" \
        --restart unless-stopped \
        kasmweb/redroid:develop

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Контейнер $container_name успішно запущено.${NC}"
    else
        echo -e "${RED}Помилка під час запуску контейнера $container_name.${NC}"
        exit 1
    fi
fi
