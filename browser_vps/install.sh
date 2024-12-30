#!/bin/bash

# Display the logo (assuming it's needed)
curl -s https://raw.githubusercontent.com/NodEligible/programs/refs/heads/main/display_logo.sh | bash

# Color codes for output
YELLOW='\e[0;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Проверяем, установлена ли локаль ru_RU.UTF-8
if locale -a | grep -q "ru_RU.utf8"; then
    echo -e "${YELLOW}Локаль ru_RU.UTF-8 уже установлена. Пропускаем установку.${NC}"
else
    echo -e "${YELLOW}Локаль ru_RU.UTF-8 не найдена. Устанавливаем...${NC}"
    sudo locale-gen ru_RU.UTF-8
    sudo update-locale LANG=ru_RU.UTF-8
    echo -e "${GREEN}Локаль ru_RU.UTF-8 успешно установлена.${NC}"
fi

sudo ufw allow 21000/tcp
sudo ufw allow 22000/tcp

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
BROWSER_URL="${SERVER_IP}"

echo -e "${YELLOW}Автоматически определен IP-адрес сервера: ${SERVER_IP}${NC}"

# Запрашиваем имя пользователя
if [ -z "$USERNAME" ]; then
   echo -e "Введите имя пользователя:"
   read -r USERNAME
fi

# Запрашиваем пароль с подтверждением
if [ -z "$PASSWORD" ]; then
    echo -e "Введите пароль:"
    read -s -r PASSWORD
    echo
    echo -e "Подтвердите пароль:"
    read -s -r PASSWORD_CONFIRM
    echo

    if [ "$PASSWORD" != "$PASSWORD_CONFIRM" ]; then
        echo -e "${RED}Пароли не совпадают. Попробуйте снова.${NC}"
        exit 1
    fi
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
        -e FAVICON_URL="https://raw.githubusercontent.com/NodEligible/test-gaides/refs/heads/main/NodEligible_logo.ico" \
        -e TITLE=NodEligible \
        -e DISPLAY=:1 \
        -e PUID=1000 \
        -e PGID=1000 \
        -e CUSTOM_USER="$USERNAME" \
        -e PASSWORD="$PASSWORD" \
        -e LANGUAGE=ru_RU.UTF-8 \
        -v "$HOME/chromium/config:/config" \
        -p 21000:3000 \
        -p 22000:3001 \
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
echo -e "${YELLOW}Открывайте браузер по адресу: http://${SERVER_IP}:21000/${NC}"
echo -e "${YELLOW}Имя пользователя: $USERNAME${NC}"
echo -e "${YELLOW}Введите ваш пароль при входе.${NC}"
