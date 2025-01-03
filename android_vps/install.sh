#!/bin/bash

# Color codes for output
YELLOW='\e[0;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# установка програм
sudo apt install linux-modules-extra-`uname -r`
sudo modprobe binder_linux devices="binder,hwbinder,vndbinder"

# Сохранение учетных данных
CREDENTIALS_FILE="$HOME/vps-android-credentials.json"
cat <<EOL > "$CREDENTIALS_FILE"
{
  "username": "$USERNAME",
  "password": "$PASSWORD"
}
EOL
chmod 600 "$CREDENTIALS_FILE"

# Проверка и загрузка образа Docker с Redroid
echo -e "${YELLOW}Загрузка последнего образа Docker с Redroid...${NC}"
if ! docker pull kasmweb/redroid:latest; then
    echo -e "${RED}Не удалось загрузить образ Docker с Redroid.${NC}"
    exit 1
else
    echo -e "${GREEN}Образ Docker с Redroid успешно загружен.${NC}"
fi

# Создание конфигурационной папки
mkdir -p "$HOME/android/config"

# Название контейнера
container_name="android"

# Запуск контейнера с Android
if [ "$(docker ps -a -q -f name=$container_name)" ]; then
    echo -e "${GREEN}Контейнер $container_name уже существует. Запускаем...${NC}"
    docker start "$container_name"
else
    echo -e "${YELLOW}Запуск контейнера с Chromium...${NC}"

    docker run -d --name "$container_name" \
            --privileged \
        -e TITLE=NodEligible \
         -e VNC_PW=password \
         -e REDROID_GPU_GUEST_MODE=guest \
         -e REDROID_WIDTH=1280 \
         -e REDROID_HEIGHT=720 \
        -e REDROID_FPS=30 \
         kasmweb/redroid:develop
        -e CUSTOM_USER="$USERNAME" \
        -e PASSWORD="$PASSWORD" \
        -e LANGUAGE=ru_RU.UTF-8 \
        -v "$HOME/chromium/config:/config" \
        -p 6901:6901 \
        --shm-size="2gb" \
        --restart unless-stopped \
        lscr.io/linuxserver/redroid:latest
