#!/bin/bash
set -euo pipefail

YELLOW='\e[0;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[38;5;81m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}"
echo "======================================="
echo "  Arcium Testnet Node Backup Install"
echo "======================================="
echo -e "${NC}"

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

echo -e "${YELLOW}🔧 Подготавливаем систему...${NC}"
sudo apt update -y && sudo apt upgrade -y

echo -e "${YELLOW}📦 Устанавливаем базовые пакеты...${NC}"
sudo apt install -y curl git wget jq make gcc nano tmux htop \
    build-essential unzip pkg-config libssl-dev libleveldb-dev \
    libudev-dev protobuf-compiler autoconf automake ncdu lz4 clang

echo -e "${CYAN}🐳 Устанавливаем Docker...${NC}"
bash <(curl -s https://raw.githubusercontent.com/NodEligible/programs/refs/heads/main/docker.sh)

echo -e "${YELLOW}📌 Устанавливаем Node.js 22 и Yarn...${NC}"
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo bash -
sudo apt install -y nodejs

if ! node -v; then
    echo -e "${RED}❌ Node.js не установился!${NC}"
    exit 1
fi

npm install -g yarn
yarn -v || { echo -e "${RED}❌ Yarn не установился!"; exit 1; }

# Устанавливаем Yarn Classic
curl -o- -L https://yarnpkg.com/install.sh | bash
export PATH="$HOME/.yarn/bin:$HOME/.config/yarn/global/node_modules/.bin:$PATH"
echo 'export PATH="$HOME/.yarn/bin:$HOME/.config/yarn/global/node_modules/.bin:$PATH"' >> ~/.bashrc

echo -e "${GREEN}✔️ Node.js и Yarn успешно установлены.${NC}"

echo -e "${YELLOW}🦀 Устанавливаем Rust...${NC}"

curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs -o rust.sh
sh rust.sh -y --default-toolchain stable
rm rust.sh

source "$HOME/.cargo/env"
export PATH="$HOME/.cargo/bin:$PATH"
echo 'source $HOME/.cargo/env' >> ~/.bashrc
echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> ~/.bashrc

rustc --version || { echo -e "${RED}❌ Rust не установился!"; exit 1; }
echo -e "${GREEN}✔️ Rust установлен.${NC}"

echo -e "${YELLOW}📦 Устанавливаем Anchor CLI (Просто ждите)...${NC}"
git clone https://github.com/coral-xyz/anchor.git
cd anchor
git checkout v0.31.1

# скрываем весь вывод, но НЕ скрываем ошибки установки Cargo
if ! cargo install --path cli --force >/dev/null 2>&1; then
    echo -e "${RED}❌ Ошибка установки Anchor CLI.${NC}"
    exit 1
fi

cd ..
rm -rf anchor

anchor --version || { echo -e "${RED}❌ Anchor CLI не установился!"; exit 1; }
echo -e "${GREEN}✔️ Anchor готов к работе.${NC}"

echo -e "${CYAN}🔑 Устанавливаем Solana CLI...${NC}"

export DEBIAN_FRONTEND=noninteractive

curl --proto '=https' --tlsv1.2 -sSfL https://solana-install.solana.workers.dev -o solana.sh
bash solana.sh -y
rm solana.sh

export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"
echo 'export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"' >> ~/.bashrc

solana --version || { echo -e "${RED}❌ Solana CLI не установился!"; exit 1; }

echo -e "${GREEN}✔️ Solana CLI установлен.${NC}"


echo -e "${GREEN}=======================================${NC}"
echo "     Все дополнительные программы установлены!"
echo -e "${GREEN}=======================================${NC}"


sleep 3

echo -e "${CYAN}📁 Создаём рабочую директорию Arcium...${NC}"

mkdir -p $HOME/arcium-node-setup
cd $HOME/arcium-node-setup

# Даємо права
chmod 700 /root/arcium-node-setup

echo -e "${YELLOW}⚙️ Устанавливаем Arcium CLI...${NC}"
curl --proto '=https' --tlsv1.2 -sSfL https://arcium-install.arcium.workers.dev/ | bash

echo -e "${GREEN}🔍 Проверяем версии Arcium...${NC}"
arcium --version
arcup --version

echo -e "${GREEN}✨ Установка завершена! Продолжаем настройку.${NC}"

sleep 5

SOURCE_DIR="$HOME/arcium-backup"
TARGET_DIR="$HOME/arcium-node-setup"

FILES=(
  "identity.pem"
  "node-keypair.json"
  "callback-kp.json"
  "bls-keypair.json"
  ".env"
  "node-config.toml"
)

echo -e "${YELLOW}♻️ Восстановление Arcium ноды из бекапа...${NC}"

# ---------- Проверка ----------
if [ ! -d "$SOURCE_DIR" ]; then
  echo -e "${RED}❌ Папка бекапа не найдена: $SOURCE_DIR${NC}"
  exit 1
fi

mkdir -p "$TARGET_DIR"

echo -e "${YELLOW}📁 Копирую файлы в $TARGET_DIR ...${NC}"

for FILE in "${FILES[@]}"; do
  if [ -f "$SOURCE_DIR/$FILE" ]; then
    cp -f "$SOURCE_DIR/$FILE" "$TARGET_DIR/"
    echo -e "${GREEN}  ✔ $FILE восстановлен${NC}"
  else
    echo -e "${YELLOW}  ⚠️ Файл отсутствует в бекапе: $FILE${NC}"
  fi
done

echo -e "${GREEN}✅ Восстановление завершено.${NC}"

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
      - "8001:8001"
      - "8002:8002"

    environment:
      NODE_IDENTITY_FILE: /usr/arx-node/node-keys/node_identity.pem
      NODE_KEYPAIR_FILE: /usr/arx-node/node-keys/node_keypair.json
      CALLBACK_AUTHORITY_KEYPAIR_FILE: /usr/arx-node/node-keys/callback_authority_keypair.json
      BLS_PRIVATE_KEY_FILE: /usr/arx-node/node-keys/bls-keypair.json
      NODE_CONFIG_PATH: /usr/arx-node/arx/node_config.toml

    volumes:
      - ./node-config.toml:/usr/arx-node/arx/node_config.toml
      - ./node-keypair.json:/usr/arx-node/node-keys/node_keypair.json:ro
      - ./callback-kp.json:/usr/arx-node/node-keys/callback_authority_keypair.json:ro
      - ./identity.pem:/usr/arx-node/node-keys/node_identity.pem:ro
      - ./bls-keypair.json:/usr/arx-node/node-keys/bls-keypair.json:ro
      - ./arx-node-logs:/usr/arx-node/logs
EOF

echo -e "${GREEN}✅ docker-compose.yml создан.${NC}"

echo -e "${YELLOW}🚀 Запускаю arx-node через Docker Compose...${NC}"

cd "$WORKDIR" && docker compose up -d

sleep 10

# Проверка запуска
if ! docker ps --format '{{.Names}}' | grep -q '^arx-node$'; then
  echo -e "${RED}❌ arx-node НЕ запущена! Проверь docker logs arx-node.${NC}"
  exit 1
fi


sleep 1

echo -e "${GREEN}🎉 Востановление Arcium Testnet Node завершено.${NC}"
