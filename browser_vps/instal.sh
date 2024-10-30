#!/bin/bash

# Цвета для вывода
GREEN="\033[32m"
RED="\033[31m"
RESET="\033[0m"

show() {
  echo -e "${GREEN}$1${RESET}"
}

error() {
  echo -e "${RED}$1${RESET}"
}

# Проверка на запуск от имени root
if [ "$EUID" -ne 0 ]; then
  error "Пожалуйста, запустите скрипт с правами root."
  exit 1
fi

# Вывод логотипа
display_logo() {
  echo -e '\e[0;37m'
  echo "███╗   ██╗ ██████╗ ██████╗ ███████╗██╗     ██╗ ██████╗ ██╗██████╗ ██╗     ███████╗"
  echo "████╗  ██║██╔═══██╗██╔══██╗██╔════╝██║     ██║██╔════╝ ██║██╔══██╗██║     ██╔════╝"
  echo "██╔██╗ ██║██║   ██║██║  ██║█████╗  ██║     ██║██║  ███╗██║██████╔╝██║     █████╗  "
  echo "██║╚██╗██║██║   ██║██║  ██║██╔══╝  ██║     ██║██║   ██║██║██╔══██╗██║     ██╔══╝  "
  echo "██║ ╚████║╚██████╔╝██████╔╝███████╗███████╗██║╚██████╔╝██║██████╔╝███████╗███████╗"
  echo "╚═╝  ╚═══╝ ╚═════╝ ╚═════╝ ╚══════╝╚══════╝╚═╝ ╚═════╝ ╚═╝╚═════╝ ╚══════╝╚══════╝"                                                                       
  echo -e '\e[0m'
}

# Функция для логирования
log_message() {
  echo -e "\e[33m'$1'\e[0m"
}

# Отображение логотипа
display_logo

# Обновление и установка зависимостей
show "Обновление системы и установка зависимостей..."
sudo apt update && sudo apt upgrade -y

for package in git curl; do
  if ! [ -x "$(command -v $package)" ]; then
    show "Устанавливаю $package..."
    sudo apt install -y $package
  else
    show "$package уже установлен."
  fi
done

# Проверка и установка Docker
if ! [ -x "$(command -v docker)" ]; then
  show "Установка Docker..."
  curl -fsSL https://get.docker.com | sh
  if ! [ -x "$(command -v docker)" ]; then
    error "Не удалось установить Docker."
    exit 1
  else
    show "Docker успешно установлен."
  fi
else
  show "Docker уже установлен."
fi

# Получение внешнего IP-адреса
IP=$(curl -s ifconfig.me)
if [ -z "$IP" ]; then
  error "Не удалось получить внешний IP адрес."
  exit 1
fi

# Запрашиваем имя пользователя
read -p "Введите имя пользователя: " USERNAME

# Запрашиваем пароль с подтверждением
read -s -p "Введите пароль: " PASSWORD
echo  # Переход на новую строку
read -s -p "Подтвердите пароль: " PASSWORD_CONFIRM
echo

if [ "$PASSWORD" != "$PASSWORD_CONFIRM" ]; then
  error "Пароли не совпадают. Пожалуйста, запустите скрипт заново и введите пароли правильно."
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

# Проверка и загрузка образа Docker с Chromium
show "Загрузка последнего образа Docker с Chromium..."
if ! docker pull linuxserver/chromium:latest; then
  error "Не удалось загрузить образ Docker с Chromium."
  exit 1
else
  show "Образ Docker с Chromium успешно загружен."
fi

# Создание конфигурационной папки
mkdir -p "$HOME/chromium/config"

# Запуск контейнера с Chromium
container_name="maycrypto_browser_$USERNAME"
if [ "$(docker ps -q -f name=$container_name)" ]; then
  show "Контейнер $container_name уже запущен."
else
  show "Запуск контейнера с Chromium..."

  docker run -d --name "$container_name" \
    --privileged \
    -e TITLE=ShishkaCrypto \
    -e DISPLAY=:1 \
    -e PUID=1000 \
    -e PGID=1000 \
    -e CUSTOM_USER="$USERNAME" \
    -e PASSWORD="$PASSWORD" \
    -e LANGUAGE=en_US.UTF-8 \
    -v "$HOME/chromium/config:/config" \
    -p 10000:3000 \
    --shm-size="2gb" \
    --restart unless-stopped \
    lscr.io/linuxserver/chromium:latest

  if [ $? -eq 0 ]; then
    show "Контейнер с Chromium успешно запущен."
  else
    error "Не удалось запустить контейнер с Chromium."
    exit 1
  fi
fi

# Вывод информации для пользователя
show "${GREEN}Откройте этот адрес http://$IP:10000/ для запуска браузера извне${RESET}"
show "${GREEN}Введите имя пользователя: $USERNAME${RESET}"
show "${GREEN}Введите пароль в браузере${RESET}"
show "${GREEN}Не забудьте подписаться https://t.me/maycrypto${RESET}"
