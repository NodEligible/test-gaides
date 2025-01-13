#!/bin/bash

# Завантаження логотипа
curl -s https://raw.githubusercontent.com/NodEligible/programs/refs/heads/main/display_logo.sh | bash

# Змінні для кольорів
YELLOW='\e[0;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Перевірка, чи передано параметри
if [ "$#" -ne 1 ]; then
    read -p "Введите адрес кошелька для ревардов: " YOUR_WALLET_ADDRESS
    if [ -z "$YOUR_WALLET_ADDRESS" ]; then
        echo -e "${RED}Адрес получения не может быть пустым. Выход...${NC}"
        exit 1
    fi
else
    YOUR_WALLET_ADDRESS=$1
fi

# Створюємо директорію для програми
sudo mkdir -p $HOME/initverse
cd $HOME/initverse

# Завантаження і підготовка файлу
wget https://github.com/Project-InitVerse/ini-miner/releases/download/v1.0.0/iniminer-linux-x64
chmod +x iniminer-linux-x64

# Створення сервісного файлу
sudo bash -c "cat > /etc/systemd/system/iniminer.service" <<EOL
[Unit]
Description=IniMiner Service
After=network.target

[Service]
Type=simple
ExecStart=$HOME/initverse/iniminer-linux-x64 --pool stratum+tcp://$YOUR_WALLET_ADDRESS.Worker001@pool-core-testnet.inichain.com:32672
Restart=always
User=$(whoami)
WorkingDirectory=$HOME/initverse

[Install]
WantedBy=multi-user.target
EOL

# Перезавантаження systemd, ввімкнення та старт сервісу
sudo systemctl daemon-reload
sudo systemctl enable iniminer
sudo systemctl start iniminer

# Перевірка статусу сервісу
SERVICE_STATUS=$(sudo systemctl is-active iniminer)

if [ "$SERVICE_STATUS" = "active" ]; then
    echo -e "${GREEN}Сервис успешно запущен!${NC}"
    echo "Проверьте статус с помощью команды: sudo systemctl status iniminer"
else
    echo -e "${RED}Ошибка запуска сервиса. Проверьте логи с помощью команды:${NC} sudo journalctl -u iniminer"
fi
