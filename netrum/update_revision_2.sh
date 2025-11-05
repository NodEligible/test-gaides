#!/bin/bash

curl -s https://raw.githubusercontent.com/NodEligible/programs/refs/heads/main/display_logo.sh | bash

# === Цвета ===
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}═══════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}     🔄 Обновление Netrum Lite Node CLI${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════════════════${NC}"
sleep 1

BACKUP_DIR="/root/netrum_backup"
NODE_DIR="/root/netrum-lite-node"

echo -e "${YELLOW}📦 Проверка наличия папки бэкапа...${NC}"

if [ -d "$BACKUP_DIR" ]; then
  echo -e "${GREEN}✅ Папка ${BACKUP_DIR} уже существует — повторное создание не требуется.${NC}"
  echo -e "${YELLOW}ℹ️  Используется существующий бэкап. Пропускаю этап создания.${NC}"
else
  echo -e "${YELLOW}🗂️  Папка бэкапа не найдена. Создаю новую...${NC}"
  mkdir -p "$BACKUP_DIR"

  echo -e "${YELLOW}📁  Копирую важные файлы...${NC}"
  cp -r "$NODE_DIR/data" "$BACKUP_DIR/" 2>/dev/null
  cp "$NODE_DIR/src/wallet/key.txt" "$BACKUP_DIR/" 2>/dev/null
  cp "$NODE_DIR/src/identity/node-id/basename.txt" "$BACKUP_DIR/" 2>/dev/null
  cp "$NODE_DIR/src/identity/node-id/id.txt" "$BACKUP_DIR/" 2>/dev/null

  echo -e "${GREEN}✅  Бэкап успешно создан в ${BACKUP_DIR}${NC}"
fi


sleep 3

echo -e "${YELLOW}🛑 Удаляем старые файлы если остались...${NC}"

systemctl stop netrum-mining &>/dev/null
systemctl disable netrum-mining &>/dev/null
systemctl daemon-reload
rm -rf /etc/systemd/system/netrum-mining.service

systemctl stop netrum-task &>/dev/null
systemctl disable netrum-task &>/dev/null
systemctl daemon-reload
rm -f /etc/systemd/system/netrum-task.service

systemctl stop netrum-node &>/dev/null
systemctl disable netrum-node &>/dev/null
systemctl daemon-reload
rm -rf /root/netrum-lite-node
rm -rf /etc/systemd/system/netrum-node.service

echo -e "${YELLOW}🛑 Удаляем старый Ookla Speedtest CLI...${NC}"
# 1️⃣ Зупини всі процеси, які могли б використовувати speedtest
pkill -f speedtest &>/dev/null

# 2️⃣ Повністю видаляємо обидві версії
apt purge -y speedtest speedtest-cli

# 3️⃣ Очищаємо кеш apt і залишки файлів
apt autoremove -y
apt clean
rm -f /usr/bin/speedtest
rm -f /etc/apt/sources.list.d/ookla_speedtest-cli.list
rm -f /etc/apt/keyrings/ookla_speedtest-cli-archive-keyring.gpg
rm -rf /var/cache/apt/archives/speedtest*

echo -e "${YELLOW}🔧 Установка Нового Ookla...${NC}"
# Додай офіційне сховище Ookla
curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh | bash
# Встанови офіційний Speedtest CLI
DEBIAN_FRONTEND=noninteractive apt install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" speedtest

echo -e "${YELLOW}🔍 Проверяем Скорость интернета${NC}"
speedtest --accept-license --accept-gdpr

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

# === Створюємо папку для логів і надаємо права ===
mkdir -p /root/netrum-lite-node/logs
chmod 755 /root/netrum-lite-node/logs

# ======================================================================================================
# === Обновляем пути логов в шаблонах service.txt перед созданием systemd сервисов ===

LOG_DIR="/root/netrum-lite-node/logs"

TASK_SERVICE_FILE="/root/netrum-lite-node/src/task/service.txt"
NODE_SERVICE_FILE="/root/netrum-lite-node/src/system/sync/service.txt"

# === netrum-task.service.txt ===
if [ -f "$TASK_SERVICE_FILE" ]; then
  sed -i '/^StandardOutput=/d' "$TASK_SERVICE_FILE"
  sed -i '/^StandardError=/d' "$TASK_SERVICE_FILE"
  sed -i "/^RestartSec=/a StandardOutput=append:${LOG_DIR}/netrum_task.log\nStandardError=append:${LOG_DIR}/netrum_task_error.log" "$TASK_SERVICE_FILE"
  echo -e "${GREEN}✅ Файл service.txt для task успешно обновлён с новыми путями логов.${NC}"
else
  echo -e "${RED}⚠️ Файл шаблона не найден: $TASK_SERVICE_FILE${NC}"
fi

# === netrum-node.service.txt ===
if [ -f "$NODE_SERVICE_FILE" ]; then
  sed -i '/^StandardOutput=/d' "$NODE_SERVICE_FILE"
  sed -i '/^StandardError=/d' "$NODE_SERVICE_FILE"
  sed -i "/^RestartSec=/a StandardOutput=append:${LOG_DIR}/netrum_node.log\nStandardError=append:${LOG_DIR}/netrum_node_error.log" "$NODE_SERVICE_FILE"
  echo -e "${GREEN}✅ Файл service.txt для node успешно обновлён с новыми путями логов.${NC}"
else
  echo -e "${RED}⚠️ Файл шаблона не найден: $NODE_SERVICE_FILE${NC}"
fi

# ======================================================================================================

# === Установка npm-зависимостей ===
echo -e "${YELLOW}📦 Устанавливаем npm пакеты...${NC}"
npm install
npm link

# Даємо права на виконання
chmod +x /usr/bin/netrum*

sleep 3

echo -e "${YELLOW}📂 Проверяю наличие бэкапа...${NC}"

if [ ! -d "$BACKUP_DIR" ]; then
  echo -e "${RED}❌ Папка ${BACKUP_DIR} не найдена!${NC}"
  exit 1
fi

echo -e "${YELLOW}♻️ Восстанавливаю файлы на свои места...${NC}"
cp -r "$BACKUP_DIR/data" "$NODE_DIR/" 2>/dev/null
cp "$BACKUP_DIR/key.txt" "$NODE_DIR/src/wallet/" 2>/dev/null
cp "$BACKUP_DIR/basename.txt" "$NODE_DIR/src/identity/node-id/" 2>/dev/null
cp "$BACKUP_DIR/id.txt" "$NODE_DIR/src/identity/node-id/" 2>/dev/null

echo -e "${GREEN}✅ Восстановление завершено!${NC}"

sleep 3

# === Проверка кошелька ===
echo -e "${YELLOW}🔍 Проверяем кошелёк${NC}"
if ! netrum-wallet; then
  echo -e "${RED}❌ Кошелёк не найден или повреждён.${NC}"
  exit 1
fi

sleep 3

# === Проверка интернет скорости перед синком ===
echo -e "${YELLOW}🌐 Проверяем скорость интернета скриптом ноды перед запуском синхронизации...${NC}"
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
StandardOutput=append:/root/netrum-lite-node/logs/netrum_mining.log
StandardError=append:/root/netrum-lite-node/logs/netrum_mining_error.log
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

# === Активация сервиса ===
systemctl daemon-reload
systemctl enable netrum-mining
systemctl start netrum-mining

echo -e "${GREEN}✅ Обновление Netrum Lite Node завершено!${NC}"
echo -e "${YELLOW}──────────────────────────────────────────────${NC}"
echo -e "${GREEN}📄 Логи синка:${NC} journalctl -fu netrum-node.service"
echo -e "${GREEN}📄 Логи майнера:${NC} tail -n 10 /var/log/netrum_mining.log"
echo -e "${GREEN}📄 Логи Тасков:${NC} journalctl -u netrum-task -n 50 -f"
echo -e "${YELLOW}──────────────────────────────────────────────${NC}"
