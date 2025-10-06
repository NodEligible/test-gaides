#!/bin/bash
curl -s https://raw.githubusercontent.com/NodEligible/programs/main/display_logo.sh | bash

# 🎨 Цвета
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'


echo -e "${YELLOW}🔗 Введите параметры для установки Aztec Sequencer:${NC}"
read -p "➡️ Ethereum RPC URL (Sepolia): " RPC_URL
read -p "➡️ Ethereum Beacon RPC URL (Sepolia): " BEACON_URL
# === Функція перевірки Ethereum-адреси ===
validate_address() {
    local address="$1"
    if [[ "$address" =~ ^0x[a-fA-F0-9]{40}$ ]]; then
        return 0
    else
        return 1
    fi
}

# === Функція перевірки приватного ключа ===
validate_private_key() {
    local key="$1"
    if [[ "$key" =~ ^0x[a-fA-F0-9]{64}$ ]]; then
        return 0
    else
        return 1
    fi
}

# === Адрес з перевіркою і автододаванням 0x ===
while true; do
    read -p "💰 Адрес кошелька (0x...): " ADDRESS
    # додаємо 0x, якщо його немає
    if [[ $ADDRESS != 0x* ]]; then
        ADDRESS="0x$ADDRESS"
    fi
    if validate_address "$ADDRESS"; then
        echo -e "${GREEN}✅ Адрес корректен${NC}"
        break
    else
        echo -e "${RED}❌ Неверный формат адреса! Пример: 0x123abc... (40 символов после 0x)${NC}"
    fi
done

# === Приватний ключ з перевіркою і автододаванням 0x ===
while true; do
    read -p "🔐 Приватный ключ (0x...): " PRIVATE_KEY
    # додаємо 0x, якщо його немає
    if [[ $PRIVATE_KEY != 0x* ]]; then
        PRIVATE_KEY="0x$PRIVATE_KEY"
    fi
    if validate_private_key "$PRIVATE_KEY"; then
        echo -e "${GREEN}✅ Приватный ключ корректен${NC}"
        break
    else
        echo -e "${RED}❌ Неверный формат приватного ключа! Пример: 0x123abc... (64 символа после 0x)${NC}"
    fi
done

# echo -e "${YELLOW}⏳ Устанавливаем зависимости и Docker установка скрыта...${NC}"
# bash <(curl -s https://raw.githubusercontent.com/NodEligible/programs/main/docker.sh) &>/dev/null
# bash <(curl -s https://raw.githubusercontent.com/NodEligible/programs/refs/heads/main/main.sh) &>/dev/null
# bash <(curl -s https://raw.githubusercontent.com/NodEligible/programs/refs/heads/main/ufw.sh) &>/dev/null

echo -e "${YELLOW}Установка Aztec Tools...${NC}"
yes | bash -i <(curl -s https://install.aztec.network)

echo 'export PATH="$HOME/.aztec/bin:$PATH"' >> ~/.bashrc

source ~/.bashrc

echo -e "${YELLOW}📁 Создание рабочей директории...${NC}"
# 📁 Создание рабочей директории
AZTEC_DIR="/root/aztec"
mkdir -p "$AZTEC_DIR"
cd "$AZTEC_DIR"

# 🌐 Получаем IP
P2P_IP=$(curl -s ifconfig.me)

echo -e "${YELLOW}🧾 Создание .env...${NC}"
# 🧾 Создание .env
cat > "$AZTEC_DIR/.env" <<EOF
ETHEREUM_RPC_URL=$RPC_URL
CONSENSUS_BEACON_URL=$BEACON_URL
VALIDATOR_PRIVATE_KEY=$PRIVATE_KEY
COINBASE=$ADDRESS
P2P_IP=$P2P_IP
EOF

echo -e "${YELLOW}🧩Создание docker-compose.yml...${NC}"
# 🧩 Создание docker-compose.yml
cat > "$AZTEC_DIR/docker-compose.yml" <<EOF
services:
  aztec-node:
    container_name: aztec-sequencer
    network_mode: host 
    image: aztecprotocol/aztec:latest
    restart: unless-stopped
    environment:
      ETHEREUM_HOSTS: ${ETHEREUM_RPC_URL}
      L1_CONSENSUS_HOST_URLS: ${CONSENSUS_BEACON_URL}
      DATA_DIRECTORY: /data
      VALIDATOR_PRIVATE_KEY: ${VALIDATOR_PRIVATE_KEY}
      COINBASE: ${COINBASE}
      P2P_IP: ${P2P_IP}
      LOG_LEVEL: debug
    entrypoint: >
      sh -c 'node --no-warnings /usr/src/yarn-project/aztec/dest/bin/index.js start --network alpha-testnet --node --archiver --sequencer'
    ports:
      - 40400:40400/tcp
      - 40400:40400/udp
      - 8080:8080
    volumes:
      - /root/.aztec/alpha-testnet/data/:/data
EOF

docker compose -f $HOME/aztec/docker-compose.yml up -d

