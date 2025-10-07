#!/usr/bin/env bash
set -euo pipefail

# === Кольори ===
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# === Шляхи ===
AZTEC_DIR="/root/aztec"
ENV_FILE="$AZTEC_DIR/.env"

# === Перевірка файлу змінних ===
if [ ! -f "$ENV_FILE" ]; then
  echo -e "${RED}❌ Файл $ENV_FILE не знайдено! Спочатку створи .env.${NC}"
  exit 1
fi

# === Завантаження змінних з .env ===
export $(grep -v '^\s*#' "$ENV_FILE" | xargs)

# === Перевірка необхідних змінних ===
REQUIRED_VARS=(ETHEREUM_RPC_URL VALIDATOR_PRIVATE_KEY COINBASE)
for var in "${REQUIRED_VARS[@]}"; do
  if [ -z "${!var:-}" ]; then
    echo -e "${RED}❌ Змінна $var відсутня або порожня в $ENV_FILE.${NC}"
    exit 1
  fi
done

echo -e "${YELLOW}🔗 Починаю реєстрацію валідатора...${NC}"

# === Виконання команди в контейнері ===
output=$(docker exec -i aztec-sequencer \
  sh -c 'node /usr/src/yarn-project/aztec/dest/bin/index.js add-l1-validator \
    --l1-rpc-urls "'"${ETHEREUM_RPC_URL}"'" \
    --private-key "'"${VALIDATOR_PRIVATE_KEY}"'" \
    --attester "'"${COINBASE}"'" \
    --proposer-eoa "'"${COINBASE}"'" \
    --staking-asset-handler 0xF739D03e98e23A7B65940848aBA8921fF3bAc4b2 \
    --l1-chain-id 11155111' 2>&1) || true

# === Обробка квоти або помилок ===
if printf '%s\n' "$output" | grep -q 'ValidatorQuotaFilledUntil'; then
  ts=$(printf '%s\n' "$output" | grep -oP '\(\K[0-9]+(?=\))' | head -n1)
  now=$(date +%s)
  delta=$(( ts - now ))
  hours=$(( delta / 3600 ))
  mins=$(( (delta % 3600) / 60 ))
  echo -e "${RED}⚠️ Квота на реєстрацію валідаторів перевищена.${NC}"
  echo -e "${YELLOW}🕒 Спробуй знову через ${hours} год ${mins} хв.${NC}"
else
  echo -e "${GREEN}✅ Відповідь від ноди:${NC}"
  echo "$output"
fi
