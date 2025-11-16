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

# Если автоматический подбор не нашел свободный OFFSET
if [ -z "$NODE_OFFSET" ]; then
  echo -e "${RED}❌ Автоматически подобрать NODE_OFFSET не удалось.${NC}"
  echo -e "${YELLOW}🔧 Переходим в ручной режим выбора OFFSET.${NC}"

  while true; do
    read -r -p "$(echo -e "${YELLOW}➡ Введи 8-значный NODE_OFFSET вручную: ${NC}")" MANUAL_OFFSET

    # Проверка что это число и что 8 цифр
    if [[ ! "$MANUAL_OFFSET" =~ ^[0-9]{8}$ ]]; then
      echo -e "${RED}⚠ Неверный формат. Нужно ровно 8 цифр.${NC}"
      continue
    fi

    echo -e "${YELLOW}🔍 Проверяю OFFSET ${CYAN}$MANUAL_OFFSET${NC}..."

    OUTPUT=$(arcium arx-info "$MANUAL_OFFSET" --rpc-url "$RPC_URL" 2>&1)
    EXIT_CODE=$?

    # Ошибки RPC
    if echo "$OUTPUT" | grep -qi "rpc" || [ $EXIT_CODE -ne 0 ]; then
      echo -e "${RED}⚠ RPC недоступен. Попробуй снова.${NC}"
      continue
    fi

    # Свободный OFFSET
    if echo "$OUTPUT" | grep -q "Error: Account info not found"; then
      NODE_OFFSET="$MANUAL_OFFSET"
      echo -e "${GREEN}✅ OFFSET свободен и принят: ${CYAN}$NODE_OFFSET${NC}"
      break
    fi

    # Занятый
    if echo "$OUTPUT" | grep -q "Node authority"; then
      echo -e "${RED}❌ OFFSET занят. Попробуй другой.${NC}"
      continue
    fi

    # Им неизвестный ответ
    echo -e "${RED}⚠ Непредвиденный ответ, попробуй другой OFFSET:${NC}"
    echo "$OUTPUT"
  done
fi

echo -e "${GREEN}✅ Использую NODE_OFFSET=${CYAN}$NODE_OFFSET${NC}"

