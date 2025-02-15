#!/bin/bash

curl -s https://raw.githubusercontent.com/NodEligible/programs/refs/heads/main/display_logo.sh | bash

# Пряме посилання на ваш CSV-файл
FILE_URL="https://drive.google.com/uc?export=download&id=14DOIRJRKYLI4VKQ6L7gdfhSzgAZu4viO"
DATA_FILE="/root/multiple.csv"

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

echo -e "${YELLOW}🔄 Обновление пакетов...${NC}"
sudo apt update
sudo apt install python3 python3-pip -y

echo -e "${YELLOW}📥 Установка Main...${NC}"
bash <(curl -s https://raw.githubusercontent.com/NodEligible/programs/refs/heads/main/main.sh)
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Main успешно установлен!${NC}"
else
    echo -e "${RED}❌ Ошибка при установке Main!${NC}"
fi

echo -e "${YELLOW}📥 Установка Ufw...${NC}" 
bash <(curl -s https://raw.githubusercontent.com/NodEligible/programs/refs/heads/main/ufw.sh)
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Ufw успешно установлено!${NC}"
else
    echo -e "${RED}❌ Ошибка при установке Ufw!${NC}"
fi

echo -e "${YELLOW}Установка Gdown...${NC}"
pip install gdown

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

# Перевіряємо службу
echo "Перевіряю статус служби multiple..."
systemctl status multiple || { echo "Служба multiple не запущена, перезапускаю..."; systemctl restart multiple; }

# Очікування ініціалізації ноди
echo "Очікую 10 секунд для ініціалізації ноди..."
sleep 10

# Виводимо команду для перевірки
echo "Запускаю команду прив'язки:"
echo "./multiple-cli bind --bandwidth-download 100 --identifier \"$IDENTIFIER\" --pin \"$PIN\" --storage 200 --bandwidth-upload 100"

# Виконуємо команду
./multiple-cli bind --bandwidth-download 100 --identifier "$IDENTIFIER" --pin "$PIN" --storage 200 --bandwidth-upload 100

# Перевірка результату
if [[ $? -ne 0 ]]; then
    echo -e "${RED}❌ Помилка: Прив'язка аккаунта не вдалася.${NC}"
    exit 1
fi

# Видалення CSV
sudo rm -f "$DATA_FILE"

echo -e "${GREEN}✅ Установка завершена!${NC}"
