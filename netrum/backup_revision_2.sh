#!/bin/bash

curl -s https://raw.githubusercontent.com/NodEligible/programs/refs/heads/main/display_logo.sh | bash

# === Цвета ===
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}═══════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}     🚀 Востановление Netrum Lite Node CLI${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════════════════${NC}"
sleep 1

# === Проверка прав ===
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}❌ Запусти скрипт от имени root (sudo su)${NC}"
  exit 1
fi

echo -e "${YELLOW}🛑 Удаляем старые файлы если остались...${NC}"

systemctl stop netrum-mining &>/dev/null
systemctl disable netrum-mining &>/dev/null
systemctl daemon-reload
rm -rf /etc/systemd/system/netrum-mining.service

systemctl stop netrum-node &>/dev/null
systemctl disable netrum-node &>/dev/null
systemctl daemon-reload
rm -rf /root/netrum-lite-node
rm -rf /etc/systemd/system/netrum-node.service

# === Обновление системы ===
echo -e "${YELLOW}📦 Обновление системы...${NC}"
apt update -y && apt upgrade -y

# === Установка зависимостей ===
# echo -e "${YELLOW}🔧 Установка необходимых пакетов...${NC}"
# apt install -y curl bc jq speedtest-cli ufw git

# === Установка Node.js v20 ===
echo -e "${YELLOW}🧩 Установка Node.js (Скрыта)...${NC}"
bash <(curl -s https://raw.githubusercontent.com/NodEligible/programs/refs/heads/main/nodejs.sh) &>/dev/null

echo -e "${YELLOW}🔧 Установка Нового Ookla...${NC}"
# Додай офіційне сховище Ookla
curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh | bash
# Встанови офіційний Speedtest CLI
apt install -y speedtest

# echo -e "${YELLOW}🔍 Проверяем Скорость интернета${NC}"
# speedtest --accept-license --accept-gdpr

# === Клонирование репозитория ===
cd /root
if [ -d "/root/netrum-lite-node" ]; then
  echo -e "${YELLOW}⚙️  Каталог уже существует, обновляем...${NC}"
  cd netrum-lite-node && git pull
else
  echo -e "${YELLOW}📥 Клонируем репозиторий...${NC}"
  git clone https://github.com/NetrumLabs/netrum-lite-node.git
  cd netrum-lite-node
fi

# === Установка npm-зависимостей ===
echo -e "${YELLOW}📦 Устанавливаем npm пакеты...${NC}"
npm install
npm link

echo -e "${YELLOW}────────────────────────────────────────────────────────────${NC}"
echo -e "${GREEN}📦  Этап восстановления Netrum Lite Node из резервной копии${NC}"
echo -e "${YELLOW}────────────────────────────────────────────────────────────${NC}"
echo
echo -e "${YELLOW}1️⃣  Загрузите файлы вашего бэкапа в каталог:${NC}"
echo -e "    ${CYAN}/root/netrum-lite-node/${NC}"
echo
echo -e "${YELLOW}2️⃣  Удалите папку data если она создалась при установке:${NC}"
echo -e "    ${RED}data${NC}"
echo
echo -e "${YELLOW}3️⃣  Скопируйте свою папку${NC} data ${YELLOW}и файлы из бэкапа обратно в папку${NC} src:"
echo -e "    ${GREEN}/root/netrum-lite-node/data${NC}"
echo
echo -e "    ${GREEN}/root/netrum-lite-node/src/wallet/key.txt${NC}"
echo -e "    ${GREEN}/root/netrum-lite-node/src/identity/node-id/basename.txt${NC}"
echo -e "    ${GREEN}/root/netrum-lite-node/src/identity/node-id/id.txt${NC}"
echo
echo -e "${YELLOW}⚠️  ВАЖНО:${NC}"
echo -e "   - Структура каталогов должна оставаться такой же, как в бэкапе."
echo -e "   - Не изменяйте имена папок и файлов внутри data и src."
echo -e "   - После копирования проверьте права доступа:"

read -p "➡️  Нажмите Enter, чтобы продолжить..."

# === Проверка интернет скорости перед синком ===
echo -e "${YELLOW}🌐 Проверяем скорость интернета перед запуском синхронизации...${NC}"
node /root/netrum-lite-node/src/system/system/speedtest.js

sleep 3

# === Создание systemd сервиса для выполнения задач ===
echo -e "${YELLOW}⚙️ Создаем systemd сервис для task...${NC}"
netrum-task

sleep 3

# === Разрешаем ноде обрабатывать задачи ===
echo -e "${YELLOW}🧠 Даём ноде разрешение на выполнение задач...${NC}"
netrum-task-allow

sleep 3

# пускаєм синхронізацію
netrum-sync
sleep 3

cd

# === Создание systemd сервиса ===
SERVICE_FILE="/etc/systemd/system/netrum-mining.service"
echo -e "${YELLOW}🛠 Создаём systemd сервис для майнинга...${NC}"
cat <<EOF > $SERVICE_FILE
[Unit]
Description=Netrum Lite Node - Mining Service
After=network.target

[Service]
User=root
WorkingDirectory=/root/netrum-lite-node
ExecStart=/usr/bin/node /root/netrum-lite-node/src/system/mining/live-log.js
Restart=always
RestartSec=10
StandardOutput=append:/var/log/netrum_mining.log
StandardError=append:/var/log/netrum_mining.log
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

# === Активация сервиса ===
systemctl daemon-reload
systemctl enable netrum-mining
systemctl start netrum-mining

echo -e "${GREEN}✅ Установка и запуск Netrum Lite Node завершены!${NC}"
echo -e "${YELLOW}──────────────────────────────────────────────${NC}"
echo -e "${GREEN}📄 Логи синка:${NC} journalctl -fu netrum-node.service"
echo -e "${GREEN}📄 Логи майнера:${NC} tail -n 10 /var/log/netrum_mining.log"
echo -e "${YELLOW}──────────────────────────────────────────────${NC}"
