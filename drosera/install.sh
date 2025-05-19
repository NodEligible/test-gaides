#!/bin/bash

curl -s https://raw.githubusercontent.com/NodEligible/programs/refs/heads/main/display_logo.sh | bash

YELLOW='\e[0;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[38;5;81m'
NC='\033[0m'

echo -e "${YELLOW}⚙️ Запрос данных пользователя...${NC}"
echo -e "${BLUE}📧 Введите вашу Github почту:${NC}"
read -p "➜ " GITHUB_EMAIL
    
echo -e "${BLUE}👤 Введите ваш Github юзернейм:${NC}"
read -p "➜ " GITHUB_USERNAME

echo -e "${BLUE}🔐 Введите ваш приватный ключ от EVM кошелька без 0x :${NC}"
read -p "➜ " PRIV_KEY

echo -e "${BLUE}📝 Введите адрес вашего EVM кошелька:${NC}"
read -p "➜ " WALLET_ADDRESS

echo -e "${BLUE}📡 Введите свой RPC адрес (или нажмите Enter  https://ethereum-holesky-rpc.publicnode.com):${NC}"
read -p "➜ " new_rpc

echo -e "${BLUE}⛓ Введите адресс вашей существующей Трапы (или нажмите Enter чтобы создать новую):${NC}"
read -p "➜ " existing_trap

# создаем файл .profile если его нет в системе
[ -f /root/.profile ] || touch /root/.profile

# Проверка и открытие портов
echo -e "${YELLOW}Настройка портов...${NC}"
for port in 31313 31314; do
  if ! ufw status | grep -qw "$port"; then
    echo -e "${YELLOW}Открываем порт${NC} $port"
    ufw allow $port
  else
    echo -e "${GREEN}Порт${NC} $port ${GREEN}уже открыт.${NC}"
  fi
done

# Проверка наличия curl и установка, если не установлен
echo -e "${YELLOW}Проверка наличия curl и установка, если не установлен...${NC}" 
if ! command -v curl &> /dev/null; then
    sudo apt update
    sudo apt install curl -y
fi

echo -e "${YELLOW}Установка Ufw...${NC}" 
bash <(curl -s https://raw.githubusercontent.com/NodEligible/programs/refs/heads/main/ufw.sh)
  if [ $? -eq 0 ]; then
      echo -e "${GREEN}Ufw успешно установлено!${NC}"
  else
      echo -e "${RED}Ошибка при установке Ufw!${NC}"
  fi

# Установки зависимостей
echo -e "${YELLOW}Установка необходимых пакетов...${NC}"
sudo apt-get update && sudo apt-get upgrade -y
sudo apt install curl ufw iptables build-essential git wget lz4 jq make gcc nano automake autoconf tmux htop nvme-cli libgbm1 pkg-config libssl-dev libleveldb-dev tar clang bsdmainutils ncdu unzip libleveldb-dev -y

sleep 5

echo -e "${YELLOW}📥 Установка Drosera CLI${NC}"
curl -s -L https://app.drosera.io/install | bash 
echo 'export PATH="$PATH:/root/.drosera/bin"' >> /root/.profile

# Робимо глобальний symlink
ln -sf /root/.drosera/bin/droseraup /usr/local/bin/droseraup
ln -sf /root/.drosera/bin/drosera-operator /usr/local/bin/drosera-operator
ln -sf /root/.drosera/bin/drosera /usr/local/bin/drosera

droseraup

sleep 2

echo -e "${YELLOW}Установка дополнительных инструментов...${NC}"   
curl -L https://foundry.paradigm.xyz | bash
curl -fsSL https://bun.sh/install | bash
  
# Функция для деплоя Trap
echo -e "${YELLOW}Настройка деплой Trap...${NC}"
# Створюємо symlink-и для foundry та bun
ln -sf /root/.foundry/bin/foundryup /usr/local/bin/foundryup
ln -sf /root/.foundry/bin/forge /usr/local/bin/forge
ln -sf /root/.bun/bin/bun /usr/local/bin/bun  

sleep 5

foundryup
    
echo -e "${YELLOW}📂 Создание директории...${NC}"
mkdir drosera
cd drosera
    
git config --global user.email "$GITHUB_EMAIL"
git config --global user.name "$GITHUB_USERNAME"
    
echo -e "${YELLOW}🛠️ Инициализация проекта...${NC}"
forge init -t drosera-network/trap-foundry-template
bun install
forge build

ln -sf /root/.drosera/bin/drosera /usr/local/bin/drosera

# Изменяем трапу если нужно
if [ -n "$existing_trap" ]; then
    echo -e "${GREEN}Вписали $existing_trap в файл drosera.toml${NC}"
    echo "address = \"$existing_trap\"" >> drosera.toml
else
    echo -e "${YELLOW}Созадаем новую трапу.${NC}"
fi

# Меняем Rpc если нужно
config_file=~/drosera/drosera.toml
if [ -n "$new_rpc" ]; then
    sed -i "s|^ethereum_rpc = \".*\"|ethereum_rpc = \"$new_rpc\"|" "$config_file"
else
    new_rpc="https://ethereum-holesky-rpc.publicnode.com"
fi

echo -e "${YELLOW}📁 Настройка конфигурации...${NC}"
TARGET_FILE="$HOME/drosera/drosera.toml"
    
    [ -f "$TARGET_FILE" ] && {
        sed -i '/^private_trap/d' "$TARGET_FILE"
        sed -i '/^whitelist/d' "$TARGET_FILE"
    }
    
echo "private_trap = true" >> "$TARGET_FILE"
echo "whitelist = [\"$WALLET_ADDRESS\"]" >> "$TARGET_FILE"

export DROSERA_PRIVATE_KEY="$PRIV_KEY"
drosera apply 

drosera dryrun

echo -e "${GREEN}Trap настроен!${NC}"

# -------------------------------------------------------------
#delay_minutes=2
#total_seconds=$((delay_minutes * 60))

#echo -e "\n⏳ Ожидание $delay_minutes минут..."

#for ((i=total_seconds; i>0; i--)); do
#    printf "\r⏱️  Осталось: %02d:%02d " $((i/60)) $((i%60))
#    sleep 1
#done

#echo -e "\n✅ Время вышло!"
read -p "➡️  Нажмите Enter, чтобы продолжить..."

# -------------------------------------------------------------
      
    
drosera-operator register --eth-rpc-url https://ethereum-holesky-rpc.publicnode.com --eth-private-key $PRIV_KEY
    
echo -e "${YELLOW}⚙️ Создание сервиса...${NC}"
SERVER_IP=$(curl -s https://api.ipify.org)
    
sudo bash -c "cat <<EOF > /etc/systemd/system/drosera.service
[Unit]
Description=drosera node service
After=network-online.target

[Service]
CPUQuota=150%
User=$USER
Restart=always
RestartSec=15
LimitNOFILE=65535
ExecStart=$(which drosera-operator) node --db-file-path \$HOME/.drosera.db --network-p2p-port 31313 --server-port 31314 \\
    --eth-rpc-url $new_rpc \\
    --eth-backup-rpc-url https://1rpc.io/holesky \\
    --drosera-address 0xea08f7d533C2b9A62F40D5326214f39a8E3A32F8 \\
    --eth-private-key $PRIV_KEY \\
    --listen-address 0.0.0.0 \\
    --network-external-p2p-address $SERVER_IP \\
    --disable-dnr-confirmation true

[Install]
WantedBy=multi-user.target
EOF"
    
sudo systemctl daemon-reload
sudo systemctl enable drosera
sudo systemctl start drosera

echo -e "${GREEN}Установка завершена!${NC}"    
