#!/bin/bash

# Color codes for output
YELLOW='\e[0;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Установка необходимых модулей
sudo apt install -y linux-modules-extra-$(uname -r)
sudo modprobe binder_linux devices="binder,hwbinder,vndbinder"

# Сохранение учетных данных
CREDENTIALS_FILE="$HOME/vps-android-credentials.json"
echo -e "${YELLOW}Сохраняем учетные данные в $CREDENTIALS_FILE...${NC}"
cat <<EOL > "$CREDENTIALS_FILE"
{
  "username": "${USERNAME:-default_user}",
  "password": "${PASSWORD:-default_password}"
}
EOL
chmod 600 "$CREDENTIALS_FILE"

# Проверка и загрузка образа Docker с Redroid
echo -e "${YELLOW}Загрузка последнего образа Docker с Redroid...${NC}"
if ! docker pull kasmweb/redroid:develop; then
    echo -e "${RED}Не удалось загрузить образ Docker с Redroid.${NC}"
    exit 1
else
    echo -e "${GREEN}Образ Docker с Redroid успешно загружен.${NC}"
fi

# Создание конфигурационной папки
CONFIG_DIR="$HOME/android/config"
echo -e "${YELLOW}Создаем конфигурационную папку: $CONFIG_DIR...${NC}"
mkdir -p "$CONFIG_DIR"

# Название контейнера
container_name="android"

# Запуск контейнера с Android
if [ "$(docker ps -a -q -f name=$container_name)" ]; then
    echo -e "${GREEN}Контейнер $container_name уже существует. Запускаем...${NC}"
    docker start "$container_name"
else
    echo -e "${YELLOW}Запуск нового контейнера с Android...${NC}"
    docker run -d --name "$container_name" \
        --privileged \
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
        --shm-size="2gb" \
        --restart unless-stopped \
        kasmweb/redroid:develop

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Контейнер $container_name успешно запущен.${NC}"
    else
        echo -e "${RED}Ошибка при запуске контейнера $container_name.${NC}"
        exit 1
    fi
fi
