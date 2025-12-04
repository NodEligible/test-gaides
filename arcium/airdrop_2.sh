#!/bin/bash

YELLOW='\e[0;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

NODE_PUBKEY="E1GQBoudCZjPDK4U28XxyYQDKhwaMGQYKUKNp2tedeFQ"
CALLBACK_PUBKEY="7PiBDzmXBpfCYP5zZ69SHfdKnMud6QdaAVmDnMLjy7Aa"

echo -e "${YELLOW}💸 Тестируем Airdrop SOL для Node Authority...${NC}"

airdrop_node() {
  local pubkey="$1"
  local label="$2"

  for tries in {1..5}; do
    echo -e "${YELLOW}➡ Airdrop для ${label} (${CYAN}$pubkey${YELLOW}), попытка $tries...${NC}"

    OUT=$(solana airdrop 2 "$pubkey" -u devnet 2>&1)

    if echo "$OUT" | grep -q "Signature:"; then
      echo -e "${GREEN}⏳ Транзакция отправлена. Проверяю баланс...${NC}"

      for i in {1..5}; do
        BAL=$(solana balance "$pubkey" -u devnet 2>/dev/null | awk '{print $1}')
        if [[ "$BAL" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
          echo -e "${GREEN}✅ Баланс ${label}: ${CYAN}${BAL} SOL${NC}"
          return 0
        fi
        sleep 2
      done

      echo -e "${RED}⚠ Баланс не обновился, пробую снова...${NC}"
    else
      echo -e "${RED}⚠ Ошибка faucet, повтор...${NC}"
    fi
    sleep 2
  done

  echo -e "${RED}❌ Не удалось получить SOL для ${label}.${NC}"
  return 1
}

# -----------------------------------------
# 1. Airdrop только для Node Authority
# -----------------------------------------
airdrop_node "$NODE_PUBKEY" "Node Authority"

echo
echo -e "${CYAN}📘 Теперь необходимо вручную получить SOL на Callback Authority.${NC}"
echo -e "${CYAN}🔗 Перейдите на сайт: ${GREEN}https://solfaucet.com/${NC}"
echo
echo -e "${YELLOW}➡ Вставьте этот адрес:${NC}"
echo -e "${GREEN}$CALLBACK_PUBKEY${NC}"
echo
echo -e "${YELLOW}➡ Выберите сеть: ${GREEN}DEVNET${NC}"
echo -e "${YELLOW}➡ В Amount укажите: ${GREEN}2 SOL${NC}"
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
