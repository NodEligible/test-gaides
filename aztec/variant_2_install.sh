#!/bin/bash
curl -s https://raw.githubusercontent.com/NodEligible/programs/main/display_logo.sh | bash

set -e

# 🎨 Цвета
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'


echo -e "${YELLOW}🔗 Введите параметры для установки Aztec Sequencer:${NC}"
read -p "➡️  RPC URL (Sepolia): " RPC
read -p "➡️  Beacon URL (Sepolia): " CONSENSUS
read -p "💰 Адрес кошелька (0x...): " WALLET
read -p "🔐 Приватный ключ (0x...): " PRIVATE_KEY


# echo -e "${YELLOW}⏳ Устанавливаем зависимости и Docker установка скрыта...${NC}"
# bash <(curl -s https://raw.githubusercontent.com/NodEligible/programs/main/docker.sh) &>/dev/null
# bash <(curl -s https://raw.githubusercontent.com/NodEligible/programs/refs/heads/main/main.sh) &>/dev/null
# bash <(curl -s https://raw.githubusercontent.com/NodEligible/programs/refs/heads/main/ufw.sh) &>/dev/null

echo -e "${YELLOW} Установка Aztec Tools...${NC}"
bash -i <(curl -s https://install.aztec.network)

echo 'export PATH="$HOME/.aztec/bin:$PATH"' >> ~/.bashrc

source ~/.bashrc

echo -e "${YELLOW}📁 Создание рабочей директории...${NC}"
# 📁 Создание рабочей директории
AZTEC_DIR="/root/aztec"
mkdir -p "$AZTEC_DIR"
cd "$AZTEC_DIR"

# 🌐 Получаем IP
SERVER_IP=$(curl -s https://api.ipify.org)

echo -e "${YELLOW}🧾 Создание .env...${NC}"
# 🧾 Создание .env
cat > "$AZTEC_DIR/.env" <<EOF
ETHEREUM_HOSTS=$RPC
L1_CONSENSUS_HOST_URLS=$CONSENSUS
VALIDATOR_PRIVATE_KEY=$PRIVATE_KEY
P2P_IP=$SERVER_IP
COINBASE=$WALLET
GOVERNANCE_PROPOSER_PAYLOAD_ADDRESS=0x54F7fe24E349993b363A5Fa1bccdAe2589D5E5Ef
EOF

echo -e "${YELLOW}🧩Создание docker-compose.yml...${NC}"
# 🧩 Создание docker-compose.yml
cat > "$AZTEC_DIR/docker-compose.yml" <<EOF
version: '3.8'

services:
  aztec-node:
    container_name: aztec-sequencer
    image: aztecprotocol/aztec:latest
    network_mode: host
    restart: unless-stopped
    env_file: .env
    environment:
      DATA_DIRECTORY: /data
      LOG_LEVEL: debug
    entrypoint: >
      sh -c 'node --no-warnings /usr/src/yarn-project/aztec/dest/bin/index.js
      start --network testnet --node --archiver --sequencer --rpc.port 8090'
    ports:
      - 40400:40400/tcp
      - 40400:40400/udp
      - 8090:8090
    volumes:
      - /root/.aztec/testnet/data/:/data
EOF

echo -e "${YELLOW}⚙️ Создаем systemd-сервис...${NC}"
# ⚙️ Создаем systemd-сервис
sudo tee /etc/systemd/system/aztec.service > /dev/null <<EOF
[Unit]
Description=Aztec Sequencer Node (Docker Compose)
After=network.target docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$AZTEC_DIR
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
TimeoutStartSec=10
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# 🔄 Перезагружаем systemd и запускаем сервис
sudo systemctl daemon-reload
sudo systemctl enable aztec
sudo systemctl start aztec

# ⏱ Проверяем статус
sleep 5
if systemctl is-active --quiet aztec; then
  echo -e "${GREEN}✅ Aztec Sequencer успешно запущен!${NC}"
else
  echo -e "${RED}❌ Ошибка при запуске сервиса aztec.${NC}"
fi

sleep 10 

# 🧪 Проверка RPC-порта
echo -e "${YELLOW}Проверяем RPC на порту 8090...${NC}"
sleep 3
if curl -s -X POST http://localhost:8090 --data '{"method":"node_getL2Tips"}' | grep -q '"result"'; then
  echo -e "${GREEN}✅ RPC отвечает успешно (порт 8090).${NC}"
else
  echo -e "${RED}⚠️ RPC пока не отвечает. Возможно, нода еще инициализируется.${NC}"
fi

