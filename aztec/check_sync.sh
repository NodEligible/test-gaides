#!/bin/bash

# === Кольори ===
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${YELLOW}🔍 Перевірка синхронізації вузлів Ethereum (Geth + Prysm)...${NC}"
echo "────────────────────────────────────────────"

# === Перевірка Geth ===
echo -e "${CYAN}➡️  Виконується перевірка Execution Node (Geth)...${NC}"
GETH_RESPONSE=$(curl -s -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}' \
  http://localhost:8545)

if [[ "$GETH_RESPONSE" == *'"result":false'* ]]; then
  echo -e "${GREEN}✅ Geth повністю синхронізовано!${NC}"
else
  CURRENT=$(echo "$GETH_RESPONSE" | grep -o '"currentBlock":"[^"]*' | cut -d'"' -f4)
  HIGHEST=$(echo "$GETH_RESPONSE" | grep -o '"highestBlock":"[^"]*' | cut -d'"' -f4)
  START=$(echo "$GETH_RESPONSE" | grep -o '"startingBlock":"[^"]*' | cut -d'"' -f4)
  echo -e "${RED}⏳ Geth ще синхронізується...${NC}"
  echo -e "📊 Початковий блок: ${YELLOW}${START}${NC}"
  echo -e "📈 Поточний блок:  ${YELLOW}${CURRENT}${NC}"
  echo -e "🏁 Найвищий блок:  ${YELLOW}${HIGHEST}${NC}"
fi

echo "────────────────────────────────────────────"

# === Перевірка Prysm ===
echo -e "${CYAN}➡️  Виконується перевірка Beacon Node (Prysm)...${NC}"
PRYSM_RESPONSE=$(curl -s http://localhost:3500/eth/v1/node/syncing)

IS_SYNCING=$(echo "$PRYSM_RESPONSE" | grep -o '"is_syncing":[^,]*' | cut -d':' -f2 | tr -d ' ')
SYNC_DISTANCE=$(echo "$PRYSM_RESPONSE" | grep -o '"sync_distance":"[^"]*' | cut -d'"' -f4)
HEAD_SLOT=$(echo "$PRYSM_RESPONSE" | grep -o '"head_slot":"[^"]*' | cut -d'"' -f4)

if [[ "$IS_SYNCING" == "false" && "$SYNC_DISTANCE" == "0" ]]; then
  echo -e "${GREEN}✅ Prysm повністю синхронізовано!${NC}"
else
  echo -e "${RED}⏳ Prysm ще синхронізується...${NC}"
  echo -e "🧩 Head slot:      ${YELLOW}${HEAD_SLOT}${NC}"
  echo -e "📉 Відставання:    ${YELLOW}${SYNC_DISTANCE}${NC} слотів"
  echo -e "🔁 is_syncing:     ${YELLOW}${IS_SYNCING}${NC}"
fi

echo "────────────────────────────────────────────"
echo -e "${GREEN}Готово!${NC}"
