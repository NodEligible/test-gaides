#!/bin/bash
curl -s https://raw.githubusercontent.com/NodEligible/programs/main/display_logo.sh | bash

# Сменные для цветов
YELLOW='\e[0;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[38;5;81m'
NC='\033[0m' # Сброс цвета

echo -e "${YELLOW}Установка дополнительных программ скрыта, просто ждите...${NC}"
bash <(curl -s https://raw.githubusercontent.com/NodEligible/programs/main/docker.sh) &>/dev/null

# Создание директории
mkdir -p "$HOME/aztec-sequencer/data"
cd "$HOME/aztec-sequencer"

docker pull aztecprotocol/aztec:2.0.2

# Ввод данных
read -p "🔗 Вставьте ваш URL RPC Sepolia: " RPC
read -p "🔗 Вставьте ваш URL Beacon Sepolia: " CONSENSUS
read -p "🔐 Вставьте приватный ключ от кошелька (0x…): " PRIVATE_KEY
read -p "💰 Вставьте адрес вашего кошелька (0x…): " WALLET

# Получаем IP
SERVER_IP=$(curl -s https://api.ipify.org)

# Создаем .env
cat > .env <<EOF
ETHEREUM_HOSTS=$RPC
L1_CONSENSUS_HOST_URLS=$CONSENSUS
VALIDATOR_PRIVATE_KEY=$PRIVATE_KEY
P2P_IP=$SERVER_IP
WALLET=$WALLET
GOVERNANCE_PROPOSER_PAYLOAD_ADDRESS=0x54F7fe24E349993b363A5Fa1bccdAe2589D5E5Ef
EOF

# Запуск контейнера
docker run -d \
--name aztec-sequencer \
--network host \
--memory=10g \
--memory-swap=12g \
--env-file "$HOME/aztec-sequencer/.env" \
-v "$HOME/aztec-sequencer/data":/data \
aztecprotocol/aztec:2.0.2 \
node --max-old-space-size=8192 --max-semi-space-size=1024 --optimize-for-size --no-warnings /usr/src/yarn-project/aztec/dest/bin/index.js \
start --network testnet --node --archiver --sequencer \
--sequencer.validatorPrivateKeys "$PRIVATE_KEY" \
--l1-rpc-urls "$RPC" \
--l1-consensus-host-urls "$CONSENSUS" \
--sequencer.coinbase "$WALLET" \
--p2p.p2pIp "$SERVER_IP"

echo -e "${GREEN}✅ Aztec sequencer успешно запущен!${NC}"
cd ~


