#!/bin/bash

curl -s https://raw.githubusercontent.com/NodEligible/programs/refs/heads/main/display_logo.sh | bash

# Пряме посилання на ваш CSV-файл
FILE_URL="https://drive.google.com/uc?export=download&id=1VBcl79bnmqsrNb4UwSH4PYpKGQrx-UH2"
DATA_FILE="/root/data.csv"

# Завантаження CSV-файлу
echo "Завантажую CSV файл з Google Drive..."
wget -O "$DATA_FILE" "$FILE_URL"

# Перевірка, чи файл завантажено
if [[ ! -f "$DATA_FILE" ]]; then
    echo "Помилка: CSV файл не завантажено."
    exit 1
fi

# Перевіряємо вміст файлу
echo "Вміст файлу CSV:"
cat "$DATA_FILE"

# Знаходимо дані для цього сервера
server_ip=$(hostname -I | awk '{print $1}')

# Зчитуємо відповідні дані з CSV
server_data=$(grep "^$server_ip," "$DATA_FILE" | head -n 1)

if [[ -z "$server_data" ]]; then
    echo "❌ Дані для сервера $server_ip не знайдено в CSV."
    exit 1
fi

# Отримуємо IDENTIFIER та PIN
IDENTIFIER=$(echo "$server_data" | cut -d',' -f2 | xargs)
PIN=$(echo "$server_data" | cut -d',' -f3 | xargs)

# Виводимо знайдені дані
echo "IDENTIFIER: $IDENTIFIER"
echo "PIN: $PIN"


# Основний процес встановлення
YELLOW='\e[0;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}🚀 Установка Multiple...${NC}"
gdown --id 1KRKoEyex7hyX5zXPDCJW_kP4G6XX5mNU -O multipleforlinux.tar

# Розпакування архіву
tar -xvf multipleforlinux.tar
rm -rf multipleforlinux.tar

# Перехід у директорію
cd multipleforlinux
chmod +x ./multiple-cli
chmod +x ./multiple-node

# Додавання до PATH
echo "PATH=\$PATH:$(pwd)" >> $HOME/.bash_profile
source $HOME/.bash_profile

sudo tee /etc/systemd/system/multiple.service > /dev/null << EOF
[Unit]
Description=Multiple Network node client on a Linux Operating System
After=network-online.target

[Service]
User=$USER
ExecStart=$HOME/multipleforlinux/multiple-node
Restart=on-failure
RestartSec=10
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable multiple
sudo systemctl start multiple

# Виконуємо команду
./multiple-cli bind --bandwidth-download 100 --identifier "$IDENTIFIER" --pin "$PIN" --storage 200 --bandwidth-upload 100

# Перевірка результату
if [[ $? -ne 0 ]]; then
    echo -e "${RED}Ошибка: Не удалось выполнить привязку аккаунта.${NC}"
    exit 1
fi

# Видалення CSV
sudo rm -f "$DATA_FILE"

echo -e "${GREEN}Установка завершена!${NC}"
