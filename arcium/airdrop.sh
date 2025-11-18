#!/bin/bash

YELLOW='\e[0;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

NODE_PUBKEY="E1GQBoudCZjPDK4U28XxyYQDKhwaMGQYKUKNp2tedeFQ"
CALLBACK_PUBKEY="7PiBDzmXBpfCYP5zZ69SHfdKnMud6QdaAVmDnMLjy7Aa"

echo -e "${YELLOW}💸 Тестируем Airdrop SOL...${NC}"

airdrop_with_retry() {
  local pubkey="$1"
  local label="$2"
  local tries=0
  local max_tries=5

  while [ $tries -lt $max_tries ]; do
    tries=$((tries + 1))

    echo -e "${YELLOW}➡ Airdrop для ${label} (${CYAN}$pubkey${YELLOW}), попытка $tries...${NC}"

    AIRDROP_OUTPUT=$(solana airdrop 2 "$pubkey" -u devnet 2>&1)
    AIRDROP_CODE=$?

    if echo "$AIRDROP_OUTPUT" | grep -q "Signature:"; then
      echo -e "${GREEN}⏳ Транзакция отправлена. Проверяю баланс...${NC}"

      for i in {1..5}; do
        BAL=$(solana balance "$pubkey" -u devnet 2>/dev/null | awk '{print $1}')

        if [[ "$BAL" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
          echo -e "${GREEN}✅ Баланс ${label}: ${CYAN}${BAL} SOL${NC}"
          return 0
        fi

        sleep 2
      done

      echo -e "${RED}⚠ Airdrop отправлен, но баланс не обновился. Пробую снова...${NC}"
      sleep 2
      continue
    fi

    echo -e "${RED}⚠ Faucet вернул ошибку, повтор...${NC}"
    sleep 2
  done

  echo -e "${RED}❌ Airdrop для ${label} не удался.${NC}"
  return 1
}

airdrop_with_retry "$NODE_PUBKEY" "Node Authority"
airdrop_with_retry "$CALLBACK_PUBKEY" "Callback Authority"

echo -e "${GREEN}🎯 Тест завершён.${NC}"
