#!/bin/bash

logo() {
curl -s https://raw.githubusercontent.com/NodEligible/programs/refs/heads/main/display_logo.sh | bash
}

YELLOW='\e[0;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[38;5;81m'
NC='\033[0m' 

delate_waku() {
docker compose -f $HOME/nwaku-compose/docker-compose.yml down -v
rm -rf $HOME/nwaku-compose
docker rm -f  nwaku-compose-nwaku-1

docker rmi -f prom/prometheus:latest
docker rmi -f grafana/grafana:latest
docker rmi -f wakuorg/nwaku:v0.36.0
docker rmi -f alrevuelta/waku-frontend:aad9628
docker rmi -f postgres:15.4-alpine3.18
docker rmi -f quay.io/prometheuscommunity/postgres-exporter:v0.12.0
}

install_tools() {
  echo -e "${YELLOW}Установка Tools...${NC}" 
  sudo apt update && sudo apt install mc wget htop jq git -y
  if [ $? -eq 0 ]; then
      echo -e "${GREEN}Tools успешно установлено!${NC}"
  else
      echo -e "${RED}Ошибка при установке Tools!${NC}"
  fi
}

install_docker() {
  echo -e "${YELLOW}Установка Docker...${NC}"
  bash <(curl -s https://raw.githubusercontent.com/NodEligible/programs/refs/heads/main/docker.sh)
  if [ $? -eq 0 ]; then
      echo -e "${GREEN}Docker успешно установлено!${NC}"
  else
      echo -e "${RED}Ошибка при установке Docker!${NC}"
  fi
}

install_ufw() {
  echo -e "${YELLOW}Установка Ufw...${NC}" 
  bash <(curl -s https://raw.githubusercontent.com/NodEligible/programs/refs/heads/main/ufw.sh)
  if [ $? -eq 0 ]; then
      echo -e "${GREEN}Ufw успешно установлено!${NC}"
  else
      echo -e "${RED}Ошибка при установке Ufw!${NC}"
  fi
}

read_sepolia_rpc() {
  if [ -z "$RPC_URL" ]; then
    echo -e "${BLUE}Введите ваш RPC Linea Sepolia https url.${NC}"
    read -r -p "RPC: " RPC_URL
    export RPC_URL
  fi
}

read_public_key() {
  while true; do
    echo -e "${BLUE}Введите ваш адрес ETH (начинается с 0x)${NC}"
    read -r -p "Адрес: " WAKU_PUBLIC_KEY

    if [[ "$WAKU_PUBLIC_KEY" =~ ^0x[a-fA-F0-9]{40}$ ]]; then
      export WAKU_PUBLIC_KEY
      break
    else
      echo -e "${RED}Неверный формат адреса. Он должен начинаться с 0x и быть 42 символа (включая 0x).${NC}"
    fi
  done
}

read_private_key() {
  while true; do
    echo -e "${BLUE}Введите приватный ключ от ETH кошелька (без 0x)${NC}"
    read -r -p "Приватный ключ: " WAKU_PRIVATE_KEY

    if [[ "$WAKU_PRIVATE_KEY" =~ ^[a-fA-F0-9]{64}$ ]]; then
      export WAKU_PRIVATE_KEY
      break
    else
      echo -e "${RED}Неверный формат приватного ключа. Он должен быть 64 символа без префикса 0x.${NC}"
    fi
  done
}

read_pass() {
  if [ -z "$WAKU_PASS" ]; then
    echo -e "${BLUE}Введите пароль из пункта 4 гайда${NC}"
    read -r -p "Пароль: " WAKU_PASS
    export WAKU_PASS
  fi
}

git_clone() {
  git clone https://github.com/waku-org/nwaku-compose
}

fix_register_rln_path() {
  local file="$HOME/nwaku-compose/register_rln.sh"
  if [ -f "$file" ]; then
    sed -i '/if test -f .env; then/,/fi/ c\
if test -f /root/nwaku-compose/.env; then\n\
  echo "Using .env file from absolute path"\n\
  . "/root/nwaku-compose/.env"\n\
fi' "$file"
    echo "✅ Путь к .env обновлен в register_rln.sh"
  else
    echo "❌ Файл register_rln.sh не найдено"
  fi
}


setup_env() {
  STORAGE_SIZE="50GB"
  POSTGRES_SHM="5g"
  ENV_FILE="$HOME/nwaku-compose/.env"
  KEYSTORE_PATH="$HOME/nwaku-compose/keystore/keystore.json"

  # Створюємо порожній .env
  echo "# Auto-generated .env" > "$ENV_FILE"

  # Функція оновлення або додавання змінної
  update_env_var() {
    local key="$1"
    local value="$2"
    if grep -q "^$key=" "$ENV_FILE"; then
      sed -i "s|^$key=.*|$key=$value|" "$ENV_FILE"
    else
      echo "$key=$value" >> "$ENV_FILE"
    fi
  }

  # Заповнюємо значення
  update_env_var "NWAKU_IMAGE" "wakuorg/nwaku:v0.36.0"
  update_env_var "STORAGE_SIZE" "$STORAGE_SIZE"
  update_env_var "POSTGRES_SHM" "$POSTGRES_SHM"
  update_env_var "EXTRA_ARGS" ""
  update_env_var "DOMAIN" ""
  update_env_var "NODEKEY" ""

  update_env_var "RLN_RELAY_ETH_CLIENT_ADDRESS" "$RPC_URL"
  update_env_var "RLN_RELAY_CONTRACT_ADDRESS" "0xB9cd878C90E49F797B4431fBF4fb333108CB90e6"
  update_env_var "TOKEN_CONTRACT_ADDRESS" "0x185A0015aC462a0aECb81beCc0497b649a64B9ea"
  update_env_var "ETH_TESTNET_ACCOUNT" "$WAKU_PUBLIC_KEY"
  update_env_var "ETH_TESTNET_KEY" "$WAKU_PRIVATE_KEY"
  update_env_var "RLN_RELAY_CRED_PASSWORD" "$WAKU_PASS"
  update_env_var "RLN_RELAY_CRED_PATH" "$KEYSTORE_PATH"

  # Заміни в docker-compose.yml (абсолютні шляхи)
  sed -i '/^version: "3.7"$/d' "$HOME/nwaku-compose/docker-compose.yml"
  sed -i 's/0\.0\.0\.0:3000:3000/0.0.0.0:3004:3000/g' "$HOME/nwaku-compose/docker-compose.yml"
  sed -i 's/127\.0\.0\.1:4000:4000/0.0.0.0:4044:4000/g' "$HOME/nwaku-compose/docker-compose.yml"
  sed -i 's|127.0.0.1:8003:8003|127.0.0.1:8333:8003|' "$HOME/nwaku-compose/docker-compose.yml"
  sed -i 's/:5432:5432/:5444:5432/g' "$HOME/nwaku-compose/docker-compose.yml"
  sed -i 's/80:80/8081:80/g' "$HOME/nwaku-compose/docker-compose.yml"

# Запуск RLN регистрации с проверкой
echo -e "\n🔄 Выполняется регистрация RLN..."
if bash "$HOME/nwaku-compose/register_rln.sh"; then
  echo -e "${GREEN}✅ Тестовый RLN токен успешно заминчен${NC}"
else
  echo -e "${RED}❌ Ошибка при попытке минта RLN токена. Возможно, недостаточно тестового ETH на Linea Sepolia или недоступен RPC.${NC}"
  exit 1
fi
}


docker_compose_up() {
  docker compose -f $HOME/nwaku-compose/docker-compose.yml up -d
}

echo_info() {
  ip_address=$(hostname -I | awk '{print $1}')
  echo -e "${GREEN}Для проверки дашборда графаны, перейдите по ссылке: ${NC}"
  echo -e "${YELLOW}http://$ip_address:3004/d/yns_4vFVk/nwaku-monitoring${NC}"
}

  logo
  delate_waku
  install_tools
  install_docker
  install_ufw
  read_sepolia_rpc
  read_public_key
  read_private_key
  read_pass
  git_clone
  fix_register_rln_path
  setup_env
  docker_compose_up
  echo_info
