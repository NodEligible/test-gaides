#!/bin/bash

echo "Удаляем OpenLedger Node..."

# Останавливаем сервис, если он был создан
if systemctl list-units --full -all | grep -Fq "openledger-node.service"; then
    echo "Останавливаем и удаляем службу OpenLedger Node..."
    sudo systemctl stop openledger-node.service
    sudo systemctl disable openledger-node.service
    sudo rm -f /etc/systemd/system/openledger-node.service
    sudo systemctl daemon-reload
fi

# Удаляем установленный пакет
if dpkg -l | grep -Fq "openledger-node"; then
    echo "Удаляем пакет openledger-node..."
    sudo dpkg --remove openledger-node
    sudo apt-get autoremove -y
else
    echo "Пакет openledger-node не найден."
fi

# Удаляем скачанные файлы
if [ -f "openledger-node-1.0.0-linux.zip" ]; then
    echo "Удаляем архив openledger-node.zip..."
    rm -f openledger-node-1.0.0-linux.zip
fi

if [ -f "openledger-node-1.0.0.deb" ]; then
    echo "Удаляем файл .deb..."
    rm -f openledger-node-1.0.0.deb
fi

# Удаляем временные файлы или каталоги, если они есть
if [ -d "/opt/OpenLedger Node" ]; then
    echo "Удаляем файлы приложения в /opt/OpenLedger Node..."
    sudo rm -rf "/opt/OpenLedger Node"
fi

# Очищаем пользовательские данные
if [ -d "$HOME/.config/OpenLedger" ]; then
    echo "Удаляем пользовательские данные OpenLedger..."
    rm -rf "$HOME/.config/OpenLedger"
fi

# Проверяем наличие Docker-контейнеров, если они были запущены для OpenLedger
if docker ps -a --format "{{.Names}}" | grep -Fq "openledger"; then
    echo "Удаляем Docker-контейнеры OpenLedger..."
    docker rm -f $(docker ps -a --format "{{.Names}}" | grep "openledger")
fi

echo "Удаление OpenLedger Node завершено!"
