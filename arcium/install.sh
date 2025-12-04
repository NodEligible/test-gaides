#!/bin/bash

YELLOW='\e[0;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[38;5;81m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${YELLOW}🔓 Открываю порт 8088/tcp...${NC}"

# --- UFW ---
if command -v ufw >/dev/null 2>&1; then
  ufw allow 8088/tcp >/dev/null 2>&1
fi

# --- iptables ---
if command -v iptables >/dev/null 2>&1; then
  iptables -A INPUT -p tcp --dport 8088 -j ACCEPT 2>/dev/null
fi

echo -e "${GREEN}✔ Порт 8088 открыт${NC}"

echo -e "${YELLOW}⚙️ Обновление системы...${NC}"
sudo apt update && sudo apt upgrade -y

sleep 3

echo -e "${YELLOW}📦 Установка необходимых пакетов...${NC}"
sudo apt install -y \
  curl wget git tmux htop unzip build-essential pkg-config \
  libssl-dev clang make jq

sleep 3

echo -e "${YELLOW}🐳 Установка Docker...${NC}"
bash <(curl -s https://raw.githubusercontent.com/NodEligible/programs/refs/heads/main/docker.sh)

sleep 3

echo -e "${YELLOW}🦀 Установка Rust...${NC}"
curl https://sh.rustup.rs -sSf | sh -s -- -y
source $HOME/.cargo/env

sleep 3

echo -e "${YELLOW}🌞 Установка Solana CLI...${NC}"
yes | sh -c "$(curl --proto '=https' --tlsv1.2 -sSfL https://solana-install.solana.workers.dev)"
export PATH="/root/.local/share/solana/install/active_release/bin:$PATH"

sleep 3

echo -e "${GREEN}✅ Проверка версий...${NC}"
solana --version
rustc --version
cargo --version
docker --version

echo -e "${GREEN}🎉 Подготовка завершена! Можно перейти к установке Arcium.${NC}"

echo -e "${YELLOW}🧩 Установка Arcium Tooling...${NC}"

curl --proto '=https' --tlsv1.2 -sSfL https://install.arcium.com/ | bash

# Добавляем Arcium и Cargo в PATH
export PATH="$HOME/.arcium/bin:$HOME/.cargo/bin:$PATH"
echo 'export PATH="$HOME/.arcium/bin:$PATH"' >> ~/.bashrc
echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> ~/.bashrc

sleep 2

echo -e "${GREEN}✅ Arcium CLI установлен.${NC}"
arcium --version || echo -e "${RED}⚠ Arcium не найден после установки.${NC}"
arcup --version || true


# ---------- Для бекапа ----------
SOURCE_DIR="$HOME/arcium-node-setup"
BACKUP_DIR="$HOME/arcium-backup"

# ---------- Общие переменные ----------
WORKDIR="$HOME/arcium-node-setup"
ENV_FILE="$WORKDIR/.env"
CFG_FILE="$WORKDIR/node-config.toml"
LOGS_DIR="$WORKDIR/arx-node-logs"
NODE_KP="$WORKDIR/node-keypair.json"
CALLBACK_KP="$WORKDIR/callback-kp.json"
IDENTITY_PEM="$WORKDIR/identity.pem"
NODE_PUB_FILE="$WORKDIR/node-pubkey.txt"
CALLBACK_PUB_FILE="$WORKDIR/callback-pubkey.txt"

DEFAULT_RPC="https://api.devnet.solana.com"
DEFAULT_WSS="wss://api.devnet.solana.com"

# ---------- Хелперы ----------
require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo -e "${RED}❌ Не найдена команда: $1. Установи её перед запуском этого скрипта.${NC}"
    exit 1
  fi
}

pause() {
  read -r -p "$(echo -e "${YELLOW}⏯ Нажми Enter для продолжения...${NC}")" _
}

print_header() {
  echo -e "${BLUE}"
  echo "======================================="
  echo "      Arcium Testnet Node Setup"
  echo "======================================="
  echo -e "${NC}"
}

# ---------- Проверка инструментов ----------
print_header

echo -e "${YELLOW}🔍 Проверка необходимых инструментов...${NC}"
for cmd in solana docker arcium curl openssl; do
  require_cmd "$cmd"
done
echo -e "${GREEN}✅ Все необходимые инструменты найдены.${NC}"

