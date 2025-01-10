#!/bin/bash

# Обновляем список пакетов
sudo apt update

# Проверяем, установлен ли Docker
if ! command -v docker &> /dev/null; then
    echo "Docker не установлен. Устанавливаем Docker..."
    sudo apt install -y docker.io
    sudo systemctl enable docker
    sudo systemctl start docker
else
    echo "Docker уже установлен."
fi

# Устанавливаем необходимые инструменты
sudo apt install -y wget unzip

# Скачиваем и распаковываем пакет
wget https://cdn.openledger.xyz/openledger-node-1.0.0-linux.zip -O openledger-node.zip
unzip openledger-node.zip

# Устанавливаем .deb пакет
sudo dpkg -i openledger-node-1.0.0.deb

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

# Проверяем, установлен ли ufw и активен ли он
if command -v ufw &> /dev/null; then
    echo "Проверяем статус ufw..."
    UFW_STATUS=$(sudo ufw status | grep -i "Status: active")
    if [ -n "$UFW_STATUS" ]; then
        echo "ufw активен. Добавляем правила для портов 5555, 8020 и 8060..."
        sudo ufw allow 5555/tcp
        sudo ufw allow 8020/tcp
        sudo ufw allow 8060/tcp
        echo "Правила для брандмауэра успешно добавлены."
    else
        echo "ufw установлен, но не активен. Пропускаем добавление правил."
    fi
else
    echo "ufw не установлен. Пропускаем настройку правил брандмауэра."
fi

echo "OpenLedger успешно установлен!"
echo "Нажмите Enter, чтобы продолжить..."
read -r
newgrp docker
