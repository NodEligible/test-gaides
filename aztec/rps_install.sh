#!/bin/bash

YELLOW='\033[1;33m'
GREEN='\033[1;32m'
RED='\033[1;31m'
NC='\033[0m'

echo -e "${YELLOW}🚀 Установка локальних RPC для Aztec (Geth + Prysm)...${NC}"
sleep 1

# === Перевірка Docker ===
if ! command -v docker &> /dev/null; then
  echo -e "${YELLOW}📦 Встановлення Docker...${NC}"
  apt update -y && apt install -y docker.io docker-compose-plugin
  systemctl enable docker --now
fi

# === Створення директорій ===
echo -e "${YELLOW}📁 Створюємо структуру директорій...${NC}"
mkdir -p /root/ethereum/execution
mkdir -p /root/ethereum/consensus

# === Генеруємо JWT ===
if [ ! -f /root/ethereum/jwt.hex ]; then
  openssl rand -hex 32 > /root/ethereum/jwt.hex
  echo -e "${GREEN}✅ JWT secret створено: /root/ethereum/jwt.hex${NC}"
else
  echo -e "${YELLOW}ℹ️ JWT вже існує, пропускаємо.${NC}"
fi

# === Docker Compose файл ===
echo -e "${YELLOW}⚙️ Створюємо docker-compose.yml...${NC}"
cat > /root/ethereum/docker-compose.yml <<EOF
services:
  geth:
    image: ethereum/client-go:stable
    container_name: geth
    network_mode: host
    restart: unless-stopped
    ports:
      - 30303:30303
      - 30303:30303/udp
      - 8545:8545
      - 8546:8546
      - 8551:8551
    volumes:
      - /root/ethereum/execution:/data
      - /root/ethereum/jwt.hex:/data/jwt.hex
    command:
      - --sepolia
      - --http
      - --http.api=eth,net,web3
      - --http.addr=0.0.0.0
      - --authrpc.addr=0.0.0.0
      - --authrpc.vhosts=*
      - --authrpc.jwtsecret=/data/jwt.hex
      - --authrpc.port=8551
      - --syncmode=snap
      - --datadir=/data
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

  prysm:
    image: gcr.io/prysmaticlabs/prysm/beacon-chain
    container_name: prysm
    network_mode: host
    restart: unless-stopped
    volumes:
      - /root/ethereum/consensus:/data
      - /root/ethereum/jwt.hex:/data/jwt.hex
    depends_on:
      - geth
    ports:
      - 4000:4000
      - 3500:3500
    command:
      - --sepolia
      - --accept-terms-of-use
      - --datadir=/data
      - --disable-monitoring
      - --rpc-host=0.0.0.0
      - --execution-endpoint=http://127.0.0.1:8551
      - --jwt-secret=/data/jwt.hex
      - --rpc-port=4000
      - --grpc-gateway-corsdomain=*
      - --grpc-gateway-host=0.0.0.0
      - --grpc-gateway-port=3500
      - --min-sync-peers=3
      - --checkpoint-sync-url=https://checkpoint-sync.sepolia.ethpandaops.io
      - --genesis-beacon-api-url=https://checkpoint-sync.sepolia.ethpandaops.io
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
EOF

# === Firewall ===
echo -e "${YELLOW}🛡️ Налаштовуємо UFW...${NC}"
if command -v ufw &> /dev/null; then
  ufw allow 22/tcp
  ufw allow 30303/tcp
  ufw allow 30303/udp
  ufw allow from 127.0.0.1 to any port 8545 proto tcp
  ufw allow from 127.0.0.1 to any port 3500 proto tcp
  ufw --force enable
  ufw reload
fi

# === Запуск ===
echo -e "${YELLOW}🚀 Запускаємо вузли Geth + Prysm...${NC}"
cd /root/ethereum
docker compose up -d

sleep 3
echo -e "${GREEN}✅ Вузли запущені!${NC}"
echo -e "${YELLOW}Перевірка синхронізації:${NC}"
echo "curl -X POST -H 'Content-Type: application/json' --data '{\"jsonrpc\":\"2.0\",\"method\":\"eth_syncing\",\"params\":[],\"id\":1}' http://localhost:8545"
echo "curl http://localhost:3500/eth/v1/node/syncing"

echo -e "${GREEN}📡 RPC готові до використання в Aztec:${NC}"
echo -e "   🔸 ETHEREUM_RPC_URL=http://127.0.0.1:8545"
echo -e "   🔸 CONSENSUS_BEACON_URL=http://127.0.0.1:3500"
echo -e "\n🧠 Після повної синхронізації — можна запускати Aztec Sequencer."