sleep 3

# ---------- Шаг 2: рабочая директория ----------
echo -e "${YELLOW}📁 Создаю рабочую директорию ноды...${NC}"
mkdir -p "$WORKDIR"
cd "$WORKDIR" || { echo -e "${RED}❌ Не удалось перейти в $WORKDIR${NC}"; exit 1; }
echo -e "${GREEN}✅ Рабочая папка: ${CYAN}$WORKDIR${NC}"

# ---------- даем права ----------
chmod 700 /root/arcium-node-setup

# ---------- Загрузка/выбор RPC ----------
echo -e "${YELLOW}🌐 Настройка RPC для Solana Devnet...${NC}"
RPC_URL="$DEFAULT_RPC"
WSS_URL="$DEFAULT_WSS"

echo -e "${YELLOW}По умолчанию будет использован публичный RPC:${NC}"
echo -e "  ${CYAN}$DEFAULT_RPC${NC}"
echo -e "${YELLOW}Ты хочешь указать свой кастомный RPC (Helius / QuickNode)?${NC}"
read -r -p "$(echo -e "${YELLOW}[1] Оставить по умолчанию  |  [2] Ввести свой RPC: ${NC}")" rpc_choice

if [ "$rpc_choice" = "2" ]; then
  read -r -p "$(echo -e "${YELLOW}➡ Введи HTTP RPC URL (например, https://...): ${NC}")" custom_rpc
  read -r -p "$(echo -e "${YELLOW}➡ Введи WebSocket WSS URL (например, wss://...): ${NC}")" custom_wss
  if [ -n "$custom_rpc" ] && [ -n "$custom_wss" ]; then
    RPC_URL="$custom_rpc"
    WSS_URL="$custom_wss"
  else
    echo -e "${RED}⚠ Пустой ввод. Оставляю дефолтные RPC/WSS.${NC}"
  fi
fi

echo -e "${GREEN}✅ RPC:  ${CYAN}$RPC_URL${NC}"
echo -e "${GREEN}✅ WSS:  ${CYAN}$WSS_URL${NC}"

# ---------- Шаг 3: генерация ключей ----------
echo -e "${YELLOW}🔐 Генерация ключей ноды...${NC}"

# Удаляем старые ключи, если они существуют
rm -f "$NODE_KP" "$CALLBACK_KP" "$IDENTITY_PEM" "$NODE_PUB_FILE" "$CALLBACK_PUB_FILE"

# Генерируем новые пары ключей
echo -e "${YELLOW}➡ Генерирую node-keypair.json...${NC}"
solana-keygen new --outfile "$NODE_KP" --no-bip39-passphrase >> /dev/null

echo -e "${YELLOW}➡ Генерирую callback-kp.json...${NC}"
solana-keygen new --outfile "$CALLBACK_KP" --no-bip39-passphrase >> /dev/null

echo -e "${YELLOW}➡ Генерирую identity.pem (Ed25519)...${NC}"
openssl genpkey -algorithm Ed25519 -out "$IDENTITY_PEM" >/dev/null 2>&1

# Получаем публичные ключи
NODE_PUBKEY=$(solana address --keypair "$NODE_KP")
CALLBACK_PUBKEY=$(solana address --keypair "$CALLBACK_KP")

echo -e "${GREEN}✅ Ключи успешно созданы.${NC}"
echo -e "${GREEN}🔑 NODE_PUBKEY:     ${CYAN}$NODE_PUBKEY${NC}"
echo -e "${GREEN}🔑 CALLBACK_PUBKEY: ${CYAN}$CALLBACK_PUBKEY${NC}"

sleep 3

# ---------- Шаг 4: Node Offset ----------
echo -e "${YELLOW}🔢 Генерация уникального Node Offset...${NC}"

NODE_OFFSET=""
attempt=0
max_attempts=10

while [ $attempt -lt $max_attempts ]; do
  attempt=$((attempt + 1))
  CANDIDATE=$(shuf -i 10000000-99999999 -n 1)

  echo -e "${YELLOW}➡ Проверка OFFSET=${CYAN}$CANDIDATE${YELLOW} (попытка $attempt/${max_attempts})...${NC}"

  OUTPUT=$(arcium arx-info "$CANDIDATE" --rpc-url "$RPC_URL" 2>&1)
  EXIT_CODE=$?

  if echo "$OUTPUT" | grep -q "Error: Account info not found"; then
    NODE_OFFSET="$CANDIDATE"
    echo -e "${GREEN}✅ Найден свободный NODE_OFFSET=${CYAN}$NODE_OFFSET${NC}"
    break
  fi

  if echo "$OUTPUT" | grep -q "Node authority"; then
    echo -e "${RED}❌ Offset занят.${NC}"
    continue
  fi

  echo -e "${YELLOW}⚠ Неизвестный ответ:${NC}"
  echo "$OUTPUT"
done

if [ -z "$NODE_OFFSET" ]; then
  echo -e "${RED}❌ Автоматически не нашли. Переход в ручной режим.${NC}"

  while true; do
    read -r -p "➡ Введите 8-значный OFFSET: " MANUAL_OFFSET

    if [[ ! "$MANUAL_OFFSET" =~ ^[0-9]{8}$ ]]; then
      echo -e "${RED}⚠ Неверный формат.${NC}"
      continue
    fi

    OUTPUT=$(arcium arx-info "$MANUAL_OFFSET" --rpc-url "$RPC_URL" 2>&1)

    if echo "$OUTPUT" | grep -q "Error: Account info not found"; then
      NODE_OFFSET="$MANUAL_OFFSET"
      echo -e "${GREEN}✔ OFFSET свободен: ${CYAN}$NODE_OFFSET${NC}"
      break
    fi

    if echo "$OUTPUT" | grep -q "Node authority"; then
      echo -e "${RED}❌ OFFSET занят.${NC}"
      continue
    fi

    echo -e "${RED}⚠ Неизвестный ответ:${NC}"
    echo "$OUTPUT"
  done
fi

echo -e "${GREEN}✨ Итоговый OFFSET: ${CYAN}$NODE_OFFSET${NC}"

# ---------- Сохранение .env ----------
echo -e "${YELLOW}🧾 Обновляю .env...${NC}"
touch "$ENV_FILE"

# Удалим старые строки, если есть
sed -i '/^NODE_OFFSET=/d' "$ENV_FILE" 2>/dev/null || true
sed -i '/^RPC_URL=/d' "$ENV_FILE" 2>/dev/null || true
sed -i '/^WSS_URL=/d' "$ENV_FILE" 2>/dev/null || true
sed -i '/^NODE_PUBKEY=/d' "$ENV_FILE" 2>/dev/null || true
sed -i '/^CALLBACK_PUBKEY=/d' "$ENV_FILE" 2>/dev/null || true

{
  echo "NODE_OFFSET=$NODE_OFFSET"
  echo "RPC_URL=$RPC_URL"
  echo "WSS_URL=$WSS_URL"
  echo "NODE_PUBKEY=$NODE_PUBKEY"
  echo "CALLBACK_PUBKEY=$CALLBACK_PUBKEY"
} >> "$ENV_FILE"

echo -e "${GREEN}✅ .env обновлён: ${CYAN}$ENV_FILE${NC}"

sleep 3

# -------------------------------------------------------------
# Ручное подтверждение
read -p "➡️  Нажмите Enter, чтобы продолжить..."
# -------------------------------------------------------------

# ---------- Шаг 5: Airdrop Devnet SOL ----------
echo -e "${YELLOW}💸 Airdrop Devnet SOL для аккаунтов ноды...${NC}"

airdrop_with_retry() {
  local pubkey="$1"
  local label="$2"

  for tries in {1..5}; do
    echo -e "${YELLOW}➡ Airdrop для ${label} (${CYAN}$pubkey${YELLOW}), попытка $tries...${NC}"

    OUT=$(solana airdrop 2 "$pubkey" -u devnet 2>&1)

    if echo "$OUT" | grep -q "Signature:"; then
      echo -e "${GREEN}⏳ Транзакция отправлена. Проверяю баланс...${NC}"

      for i in {1..5}; do
        BAL=$(solana balance "$pubkey" -u devnet 2>/dev/null | awk '{print $1}')
        if [[ "$BAL" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
          echo -e "${GREEN}✅ Баланс ${label}: ${CYAN}${BAL} SOL${NC}"
          return 0
        fi
        sleep 2
      done

      echo -e "${RED}⚠ Баланс не обновился, пробую снова...${NC}"
    else
      echo -e "${RED}⚠ Ошибка faucet, повтор...${NC}"
    fi
    sleep 2
  done

  echo -e "${RED}❌ Не удалось получить SOL для ${label}.${NC}"
  return 1
}

# -----------------------------------------
# 1. Airdrop только для Node Authority
# -----------------------------------------
airdrop_node "$NODE_PUBKEY" "Node Authority"

echo
echo -e "${CYAN}📘 Теперь необходимо вручную получить SOL на Callback Authority.${NC}"
echo -e "${CYAN}🔗 Перейдите на сайт: ${GREEN}https://solfaucet.com/${NC}"
echo
echo -e "${YELLOW}➡ Вставьте этот адрес:${NC}"
echo -e "${GREEN}$CALLBACK_PUBKEY${NC}"
echo
echo -e "${YELLOW}➡ В Amount укажите: ${GREEN}2 SOL${NC}"
echo -e "${YELLOW}➡ Выберите сеть: ${GREEN}DEVNET${NC}"
echo -e "${YELLOW}➡ Нажмите кнопку: ${GREEN}Request Airdrop${NC}"
echo
echo -e "${CYAN}⏳ Ожидаю 60 секунд, чтобы баланс обновился...${NC}"
sleep 60

# -----------------------------------------
# 2. Автоматическая проверка баланса Callback Authority
# -----------------------------------------
echo
echo -e "${YELLOW}🔍 Проверяю баланс Callback Authority...${NC}"

CB_BAL=$(solana balance "$CALLBACK_PUBKEY" -u devnet 2>/dev/null | awk '{print $1}')

if [[ "$CB_BAL" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
  echo -e "${GREEN}💰 Баланс Callback Authority: ${CYAN}${CB_BAL} SOL${NC}"
else
  echo -e "${RED}⚠ Не удалось получить баланс. Возможно SOL ещё не пришли.${NC}"
fi

airdrop_with_retry "$NODE_PUBKEY" "Node Authority"
airdrop_with_retry "$CALLBACK_PUBKEY" "Callback Authority"

# -----------------------------------------
# 3. Спросить пользователя — продолжать ли установку
# -----------------------------------------
echo
# read -rp "Продолжить установку? [Y/n]: " ans
# ans=${ans:-Y}

# if [[ "$ans" =~ ^[Yy]$ ]]; then
#   echo -e "${GREEN}✔ Продолжаем установку...${NC}"
# else
#   echo -e "${RED}✖ Установка остановлена пользователем.${NC}"
#   exit 1
# fi

sleep 3

# -------------------------------------------------------------
# Ручное подтверждение
read -p "➡️  Нажмите Enter, чтобы продолжить..."
# -------------------------------------------------------------

# ---------- Шаг 6: init-arx-accs ----------
echo -e "${YELLOW}🧩 On-chain инициализация аккаунтов ноды (init-arx-accs)...${NC}"

SERVER_IP=$(curl -s https://api.ipify.org)
if [ -z "$SERVER_IP" ]; then
  echo -e "${RED}❌ Не удалось определить публичный IP через api.ipify.org.${NC}"
  read -r -p "$(echo -e "${YELLOW}Введи IP вручную: ${NC}")" SERVER_IP
fi

echo -e "${GREEN}✅ Публичный IP ноды: ${CYAN}$SERVER_IP${NC}"

tries=0
max_tries=3
INIT_OK=0

while [ $tries -lt $max_tries ]; do
  tries=$((tries + 1))
  echo -e "${YELLOW}➡ Запуск init-arx-accs (попытка $tries)...${NC}"

  if arcium init-arx-accs \
      --keypair-path "$NODE_KP" \
      --callback-keypair-path "$CALLBACK_KP" \
      --peer-keypair-path "$IDENTITY_PEM" \
      --node-offset "$NODE_OFFSET" \
      --ip-address "$SERVER_IP" \
      --rpc-url "$RPC_URL"; then
    INIT_OK=1
    break
  else
    echo -e "${RED}⚠ init-arx-accs завершился с ошибкой.${NC}"
    echo -e "${YELLOW}Проверяю доступность RPC...${NC}"
    if ! curl -s --max-time 5 "$RPC_URL" >/dev/null 2>&1; then
      echo -e "${RED}❌ RPC ${RPC_URL} не отвечает.${NC}"
    fi
    sleep 5
  fi
done

if [ "$INIT_OK" -ne 1 ]; then
  echo -e "${RED}❌ Не удалось инициализировать on-chain аккаунты ноды после $max_tries попыток.${NC}"
  echo -e "${YELLOW}Проверь RPC, баланс аккаунтов и попробуй ещё раз вручную.${NC}"
  exit 1
fi

echo -e "${GREEN}✅ On-chain аккаунты ноды успешно инициализированы.${NC}"

sleep 2

# -------------------------------------------------------------
# Ручное подтверждение
read -p "➡️  Нажмите Enter, чтобы продолжить..."
# -------------------------------------------------------------

# ---------- Шаг 7: node-config.toml ----------
echo -e "${YELLOW}🧾 Генерация node-config.toml...${NC}"

cat > "$CFG_FILE" <<EOF
[node]
offset = $NODE_OFFSET
hardware_claim = 0
starting_epoch = 0
ending_epoch = 9223372036854775807

[network]
address = "0.0.0.0"

[solana]
endpoint_rpc = "$RPC_URL"
endpoint_wss = "$WSS_URL"
cluster = "Devnet"
commitment.commitment = "confirmed"
EOF

echo -e "${GREEN}✅ node-config.toml создан: ${CYAN}$CFG_FILE${NC}"

sleep 3

# -------------------------------------------------------------
# Ручное подтверждение
read -p "➡️  Нажмите Enter, чтобы продолжить..."
# -------------------------------------------------------------

# ---------- Шаг 8: Кластер ----------
echo -e "${YELLOW}🧬 Настройка кластера Arcium...${NC}"
echo -e "${YELLOW}Что делаем с кластером?${NC}"
echo -e "${CYAN}[1] Создать свой кластер"
echo -e "[2] Присоединиться к существующему"
echo -e "[3] Пропустить этот шаг (сделаешь позже)${NC}"

read -r -p "$(echo -e "${YELLOW}➡ Введи выбор [1/2/3]: ${NC}")" cluster_choice

CLUSTER_OFFSET=""

case "$cluster_choice" in
  1)
    echo -e "${YELLOW}🔧 Создание собственного кластера...${NC}"
    CLUSTER_OFFSET=$(shuf -i 10000000-99999999 -n 1)
    echo -e "${YELLOW}➡ Попробую CLUSTER_OFFSET=${CYAN}$CLUSTER_OFFSET${NC}"

    if arcium init-cluster \
        --keypair-path "$NODE_KP" \
        --offset "$CLUSTER_OFFSET" \
        --max-nodes 10 \
        --rpc-url "$RPC_URL"; then
      echo -e "${GREEN}✅ Кластер создан с offset=${CYAN}$CLUSTER_OFFSET${NC}"
      sed -i '/^CLUSTER_OFFSET=/d' "$ENV_FILE" 2>/dev/null || true
      echo "CLUSTER_OFFSET=$CLUSTER_OFFSET" >> "$ENV_FILE"
    else
      echo -e "${RED}⚠ Не удалось создать кластер. Можно будет попробовать позже вручную.${NC}"
    fi
    ;;
  2)
    echo -e "${YELLOW}🔗 Присоединение к существующему кластеру...${NC}"
    read -r -p "$(echo -e "${YELLOW}➡ Введи CLUSTER_OFFSET кластера: ${NC}")" CLUSTER_OFFSET
    if [ -n "$CLUSTER_OFFSET" ]; then
      if arcium join-cluster true \
          --keypair-path "$NODE_KP" \
          --node-offset "$NODE_OFFSET" \
          --cluster-offset "$CLUSTER_OFFSET" \
          --rpc-url "$RPC_URL"; then
        echo -e "${GREEN}✅ Нода успешно присоединена к кластеру ${CYAN}$CLUSTER_OFFSET${NC}"
        sed -i '/^CLUSTER_OFFSET=/d' "$ENV_FILE" 2>/dev/null || true
        echo "CLUSTER_OFFSET=$CLUSTER_OFFSET" >> "$ENV_FILE"
      else
        echo -e "${RED}⚠ Ошибка при присоединении к кластеру. Можно повторить позже вручную.${NC}"
      fi
    else
      echo -e "${RED}⚠ Пустой CLUSTER_OFFSET, шаг пропущен.${NC}"
    fi
    ;;
  3|*)
    echo -e "${YELLOW}⏭ Шаг с кластером пропущен. Ты сможешь создать или присоединиться позже вручную.${NC}"
    ;;
esac

sleep 3

# -------------------------------------------------------------
# Ручное подтверждение
read -p "➡️  Нажмите Enter, чтобы продолжить..."
# -------------------------------------------------------------

# ---------- Шаг 9: Docker Compose запуск ----------
echo -e "${YELLOW}🐳 Запуск ARX-ноды через Docker Compose...${NC}"

mkdir -p "$LOGS_DIR"
# touch "$LOGS_DIR/arx.log"

# Удаляем старый контейнер, если существует
if docker ps -a --format '{{.Names}}' | grep -q '^arx-node$'; then
  echo -e "${YELLOW}♻ Обнаружен существующий контейнер arx-node. Останавливаю и удаляю...${NC}"
  docker stop arx-node >/dev/null 2>&1 || true
  docker rm arx-node >/dev/null 2>&1 || true
fi

# Создаём docker-compose.yml рядом с файлами ноды
COMPOSE_FILE="$WORKDIR/docker-compose.yml"

echo -e "${YELLOW}📄 Создаю docker-compose.yml...${NC}"

cat > "$COMPOSE_FILE" <<EOF
version: "3.8"

services:
  arx-node:
    image: arcium/arx-node
    container_name: arx-node
    restart: always

    ports:
      - "8088:8080"

    environment:
      NODE_IDENTITY_FILE: /usr/arx-node/node-keys/node_identity.pem
      NODE_KEYPAIR_FILE: /usr/arx-node/node-keys/node_keypair.json
      OPERATOR_KEYPAIR_FILE: /usr/arx-node/node-keys/operator_keypair.json
      CALLBACK_AUTHORITY_KEYPAIR_FILE: /usr/arx-node/node-keys/callback_authority_keypair.json
      NODE_CONFIG_PATH: /usr/arx-node/arx/node_config.toml

    volumes:
      - ./node-config.toml:/usr/arx-node/arx/node_config.toml
      - ./node-keypair.json:/usr/arx-node/node-keys/node_keypair.json:ro
      - ./node-keypair.json:/usr/arx-node/node-keys/operator_keypair.json:ro
      - ./callback-kp.json:/usr/arx-node/node-keys/callback_authority_keypair.json:ro
      - ./identity.pem:/usr/arx-node/node-keys/node_identity.pem:ro
      - ./arx-node-logs:/usr/arx-node/logs
EOF

echo -e "${GREEN}✅ docker-compose.yml создан.${NC}"

echo -e "${YELLOW}🚀 Запускаю arx-node через Docker Compose...${NC}"

cd "$WORKDIR" && docker compose up -d

sleep 3

# Проверка запуска
if ! docker ps --format '{{.Names}}' | grep -q '^arx-node$'; then
  echo -e "${RED}❌ arx-node НЕ запущена! Проверь docker logs arx-node.${NC}"
  exit 1
fi

# ---------- Делаем бекап файлов ----------
echo -e "${YELLOW}🔍 Проверка директории ноды...${NC}"
if [ ! -d "$SOURCE_DIR" ]; then
  echo -e "${RED}❌ Ошибка: директория $SOURCE_DIR не найдена.${NC}"
  exit 1
fi

echo -e "${YELLOW}📦 Пересоздаю папку бекапа...${NC}"
rm -rf "$BACKUP_DIR"
mkdir -p "$BACKUP_DIR"

FILES=(
  "identity.pem"
  "node-keypair.json"
  "callback-kp.json"
  ".env"
  "node-config.toml"
)

echo -e "${YELLOW}📁 Копирую файлы...${NC}"
for FILE in "${FILES[@]}"; do
  if [ -f "$SOURCE_DIR/$FILE" ]; then
    cp "$SOURCE_DIR/$FILE" "$BACKUP_DIR/"
    echo -e "  ➕ $FILE"
  else
    echo -e "  ⚠️ Файл отсутствует: $FILE"
  fi
done

echo -e "${GREEN}✅ Бекап завершен!"
echo -e "${GREEN}📁 Файлы сохранены в: $BACKUP_DIR${NC}"

sleep 1

echo -e "${GREEN}🎉 Установка Arcium Testnet Node завершена.${NC}"

