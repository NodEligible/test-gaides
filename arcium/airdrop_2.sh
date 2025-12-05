#!/bin/bash

YELLOW='\e[0;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

NODE_PUBKEY="FHX6un8FPFVyCbap3LizBygSecQbFwgZYj7wPcZiAVd6"
CALLBACK_PUBKEY="8SkiLqHKnfnARnuNj9Xn54qn2BYxLj768x8fAoNbyw7B"

echo -e "${YELLOW}💸 Тестируем Airdrop SOL для Node Authority...${NC}"

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

    # Если команда вообще выполнилась (код возврата = 0)
    if [ $AIRDROP_CODE -eq 0 ]; then
      echo -e "${GREEN}⏳ Airdrop отправлен. Проверяю баланс...${NC}"

      for i in {1..5}; do
        BAL=$(solana balance "$pubkey" -u devnet 2>/dev/null | awk '{print $1}')

        if [[ "$BAL" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
          echo -e "${GREEN}✅ Баланс ${label}: ${CYAN}${BAL} SOL${NC}"
          return 0
        fi

        sleep 2
      done

      echo -e "${RED}⚠ Баланс пока не обновился. Пробую снова...${NC}"
      sleep 2
      continue
    fi

    echo -e "${RED}⚠ Faucet вернул ошибку, повтор через 3 сек...${NC}"
    sleep 3
  done

  echo -e "${RED}❌ Не удалось выполнить airdrop для ${label}.${NC}"
  return 1
}

# -----------------------------------------
# 1. Airdrop только для Node Authority
# -----------------------------------------
airdrop_with_retry "$NODE_PUBKEY" "Node Authority"

echo
echo -e "${CYAN}📘 Теперь необходимо вручную получить SOL на Callback Authority.${NC}"
echo -e "${CYAN}🔗 Перейдите на сайт: ${GREEN}https://solfaucet.com/${NC}"
echo
echo -e "${YELLOW}➡ Вставьте этот адрес:${NC}"
echo -e "${GREEN}$CALLBACK_PUBKEY${NC}"
echo
echo -e "${YELLOW}➡ В Amount укажите: ${GREEN}2 SOL${NC}"
echo -e "${YELLOW}➡ Выберите сеть: ${GREEN}DEVNET${NC}"
echo -e "${YELLOW}➡ Нажмите кнопку: ${GREEN}Request Airdrop${NC}"
echo
echo -e "${CYAN}⏳ Ожидаю 60 секунд, чтобы баланс обновился...${NC}"
sleep 60

# -----------------------------------------
# 2. Автоматическая проверка баланса Callback Authority
# -----------------------------------------
echo
echo -e "${YELLOW}🔍 Проверяю баланс Callback Authority...${NC}"

CB_BAL=$(solana balance "$CALLBACK_PUBKEY" -u devnet 2>/dev/null | awk '{print $1}')

if [[ "$CB_BAL" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
  echo -e "${GREEN}💰 Баланс Callback Authority: ${CYAN}${CB_BAL} SOL${NC}"
else
  echo -e "${RED}⚠ Не удалось получить баланс. Возможно SOL ещё не пришли.${NC}"
fi

# -----------------------------------------
# 3. Спросить пользователя — продолжать ли установку
# -----------------------------------------
echo
read -rp "Продолжить установку? [Y/n]: " ans
ans=${ans:-Y}

if [[ "$ans" =~ ^[Yy]$ ]]; then
  echo -e "${GREEN}✔ Продолжаем установку...${NC}"
else
  echo -e "${RED}✖ Установка остановлена пользователем.${NC}"
  exit 1
fi
