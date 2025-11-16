#!/bin/bash

YELLOW='\e[0;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[38;5;81m'
CYAN='\033[0;36m'
NC='\033[0m'

# ---------- Шаг 4: Node Offset ----------
echo -e "${YELLOW}🔢 Генерация уникального Node Offset...${NC}"

NODE_OFFSET=""
attempt=0
max_attempts=50  # увеличил чтобы наверняка

while [ -z "$NODE_OFFSET" ] && [ $attempt -lt $max_attempts ]; do
  attempt=$((attempt + 1))
  CANDIDATE=$(shuf -i 10000000-99999999 -n 1)

  echo -e "${YELLOW}➡ Пробую NODE_OFFSET=${CYAN}$CANDIDATE${YELLOW} (попытка $attempt)...${NC}"

  OUTPUT=$(arcium arx-info "$CANDIDATE" --rpc-url "$RPC_URL" 2>&1)
  EXIT_CODE=$?

  # --- RPC не отвечает ---
  if echo "$OUTPUT" | grep -qi "rpc" || [ $EXIT_CODE -ne 0 ]; then
    echo -e "${YELLOW}⚠ RPC не отвечает, повторяю...${NC}"
    sleep 1
    continue
  fi

  # --- Вильный Offset ---
  if echo "$OUTPUT" | grep -q "Error: Account info not found"; then
    NODE_OFFSET="$CANDIDATE"
    break
  fi

  # --- Зайнятий Offset ---
  if echo "$OUTPUT" | grep -q "Node authority"; then
    echo -e "${RED}❌ Offset $CANDIDATE занят.${NC}"
    continue
  fi

  # --- Непонятный ответ ---
  echo -e "${YELLOW}⚠ Неизвестный ответ от arx-info, повтор...${NC}"
  echo "$OUTPUT" | head -n 5
  sleep 1

done

if [ -z "$NODE_OFFSET" ]; then
  echo -e "${RED}❌ Не удалось подобрать свободный NODE_OFFSET.${NC}"
  exit 1
fi

echo -e "${GREEN}✅ Выбран свободный NODE_OFFSET=${CYAN}$NODE_OFFSET${NC}"
