#!/bin/bash

curl -s https://raw.githubusercontent.com/NodEligible/programs/refs/heads/main/display_logo.sh | bash

# Пряме посилання на ваш CSV-файл
FILE_URL="https://drive.google.com/uc?export=download&id=1VBcl79bnmqsrNb4UwSH4PYpKGQrx-UH2"
DATA_FILE="/root/data.csv"

# Завантаження CSV-файлу
echo "Завантажую CSV файл з Google Drive..."
wget -O "$DATA_FILE" "$FILE_URL"

if [[ ! -f "$DATA_FILE" ]]; then
    echo "Помилка: CSV файл не завантажено."
    exit 1
fi

# Перевіряємо вміст файлу
echo "Вміст файлу CSV:"
cat "$DATA_FILE"

# Функція для пошуку даних у CSV
get_server_data() {
    local server_ip="$1"
    echo "Шукаю дані для IP: $server_ip"
    while IFS=',' read -r ip identifier pin; do
        ip=$(echo "$ip" | xargs)  # Видаляємо зайві пробіли
        identifier=$(echo "$identifier" | xargs)
        pin=$(echo "$pin" | xargs)
        
        echo "Читаю рядок: IP=$ip, ID=$identifier, PIN=$pin"

        if [[ "$ip" == "$server_ip" ]]; then
            echo "$identifier $pin"
            return 0
        fi
    done < <(tail -n +2 "$DATA_FILE")  # Пропускаємо заголовок
    echo ""
    return 1
}


# Знаходимо дані для цього сервера
server_ip=$(hostname -I | awk '{print $1}')
echo "IP сервера: $server_ip"
server_data=$(get_server_data "$server_ip")

if [[ -z "$server_data" ]]; then
    echo -e "${RED}❌ Дані для сервера $server_ip не знайдено в CSV.${NC}"
    exit 1
fi

IDENTIFIER=$(echo "$server_data" | awk '{print $1}')
PIN=$(echo "$server_data" | awk '{print $2}')

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
