#!/bin/bash

# Display the logo (assuming it's needed)
curl -s https://raw.githubusercontent.com/NodEligible/programs/refs/heads/main/display_logo.sh | bash


sudo locale-gen ru_RU.UTF-8
sudo update-locale

sudo ufw allow 3002/tcp
sudo ufw allow 10000/tcp

# Color codes for output
YELLOW='\e[0;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Обновление и установка зависимостей
echo -e "${YELLOW}Обновление пакетов...${NC}"
sudo apt update && sudo apt upgrade -y
if [ $? -eq 0 ]; then
    echo -e "${GREEN}Пакеты успешно обновлены!${NC}"
else
    echo -e "${RED}Ошибка при обновлении пакетов!${NC}"
    exit 1
fi

echo -e "${YELLOW}Установка Docker...${NC}"
bash <(curl -s https://raw.githubusercontent.com/NodEligible/programs/refs/heads/main/docker.sh)
if [ $? -eq 0 ]; then
    echo -e "${GREEN}Docker успешно установлен!${NC}"
else
    echo -e "${RED}Ошибка при установке Docker!${NC}"
    exit 1
fi

# Получение внешнего IP-адреса
SERVER_IP=$(hostname -I | awk '{print $1}')
SERVER_URL="http://${SERVER_IP}"

echo -e "${YELLOW}Автоматически определен IP-адрес сервера: ${SERVER_IP}${NC}"
echo -e "${YELLOW}SERVER_URL: ${SERVER_URL}${NC}"

# Запрашиваем имя пользователя
read -p "Введите имя пользователя: " USERNAME

# Запрашиваем пароль с подтверждением
read -s -p "Введите пароль: " PASSWORD
echo
read -s -p "Подтвердите пароль: " PASSWORD_CONFIRM
echo

if [ "$PASSWORD" != "$PASSWORD_CONFIRM" ]; then
    echo -e "${RED}Пароли не совпадают. Попробуйте снова.${NC}"
    exit 1
fi

# Сохранение учетных данных
CREDENTIALS_FILE="$HOME/vps-browser-credentials.json"
cat <<EOL > "$CREDENTIALS_FILE"
{
  "username": "$USERNAME",
  "password": "$PASSWORD"
}
EOL
chmod 600 "$CREDENTIALS_FILE"

# Проверка и загрузка образа Docker с Chromium
echo -e "${YELLOW}Загрузка последнего образа Docker с Chromium...${NC}"
if ! docker pull linuxserver/chromium:latest; then
    echo -e "${RED}Не удалось загрузить образ Docker с Chromium.${NC}"
    exit 1
else
    echo -e "${GREEN}Образ Docker с Chromium успешно загружен.${NC}"
fi

# Создание конфигурационной папки
mkdir -p "$HOME/chromium/config"

# Название контейнера
container_name="browser"

# Запуск контейнера с Chromium
if [ "$(docker ps -a -q -f name=$container_name)" ]; then
    echo -e "${GREEN}Контейнер $container_name уже существует. Запускаем...${NC}"
    docker start "$container_name"
else
    echo -e "${YELLOW}Запуск контейнера с Chromium...${NC}"

    docker run -d --name "$container_name" \
        --privileged \
        -e TITLE=ShishkaCrypto \
        -e DISPLAY=:1 \
        -e PUID=1000 \
        -e PGID=1000 \
        -e CUSTOM_USER="$USERNAME" \
        -e PASSWORD="$PASSWORD" \
        -e LANGUAGE=ru_RU.UTF-8 \
        -v "$HOME/chromium/config:/config" \
        -p 10000:3000 \
        --shm-size="2gb" \
        --restart unless-stopped \
        lscr.io/linuxserver/chromium:latest

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Контейнер с Chromium успешно запущен.${NC}"
    else
        echo -e "${RED}Не удалось запустить контейнер с Chromium.${NC}"
        exit 1
    fi
fi

# Вывод информации для пользователя
echo -e "${YELLOW}Открывайте браузер по адресу: ${SERVER_URL}:10000/${NC}"
echo -e "${YELLOW}Имя пользователя: $USERNAME${NC}"
echo -e "${YELLOW}Введите ваш пароль при входе.${NC}"
