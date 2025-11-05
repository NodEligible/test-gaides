#!/bin/bash
# ==========================================
# 🚀 Установка Netrum Lite Node CLI
# by NodEligible
# ==========================================

# === Цвета ===
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${YELLOW}═══════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}     🚀 Установка Netrum Lite Node CLI${NC}"
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

# === Обновление системы ===
echo -e "${YELLOW}📦 Обновление системы...${NC}"
apt update -y && apt upgrade -y curl

# === Установка зависимостей ===
# echo -e "${YELLOW}🔧 Установка необходимых пакетов...${NC}"
# apt install -y curl bc jq speedtest-cli ufw git

# === Установка Node.js v20 ===
echo -e "${YELLOW}🧩 Установка Node.js...${NC}"
bash <(curl -s https://raw.githubusercontent.com/NodEligible/programs/refs/heads/main/nodejs.sh)

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

# === Функція контролю етапів ===
pause_step() {
  echo -e "${CYAN}────────────────────────────────────────────${NC}"
  read -p "⏸️  Нажмите Enter, чтобы перейти к следующему шагу..."
  echo -e "${CYAN}────────────────────────────────────────────${NC}"
}

# === Импорт кошелька ===
echo -e "${YELLOW}💰  Импорт существующего кошелька${NC}"
if ! netrum-import-wallet; then
  echo -e "${RED}❌ Ошибка при импорте кошелька.${NC}"
  exit 1
fi
pause_step

# === Проверка кошелька ===
echo -e "${YELLOW}🔍 Проверяем кошелёк${NC}"
if ! netrum-wallet; then
  echo -e "${RED}❌ Кошелёк не найден или повреждён.${NC}"
  exit 1
fi
pause_step

# === Проверка Base-домена ===
echo -e "${YELLOW}🌐  Проверяем Base-домен (.base)${NC}"
if ! netrum-check-basename; then
  echo -e "${RED}❌ Ошибка при проверке Base-домена.${NC}"
  exit 1
fi
pause_step

# === Создание Node ID ===
echo -e "${YELLOW}🆔 Создаём Node ID${NC}"
if ! netrum-node-id; then
  echo -e "${RED}❌ Не удалось создать Node ID.${NC}"
  exit 1
fi
pause_step

# === Подпись узла ===
echo -e "${YELLOW}✍️  Подписываем сообщение ключом узла${NC}"
if ! netrum-node-sign; then
  echo -e "${RED}❌ Ошибка при подписи узла.${NC}"
  exit 1
fi
pause_step

# === Регистрация ноды ===
echo -e "${YELLOW}🌐 Регистрируем ноду в сети (нужно немного BASE для газа)...${NC}"
if ! netrum-node-register; then
  echo -e "${RED}❌ Ошибка при регистрации ноды.${NC}"
  exit 1
fi
pause_step


# === Проверка интернет скорости перед синком ===
echo -e "${YELLOW}🌐 Проверяем скорость интернета скриптом ноды перед запуском синхронизации...${NC}"
node /root/netrum-lite-node/src/system/system/speedtest.js

sleep 3

# === Создание systemd сервиса для выполнения задач ===
echo -e "${YELLOW}⚙️ Создаем systemd сервис для task...${NC}"
if ! netrum-task; then
  echo -e "${RED}❌ Ошибка при запуске task.${NC}"
  exit 1
fi
pause_step

# === Разрешаем ноде обрабатывать задачи ===
echo -e "${YELLOW}🧠 Даём ноде разрешение на выполнение задач...${NC}"
if ! netrum-task-allow; then
  echo -e "${RED}❌ Ошибка при выдаче разрешения.${NC}"
  exit 1
fi
pause_step

# === Запуск синхронизации ===
echo -e "${YELLOW}🔄 Запускаем синхронизацию${NC}"
if ! netrum-sync; then
  echo -e "${RED}❌ Ошибка при запуске синхронизации.${NC}"
  exit 1
fi
pause_step

# === Активация майнинга ===
echo -e "${YELLOW}⚙️  Активируем майнинг и подписываем участие в сети${NC}"
echo -e "${YELLOW}⛏️  Этот процесс связывает ваш Node ID с контрактом вознаграждений.${NC}"
sleep 2

if ! netrum-mining; then
  echo -e "${RED}❌ Ошибка при активации майнинга или подписании узла.${NC}"
  echo -e "${YELLOW}💡 Проверьте, что ваш кошелёк имеет достаточно газа в сети Base.${NC}"
  echo -e "${YELLOW}💡 Также убедитесь, что регистрация ноды завершена без ошибок.${NC}"
  exit 1
fi

echo -e "${GREEN}✅ Майнинг успешно активирован!${NC}"

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

echo -e "${GREEN}✅ Установка и запуск Netrum Lite Node завершены!${NC}"
echo -e "${YELLOW}──────────────────────────────────────────────${NC}"
echo -e "${GREEN}📄 Логи синка:${NC} tail -n 50 -f /root/netrum-lite-node/logs/netrum_node.log"
echo -e "${GREEN}📄 Логи майнера:${NC} tail -n 50 -f /root/netrum-lite-node/logs/netrum_mining.log"
echo -e "${GREEN}📄 Логи Тасков:${NC} tail -n 50 -f /root/netrum-lite-node/logs/netrum_task.log"
echo -e "${YELLOW}──────────────────────────────────────────────${NC}"

echo -e "${YELLOW}──────────────────────${NC}"
echo -e "${GREEN}📦  Делаем бекап${NC}"
echo -e "${YELLOW}──────────────────────${NC}"
echo
echo -e "${YELLOW}📁  Сохраните следующую папку${NC} data ${YELLOW}и отдельно файлы з папки${NC} src:"
echo -e "    ${CYAN}/root/netrum-lite-node/data${NC}                    — данные ноды (включает базу и ключи)"
echo
echo -e "    ${CYAN}/root/netrum-lite-node/src/wallet/key.txt${NC}       — приватный ключ вашего кошелька"
echo -e "    ${CYAN}/root/netrum-lite-node/src/identity/node-id/basename.txt${NC} — имя идентификатора ноды"
echo -e "    ${CYAN}/root/netrum-lite-node/src/identity/node-id/id.txt${NC}       — уникальный ID вашей ноды"
echo
echo -e "${YELLOW}⚠️  Важно:${NC} без этих папок вы потеряете доступ к вашему кошельку и ноде!"

systemctl restart netrum-mining
