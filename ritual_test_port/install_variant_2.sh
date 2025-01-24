#!/bin/bash

# Кольори для виводу
YELLOW='\e[0;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Функція для запиту параметрів у користувача
request_param() {
    read -p "$1: " param
    echo $param
}

# Введення даних від користувача
echo -e "${YELLOW}Пожалуйста, введите следующие параметры для настройки ноды:${NC}"
RPC_URL=$(request_param "Введите RPC URL")
PRIVATE_KEY=$(request_param "Введите ваш приватный ключ (начинающийся с 0x)")

# Перевірка приватного ключа
if [[ "$PRIVATE_KEY" == 0x* ]]; then
    echo -e "${GREEN}Приватный ключ введен корректно!${NC}"
else
    echo -e "${RED}Приватный ключ должен начинаться с 0x!${NC}"
    exit 1
fi

# Змінні конфігурації
REGISTRY_ADDRESS="0x3B1554f346DFe5c482Bb4BA31b880c1C18412170"
IMAGE="ritualnetwork/infernet-node:1.4.0"
DEPLOY_JSON="$HOME/infernet-container-starter/deploy/config.json"
CONTAINER_JSON="$HOME/infernet-container-starter/projects/hello-world/container/config.json"

# Функції установки
update() {
    echo -e "${YELLOW}Обновление пакетов...${NC}"
    sudo apt update -y && sudo apt upgrade -y
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Пакеты успешно обновлены!${NC}"
    else
        echo -e "${RED}Ошибка при обновлении пакетов!${NC}"
        exit 1
    fi
}

install_script() {
    local url=$1
    local name=$2
    echo -e "${YELLOW}Установка ${name}...${NC}"
    bash <(curl -s $url)
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}${name} успешно установлен!${NC}"
    else
        echo -e "${RED}Ошибка при установке ${name}!${NC}"
        exit 1
    fi
}

install_docker() {
    echo -e "${YELLOW}Установка Docker...${NC}"
    bash <(curl -s https://raw.githubusercontent.com/NodEligible/programs/refs/heads/main/docker.sh)
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Docker успешно установлен!${NC}"
    else
        echo -e "${RED}Ошибка при установке Docker!${NC}"
        exit 1
    fi
}

# Встановлення необхідних компонентів
update
install_script "https://raw.githubusercontent.com/NodEligible/programs/refs/heads/main/main.sh" "Main"
install_script "https://raw.githubusercontent.com/NodEligible/programs/refs/heads/main/ufw.sh" "UFW"
install_docker

# Клонування репозиторію
echo -e "${YELLOW}Клонирование репозитория...${NC}"
git clone https://github.com/ritual-net/infernet-container-starter $HOME/infernet-container-starter
if [ $? -eq 0 ]; then
    echo -e "${GREEN}Репозиторий успешно клонирован!${NC}"
else
    echo -e "${RED}Ошибка при клонировании репозитория!${NC}"
    exit 1
fi

# Налаштування конфігурацій
configure_json() {
    local file=$1
    echo -e "${YELLOW}Настройка файла $file...${NC}"
    sed -i 's|"rpc_url": "[^"]*"|"rpc_url": "'"$RPC_URL"'"|' "$file"
    sed -i 's|"private_key": "[^"]*"|"private_key": "'"$PRIVATE_KEY"'"|' "$file"
    sed -i 's|"registry_address": "[^"]*"|"registry_address": "'"$REGISTRY_ADDRESS"'"|' "$file"
    sed -i 's|"sleep": .*|"sleep": 3,|' "$file"
    sed -i 's|"batch_size": .*|"batch_size": 800,|' "$file"
    sed -i 's|"trail_head_blocks": .*|"trail_head_blocks": 3,|' "$file"
    sed -i 's|"sync_period": .*|"sync_period": 30|' "$file"
    sed -i 's|"starting_sub_id": .*|"starting_sub_id": 160000,|' "$file"
}

configure_json "$DEPLOY_JSON"
configure_json "$CONTAINER_JSON"

# Конфігурація Docker
echo -e "${YELLOW}Настройка Docker Compose...${NC}"
sed -i 's|ritualnetwork/infernet-node:.*|ritualnetwork/infernet-node:1.4.0|' $HOME/infernet-container-starter/deploy/docker-compose.yaml
sed -i 's|0.0.0.0:4000:4000|0.0.0.0:4321:4000|' $HOME/infernet-container-starter/deploy/docker-compose.yaml
sed -i 's|8545:3000|8845:3000|' $HOME/infernet-container-starter/deploy/docker-compose.yaml
sed -i 's|container_name: infernet-anvil|container_name: infernet-anvil\n    restart: on-failure|' $HOME/infernet-container-starter/deploy/docker-compose.yaml

docker compose -f $HOME/infernet-container-starter/deploy/docker-compose.yaml up -d

# Встановлення Foundry
echo -e "${YELLOW}Установка Foundry...${NC}"
curl -L https://foundry.paradigm.xyz | bash
source ~/.bashrc
foundryup

# Установка залежностей
echo -e "${YELLOW}Установка зависимостей...${NC}"
cd $HOME/infernet-container-starter/projects/hello-world/contracts/lib/
forge install foundry-rs/forge-std
forge install ritual-net/infernet-sdk

# Деплой контракту
echo -e "${YELLOW}Деплой контракта...${NC}"
cd $HOME/infernet-container-starter
project=hello-world make deploy-contracts >> logs.txt
CONTRACT_ADDRESS=$(grep "Deployed SaysHello" logs.txt | awk '{print $NF}')
rm -rf logs.txt

if [ -z "$CONTRACT_ADDRESS" ]; then
    echo -e "${RED}Ошибка: не удалось получить адрес контракта.${NC}"
    exit 1
fi

echo -e "${GREEN}Адрес контракта: $CONTRACT_ADDRESS${NC}"

# Виклик контракту
echo -e "${YELLOW}Вызов контракта...${NC}"
project=hello-world make call-contract

# Завершення
echo -e "${GREEN}Установка завершена успешно!${NC}"
