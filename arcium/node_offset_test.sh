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
max_attempts=10   # рестриктуємо 10 спроб, щоб не зависало

while [ $attempt -lt $max_attempts ]; do
  attempt=$((attempt + 1))
  CANDIDATE=$(shuf -i 10000000-99999999 -n 1)

  echo -e "${YELLOW}➡ Проверка OFFSET=${CYAN}$CANDIDATE${YELLOW} (попытка $attempt/${max_attempts})...${NC}"

  OUTPUT=$(arcium arx-info "$CANDIDATE" --rpc-url "$RPC_URL" 2>&1)
  EXIT_CODE=$?

  # --- RPC не отвечает --- считаем попытку, не зацикливаемся!
  if echo "$OUTPUT" | grep -qi "rpc" || [ $EXIT_CODE -ne 0 ]; then
    echo -e "${RED}⚠ RPC ошибка, продолжаю...${NC}"
    continue
  fi

  # --- Свободный offset ---
  if echo "$OUTPUT" | grep -q "Error: Account info not found"; then
    NODE_OFFSET="$CANDIDATE"
    echo -e "${GREEN}✅ Найден свободный NODE_OFFSET=${CYAN}$NODE_OFFSET${NC}"
    break
  fi

  # --- Занятый offset ---
  if echo "$OUTPUT" | grep -q "Node authority"; then
    echo -e "${RED}❌ Offset занят, пробую другой...${NC}"
    continue
  fi

  # --- Неизвестный ответ ---
  echo -e "${YELLOW}⚠ Неизвестный ответ, продолжаю...${NC}"
  echo "$OUTPUT" | head -n 5
done


# === РУЧНОЙ РЕЖИМ ===
if [ -z "$NODE_OFFSET" ]; then
  echo -e "${RED}❌ Автоматически подобрать свободный OFFSET не удалось за $max_attempts попыток.${NC}"
  echo -e "${YELLOW}🔧 Переход в ручной режим ввода OFFSET.${NC}"

  while true; do
    read -r -p "$(echo -e "${YELLOW}➡ Введите 8-значный NODE_OFFSET: ${NC}")" MANUAL_OFFSET

    if [[ ! "$MANUAL_OFFSET" =~ ^[0-9]{8}$ ]]; then
      echo -e "${RED}⚠ Неверный формат — нужно ровно 8 цифр.${NC}"
      continue
    fi

    OUTPUT=$(arcium arx-info "$MANUAL_OFFSET" --rpc-url "$RPC_URL" 2>&1)

    # свободен
    if echo "$OUTPUT" | grep -q "Error: Account info not found"; then
      NODE_OFFSET="$MANUAL_OFFSET"
      echo -e "${GREEN}✅ OFFSET свободен и принят: ${CYAN}$NODE_OFFSET${NC}"
      break
    fi

    # занят
    if echo "$OUTPUT" | grep -q "Node authority"; then
      echo -e "${RED}❌ OFFSET занят, попробуйте другой.${NC}"
      continue
    fi

    echo -e "${RED}⚠ Неизвестный ответ, попробуйте другой:${NC}"
    echo "$OUTPUT"
  done
fi

echo -e "${GREEN}✨ Итоговый NODE_OFFSET=${CYAN}$NODE_OFFSET${NC}"


