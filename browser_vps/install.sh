#!/bin/bash

# Display the logo (assuming it's needed)
curl -s https://raw.githubusercontent.com/NodEligible/programs/refs/heads/main/display_logo.sh | bash

sudo locale-gen ru_RU.UTF-8
sudo update-locale

sudo ufw allow 11000/tcp
sudo ufw allow 3002/tcp

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
BROWSER_URL="http://${SERVER_IP}:11000"

echo -e "${YELLOW}Автоматически определен IP-адрес сервера: ${SERVER_IP}${NC}"

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

# Создание кастомного Dockerfile
DOCKERFILE_PATH="$HOME/Dockerfile"
cat <<EOL > "$DOCKERFILE_PATH"
FROM lscr.io/linuxserver/chromium:latest

# Зміна оголошеного порту
EXPOSE 3002

# Заміна портів у конфігурації
RUN sed -i 's|3000|3002|g' /etc/nginx/sites-available/default && \\
    sed -i 's|3000|3002|g' /etc/s6-overlay/s6-rc.d/init-nginx/run

# CMD для запуску
CMD ["/init"]
EOL

# Построение кастомного образа
echo -e "${YELLOW}Создание кастомного Docker-образа...${NC}"
docker build -t custom-chromium "$HOME"
if [ $? -eq 0 ]; then
    echo -e "${GREEN}Кастомный Docker-образ успешно создан.${NC}"
else
    echo -e "${RED}Ошибка при создании Docker-образа.${NC}"
    exit 1
fi

# Создание конфигурационной папки
mkdir -p "$HOME/chromium/config"

# Название контейнера
container_name="browser"

# Запуск контейнера с кастомным образом
if [ "$(docker ps -a -q -f name=$container_name)" ]; then
    echo -e "${GREEN}Контейнер $container_name уже существует. Запускаем...${NC}"
    docker start "$container_name"
else
    echo -e "${YELLOW}Запуск контейнера с кастомным Docker-образом...${NC}"

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
        -p 11000:3002 \
        --shm-size="2gb" \
        --restart unless-stopped \
        custom-chromium

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Контейнер с Chromium успешно запущен.${NC}"
    else
        echo -e "${RED}Не удалось запустить контейнер с Chromium.${NC}"
        exit 1
    fi
fi

# Вывод информации для пользователя
echo -e "${YELLOW}Открывайте браузер по адресу: http://${SERVER_IP}:11000/${NC}"
echo -e "${YELLOW}Имя пользователя: $USERNAME${NC}"
echo -e "${YELLOW}Введите ваш пароль при входе.${NC}"
