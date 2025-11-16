#!/bin/bash

RPC_URL="https://api.devnet.solana.com"

YELLOW='\e[0;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

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
