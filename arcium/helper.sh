#!/usr/bin/env bash
# Arcium node helper
# Работает с директорией /root/arcium-node-setup и контейнером arx-node

#########################
#  Цвета
#########################
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

#########################
#  Базовые пути / константы
#########################
NODE_DIR="/root/arcium-node-setup"
ENV_FILE="$NODE_DIR/.env"
NODE_KP_FILE="$NODE_DIR/node-keypair.json"
CALLBACK_KP_FILE="$NODE_DIR/callback-kp.json"
CFG_FILE="$NODE_DIR/node-config.toml"
IDENTITY_FILE="$NODE_DIR/identity.pem"

CONTAINER_NAME="arx-node"
EXTERNAL_PORT="8088"

#########################
#  Вспомогательные функции
#########################

pause() {
  echo
  read -rp "Нажмите Enter, чтобы продолжить..." _
}

check_file() {
  local file="$1"
  if [[ ! -f "$file" ]]; then
    echo -e "${RED}⚠ Файл не найден: ${file}${NC}"
    return 1
  fi
  return 0
}

check_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo -e "${RED}⚠ Команда не найдена: ${cmd}${NC}"
    return 1
  fi
  return 0
}

load_env() {
  if ! check_file "$ENV_FILE"; then
    return 1
  fi

  # Загружаем только нужные переменные
  # (чтобы не ломать окружение)
  while IFS='=' read -r key value; do
    [[ -z "$key" || "$key" =~ ^# ]] && continue
    key=$(echo "$key" | tr -d ' ')
    value=$(echo "$value" | sed 's/^ *//; s/ *$//')
    export "$key=$value"
  done < "$ENV_FILE"
}

print_header() {
  clear
  echo -e "${BLUE}============================================${NC}"
  echo -e "${BLUE}        Arcium Node Helper (multi-mode)     ${NC}"
  echo -e "${BLUE}============================================${NC}"
  echo -e "${CYAN}Рабочая директория:${NC} ${NODE_DIR}"
  echo
}

#########################
#  Режим 1: Инфо по ноде
#########################
mode_info() {
  print_header
  echo -e "${YELLOW}▶ РЕЖИМ 1: Информация о ноде и ключах${NC}"
  echo

  # Загружаем .env
  if ! load_env; then
    echo -e "${RED}❌ Не удалось загрузить ${ENV_FILE}${NC}"
  else
    echo -e "${GREEN}✓ Загрузен файл .env${NC}"
  fi
  echo

  echo -e "${CYAN}Основные ключи из .env:${NC}"
  echo -e "  NODE_PUBKEY      : ${GREEN}${NODE_PUBKEY:-не задан}${NC}"
  echo -e "  CALLBACK_PUBKEY  : ${GREEN}${CALLBACK_PUBKEY:-не задан}${NC}"
  echo -e "  NODE_OFFSET      : ${YELLOW}${NODE_OFFSET:-не задан}${NC}"
  echo -e "  CLUSTER_OFFSET   : ${YELLOW}${CLUSTER_OFFSET:-не задан}${NC}"
  echo
  echo -e "${CYAN}Solana endpoints:${NC}"
  echo -e "  RPC_URL          : ${GREEN}${RPC_URL:-не задан}${NC}"
  echo -e "  WSS_URL          : ${GREEN}${WSS_URL:-не задан}${NC}"
  echo

  # Инфо из node-config.toml
  if check_file "$CFG_FILE"; then
    echo -e "${CYAN}Данные из node-config.toml:${NC}"

    local offset hardware_claim start_epoch end_epoch address cluster commitment
    offset=$(grep -E '^offset' "$CFG_FILE" 2>/dev/null | head -n1 | sed 's/.*=\s*//')
    hardware_claim=$(grep -E '^hardware_claim' "$CFG_FILE" 2>/dev/null | sed 's/.*=\s*//')
    start_epoch=$(grep -E '^starting_epoch' "$CFG_FILE" 2>/dev/null | sed 's/.*=\s*//')
    end_epoch=$(grep -E '^ending_epoch' "$CFG_FILE" 2>/dev/null | sed 's/.*=\s*//')
    address=$(grep -E '^address' "$CFG_FILE" 2>/dev/null | sed 's/.*=\s*"\(.*\)".*/\1/')
    cluster=$(grep -E '^cluster' "$CFG_FILE" 2>/dev/null | sed 's/.*=\s*"\(.*\)".*/\1/')
    commitment=$(grep -E 'commitment.commitment' "$CFG_FILE" 2>/dev/null | sed 's/.*=\s*"\(.*\)".*/\1/')

    echo -e "  offset           : ${YELLOW}${offset:-не найдено}${NC}"
    echo -e "  hardware_claim   : ${YELLOW}${hardware_claim:-не найдено}${NC}"
    echo -e "  starting_epoch   : ${YELLOW}${start_epoch:-не найдено}${NC}"
    echo -e "  ending_epoch     : ${YELLOW}${end_epoch:-не найдено}${NC}"
    echo -e "  network address  : ${GREEN}${address:-не найдено}${NC}"
    echo -e "  cluster          : ${GREEN}${cluster:-не найдено}${NC}"
    echo -e "  commitment       : ${GREEN}${commitment:-не найдено}${NC}"
    echo
  else
    echo -e "${RED}⚠ node-config.toml не найден${NC}"
  fi

  # identity.pem fingerprint
  if check_file "$IDENTITY_FILE"; then
    echo -e "${CYAN}Identity (identity.pem):${NC}"
    if check_cmd sha256sum; then
      local fp
      fp=$(sha256sum "$IDENTITY_FILE" | awk '{print $1}')
      echo -e "  SHA256 fingerprint: ${GREEN}${fp}${NC}"
    else
      echo -e "  identity.pem найден, но команда sha256sum отсутствует"
    fi
    echo
  else
    echo -e "${RED}⚠ identity.pem не найден${NC}"
    echo
  fi

  # node-keypair.json / callback-kp.json (секретные данные по запросу)
  echo -e "${YELLOW}Показать содержимое приватных ключей (JSON и PEM)?${NC}"
  echo -e "${RED}ВНИМАНИЕ: НЕ ДЕЛАЙТЕ ЭТО НА СКРИНАХ И В ПУБЛИЧНЫХ ЛОГАХ!${NC}"
  read -rp "Показать чувствительные данные? [y/N]: " show_secrets

  if [[ "$show_secrets" =~ ^[Yy]$ ]]; then
    echo
    if check_file "$NODE_KP_FILE"; then
      echo -e "${CYAN}node-keypair.json:${NC}"
      cat "$NODE_KP_FILE"
      echo
      echo
    else
      echo -e "${RED}⚠ node-keypair.json не найден${NC}"
      echo
    fi

    if check_file "$CALLBACK_KP_FILE"; then
      echo -e "${CYAN}callback-kp.json:${NC}"
      cat "$CALLBACK_KP_FILE"
      echo
      echo
    else
      echo -e "${RED}⚠ callback-kp.json не найден${NC}"
      echo
    fi

    if check_file "$IDENTITY_FILE"; then
      echo -e "${CYAN}identity.pem:${NC}"
      cat "$IDENTITY_FILE"
      echo
    fi
  else
    echo
    echo -e "${GREEN}✓ Приватные данные не показаны (защита от лишних утечек).${NC}"
  fi

  echo
  pause
}

#########################
#  Режим 2: Генерация команд
#########################
mode_commands() {
  print_header
  echo -e "${YELLOW}▶ РЕЖИМ 2: Генерация команд с автоподстановкой${NC}"
  echo

  load_env >/dev/null 2>&1 || true

  local node_pk="${NODE_PUBKEY:-<NODE_PUBKEY_НЕ_ЗАДАН>}"
  local cb_pk="${CALLBACK_PUBKEY:-<CALLBACK_PUBKEY_НЕ_ЗАДАН>}"
  local rpc="${RPC_URL:-https://api.devnet.solana.com}"

  echo -e "${CYAN}Команды для Solana:${NC}"
  echo "solana config set --url $rpc"
  echo "solana account $node_pk"
  echo "solana balance $node_pk"
  echo
  echo "solana account $cb_pk"
  echo "solana balance $cb_pk"
  echo

  echo -e "${CYAN}Команды для проверки ноды / Docker:${NC}"
  echo "docker ps | grep $CONTAINER_NAME"
  echo "docker logs $CONTAINER_NAME --tail 50"
  echo "docker logs $CONTAINER_NAME -f"
  echo "docker restart $CONTAINER_NAME"
  echo

  echo -e "${CYAN}Команда для проверки порта с хоста:${NC}"
  echo "ss -tulpn | grep :$EXTERNAL_PORT"
  echo

  echo -e "${CYAN}Простой health-check RPC Solana:${NC}"
  echo "curl -s -X POST \"$rpc\" -H \"Content-Type: application/json\" -d '{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"getHealth\"}'"
  echo

  echo -e "${CYAN}Пример проверки ресурсов контейнера:${NC}"
  echo "docker stats $CONTAINER_NAME"
  echo

  echo -e "${GREEN}✓ Команды сгенерированы. Копируй нужное и запускай вручную.${NC}"
  echo
  pause
}

#########################
#  Режим 3: Автоматическая диагностика
#########################
mode_auto() {
  print_header
  echo -e "${YELLOW}▶ РЕЖИМ 3: Автоматическая проверка ноды${NC}"
  echo

  load_env >/dev/null 2>&1 || true

  local node_pk="${NODE_PUBKEY:-}"
  local cb_pk="${CALLBACK_PUBKEY:-}"
  local rpc="${RPC_URL:-https://api.devnet.solana.com}"

  ######################
  # Проверка бинарей
  ######################
  echo -e "${CYAN}Проверка необходимых команд...${NC}"

  local ok=1
  check_cmd solana || ok=0
  check_cmd docker || ok=0
  check_cmd curl || ok=0

  if [[ $ok -eq 0 ]]; then
    echo -e "${RED}❌ Не все необходимые команды доступны. Проверьте установки.${NC}"
    echo
  else
    echo -e "${GREEN}✓ Все основные бинарники доступны.${NC}"
  fi
  echo

  ######################
  # Проверка RPC Solana
  ######################
  echo -e "${CYAN}Проверка доступности RPC: ${rpc}${NC}"
  if check_cmd curl; then
    local rpc_resp
    rpc_resp=$(curl -s -m 10 -X POST "$rpc" \
      -H "Content-Type: application/json" \
      -d '{"jsonrpc":"2.0","id":1,"method":"getHealth"}' || true)
    if [[ -n "$rpc_resp" ]]; then
      echo -e "${GREEN}✓ RPC ответило:${NC} $rpc_resp"
    else
      echo -e "${RED}⚠ Нет ответа от RPC (timeout или ошибка).${NC}"
    fi
  fi
  echo

  ######################
  # Инфо по Solana аккаунтам
  ######################
  if [[ -n "$node_pk" ]]; then
    echo -e "${CYAN}Проверка Solana аккаунта ноды:${NC} ${node_pk}"
    if check_cmd solana; then
      solana account "$node_pk" 2>&1 || echo -e "${RED}⚠ Ошибка при solana account для ноды${NC}"
      echo
      echo -e "${CYAN}Баланс ноды:${NC}"
      solana balance "$node_pk" 2>&1 || echo -e "${RED}⚠ Ошибка при solana balance для ноды${NC}"
    else
      echo -e "${RED}⚠ Команда solana недоступна, пропускаю проверку аккаунта ноды.${NC}"
    fi
  else
    echo -e "${RED}⚠ NODE_PUBKEY не задан в .env, пропускаю проверку аккаунта ноды.${NC}"
  fi
  echo

  if [[ -n "$cb_pk" ]]; then
    echo -e "${CYAN}Проверка Solana аккаунта callback:${NC} ${cb_pk}"
    if check_cmd solana; then
      solana account "$cb_pk" 2>&1 || echo -e "${RED}⚠ Ошибка при solana account для callback${NC}"
      echo
      echo -e "${CYAN}Баланс callback:${NC}"
      solana balance "$cb_pk" 2>&1 || echo -e "${RED}⚠ Ошибка при solana balance для callback${NC}"
    else
      echo -e "${RED}⚠ Команда solana недоступна, пропускаю проверку аккаунта callback.${NC}"
    fi
  else
    echo -e "${RED}⚠ CALLBACK_PUBKEY не задан в .env, пропускаю проверку аккаунта callback.${NC}"
  fi
  echo

  ######################
  # Проверка Docker контейнера
  ######################
  echo -e "${CYAN}Проверка Docker контейнера ${CONTAINER_NAME}...${NC}"
  if check_cmd docker; then
    if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
      echo -e "${GREEN}✓ Контейнер ${CONTAINER_NAME} запущен.${NC}"
      echo
      echo -e "${CYAN}Последние 20 строк логов контейнера:${NC}"
      docker logs "$CONTAINER_NAME" --tail 20 2>&1 || echo -e "${RED}⚠ Не удалось прочитать логи${NC}"
    else
      echo -e "${RED}❌ Контейнер ${CONTAINER_NAME} не найден или не запущен.${NC}"
    fi
  else
    echo -e "${RED}⚠ Docker недоступен, пропускаю проверку контейнера.${NC}"
  fi
  echo

  ######################
  # Проверка порта
  ######################
  echo -e "${CYAN}Проверка, слушается ли порт ${EXTERNAL_PORT}...${NC}"
  if check_cmd ss; then
    if ss -tulpn 2>/dev/null | grep -q ":${EXTERNAL_PORT} "; then
      echo -e "${GREEN}✓ Порт ${EXTERNAL_PORT} прослушивается.${NC}"
    else
      echo -e "${RED}⚠ Порт ${EXTERNAL_PORT} не найден в списке слушающих.${NC}"
    fi
  else
    echo -e "${RED}⚠ Команда ss недоступна, пропускаю проверку порта.${NC}"
  fi
  echo

  ######################
  # Финальный вывод
  ######################
  echo -e "${GREEN}✔ Автоматическая диагностика завершена.${NC}"
  echo -e "Проверьте вывод выше для деталей по ноде, балансам и статусу контейнера."
  echo
  pause
}

#########################
#  Главное меню
#########################
main_menu() {
  while true; do
    print_header
    echo -e "${YELLOW}Выберите режим:${NC}"
    echo
    echo -e "  ${CYAN}1${NC} - Показать ключи, адреса и параметры ноды (без структуры папки и портов)"
    echo -e "  ${CYAN}2${NC} - Сгенерировать готовые команды с автоподстановкой (без выполнения)"
    echo -e "  ${CYAN}3${NC} - Автоматическая проверка ноды (статус, балансы, порты, логи)"
    echo -e "  ${CYAN}0${NC} - Выход"
    echo
    read -rp "Ваш выбор: " choice

    case "$choice" in
      1) mode_info ;;
      2) mode_commands ;;
      3) mode_auto ;;
      0)
        echo -e "${GREEN}Выход...${NC}"
        exit 0
        ;;
      *)
        echo -e "${RED}Неверный выбор, попробуйте снова.${NC}"
        sleep 1
        ;;
    esac
  done
}

#########################
#  Старт
#########################
main_menu
