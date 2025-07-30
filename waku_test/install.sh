#!/bin/bash

logo() {
curl -s https://raw.githubusercontent.com/NodEligible/programs/refs/heads/main/display_logo.sh | bash
}

YELLOW='\e[0;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[38;5;81m'
NC='\033[0m' 

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
  if [ -z "$WAKU_PUBLIC_KEY" ]; then
    echo -e "${BLUE}Введите ваш адрес ETH (0x...)${NC}"
    read -r -p "Адрес: " WAKU_PUBLIC_KEY
    export WAKU_PUBLIC_KEY
  fi
}

read_private_key() {
  if [ -z "$WAKU_PRIVATE_KEY" ]; then
    echo -e "${BLUE}Введите приватный ключ (0x...)${NC}"
    read -r -p "Приватный ключ: " WAKU_PRIVATE_KEY
    export WAKU_PRIVATE_KEY
  fi
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

echo "PUBLIC: $WAKU_PUBLIC_KEY"
echo "PRIVATE: $WAKU_PRIVATE_KEY"
echo "PASS: $WAKU_PASS"

setup_env() {
  # Иницифализируем
  STORAGE_SIZE="50GB"
  POSTGRES_SHM="5g"
  ENV_FILE=$HOME/nwaku-compose/.env
  KEYSTORE_PATH="$HOME/nwaku-compose/keystore/keystore.json"
  
  cd nwaku-compose
  cp .env.example .env

  if grep -q "^STORAGE_SIZE=" "$ENV_FILE"; then
      sed -i "s/^STORAGE_SIZE=.*/STORAGE_SIZE=$STORAGE_SIZE/" "$ENV_FILE"
  else
      echo "STORAGE_SIZE=$STORAGE_SIZE" >> "$ENV_FILE"
  fi

  if grep -q "^POSTGRES_SHM=" "$ENV_FILE"; then
      sed -i "s/^POSTGRES_SHM=.*/POSTGRES_SHM=$POSTGRES_SHM/" "$ENV_FILE"
  else
      echo "POSTGRES_SHM=$POSTGRES_SHM" >> "$ENV_FILE"
  fi

  sed -i "s|RLN_RELAY_ETH_CLIENT_ADDRESS=.*|RLN_RELAY_ETH_CLIENT_ADDRESS=$RPC_URL|" $HOME/nwaku-compose/.env
  sed -i "s|ETH_TESTNET_ACCOUNT=.*|ETH_TESTNET_ACCOUNT=$WAKU_PUBLIC_KEY|" $HOME/nwaku-compose/.env
  sed -i "s|ETH_TESTNET_KEY=.*|ETH_TESTNET_KEY=$WAKU_PRIVATE_KEY|" $HOME/nwaku-compose/.env
  sed -i "s|RLN_RELAY_CRED_PASSWORD=.*|RLN_RELAY_CRED_PASSWORD=$WAKU_PASS|" $HOME/nwaku-compose/.env
  sed -i "s|NWAKU_IMAGE=.*|NWAKU_IMAGE=wakuorg/nwaku:v0.36.0|" $HOME/nwaku-compose/.env


  # Меняем стандартный порт графаны
  sed -i '/^version: "3.7"$/d' $HOME/nwaku-compose/docker-compose.yml
  sed -i 's/0\.0\.0\.0:3000:3000/0.0.0.0:3004:3000/g' $HOME/nwaku-compose/docker-compose.yml
  sed -i 's/127\.0\.0\.1:4000:4000/0.0.0.0:4044:4000/g' $HOME/nwaku-compose/docker-compose.yml
  sed -i 's|127.0.0.1:8003:8003|127.0.0.1:8333:8003|' $HOME/nwaku-compose/docker-compose.yml
  sed -i 's/:5432:5432/:5444:5432/g' $HOME/nwaku-compose/docker-compose.yml
  sed -i 's/80:80/8081:80/g' $HOME/nwaku-compose/docker-compose.yml

  bash $HOME/nwaku-compose/register_rln.sh
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
  install_tools
  install_docker
  install_ufw
  read_sepolia_rpc
  read_public_key
  read_private_key
  read_pass
  git_clone
  setup_env
  docker_compose_up
  echo_info
