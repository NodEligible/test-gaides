#!/bin/bash

# === Кольори ===
GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

# Секунд на блок (Sepolia ≈ 12 c). Можеш змінити через env: BLOCK_TIME=12 ./check_sync.sh
BLOCK_TIME=${BLOCK_TIME:-12}

fmt_dur() {
  local s=$1; local d=$(( s/86400 )); s=$(( s%86400 ))
  local h=$(( s/3600 )); s=$(( s%3600 ))
  local m=$(( s/60 ))
  [[ $d -gt 0 ]] && echo "${d}d ${h}h ${m}m" && return
  [[ $h -gt 0 ]] && echo "${h}h ${m}m" && return
  [[ $m -gt 0 ]] && echo "${m}m" && return
  echo "<1m"
}

echo -e "${YELLOW}Перевірка синхронізації вузлів Ethereum (Geth + Prysm)...${NC}"
echo "────────────────────────────────────────────"

# ===== GETH (Execution Layer) =====
echo -e "${CYAN}➡️  Виконується перевірка Execution Node (Geth)...${NC}"
GETH_JSON=$(curl -s -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}' \
  http://localhost:8545)

# Перевірка доступності порту AuthRPC (8551)
if curl -s --connect-timeout 3 http://localhost:8551 >/dev/null; then
  echo -e "🔗 AuthRPC (8551): ${GREEN}✅ Відкритий${NC}"
else
  echo -e "🔗 AuthRPC (8551): ${RED}❌ Недоступний${NC}"
fi

if [[ "$GETH_JSON" == *'"result":false'* ]]; then
  echo -e "${GREEN}✅ Geth повністю синхронізовано!${NC}"
  echo -e "📉 Відставання: 0 блоків"
else
  # Hex значення
  START_HEX=$(echo "$GETH_JSON"   | grep -o '"startingBlock":"0x[0-9a-fA-F]*' | cut -d'"' -f4)
  CURR_HEX=$(echo  "$GETH_JSON"   | grep -o '"currentBlock":"0x[0-9a-fA-F]*'  | cut -d'"' -f4)
  HIGH_HEX=$(echo  "$GETH_JSON"   | grep -o '"highestBlock":"0x[0-9a-fA-F]*'  | cut -d'"' -f4)

  # Перетворення у decimal
  START_DEC=$((16#${START_HEX#0x})); CURR_DEC=$((16#${CURR_HEX#0x})); HIGH_DEC=$((16#${HIGH_HEX#0x}))
  LAG=$(( HIGH_DEC - CURR_DEC )); [[ $LAG -lt 0 ]] && LAG=0
  PCT=$(( CURR_DEC * 100 / HIGH_DEC 2>/dev/null || echo 100 ))
  ETA_SEC=$(( LAG * BLOCK_TIME ))
  ETA_HUMAN=$(fmt_dur "$ETA_SEC")

  # Нове правило толерантності
  if [[ $LAG -le 500 ]]; then
    echo -e "${GREEN}✅ Geth синхронізовано (мінімальне відставання ${LAG} блоків)${NC}"
  else
    echo -e "${RED}⏳ Geth ще синхронізується...${NC}"
    echo -e "📊 Початковий блок: ${YELLOW}${START_HEX}${NC} (${START_DEC})"
    echo -e "📈 Поточний блок:  ${YELLOW}${CURR_HEX}${NC} (${CURR_DEC})"
    echo -e "🏁 Найвищий блок:  ${YELLOW}${HIGH_HEX}${NC} (${HIGH_DEC})"
    echo -e "📉 Відставання:     ${YELLOW}${LAG}${NC} блоків  | 🔢 Прогрес: ${YELLOW}${PCT}%${NC}  | ⏱️ ETA: ${YELLOW}${ETA_HUMAN}${NC}"
  fi
fi

echo "────────────────────────────────────────────"

# ===== PRYSM (Beacon Node) =====
echo -e "${CYAN}➡️  Виконується перевірка Beacon Node (Prysm)...${NC}"
PRYSM_JSON=$(curl -s http://localhost:3500/eth/v1/node/syncing)

IS_SYNC=$(echo "$PRYSM_JSON" | grep -o '"is_syncing":[^,]*'     | cut -d':' -f2 | tr -d ' ')
DIST=$(   echo "$PRYSM_JSON" | grep -o '"sync_distance":"[^"]*' | cut -d'"' -f4)
HEAD=$(   echo "$PRYSM_JSON" | grep -o '"head_slot":"[^"]*'     | cut -d'"' -f4)
EL_OFFLINE=$(echo "$PRYSM_JSON" | grep -o '"el_offline":[^,]*' | cut -d':' -f2 | tr -d ' ')

if [[ "$IS_SYNC" == "false" && "$DIST" == "0" ]]; then
  echo -e "${GREEN}✅ Prysm повністю синхронізовано!${NC}"
  echo -e "📉 Відставання: 0 слотів | 🧩 Head slot: ${YELLOW}${HEAD}${NC}"
else
  echo -e "${RED}⏳ Prysm ще синхронізується...${NC}"
  echo -e "🧩 Head slot:   ${YELLOW}${HEAD}${NC}"
  echo -e "📉 Відставання: ${YELLOW}${DIST}${NC} слотів"
  echo -e "🔁 is_syncing:  ${YELLOW}${IS_SYNC}${NC}"
fi

# Новий блок: перевірка підключення до Execution Layer
if [[ "$EL_OFFLINE" == "true" ]]; then
  echo -e "🔗 Execution layer connection: ${RED}❌ Offline${NC}"
else
  echo -e "🔗 Execution layer connection: ${GREEN}✅ Online${NC}"
fi

echo "────────────────────────────────────────────"
echo -e "${GREEN}Готово!${NC}"
