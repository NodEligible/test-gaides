#!/bin/bash

curl -s https://raw.githubusercontent.com/NodEligible/programs/refs/heads/main/display_logo.sh | bash

YELLOW='\e[0;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Перевірка, чи передано параметри
if [ "$#" -ne 1 ]; then
    read -p "Введите адрес кошелька для ревардов: " CLAIM_REWARD_ADDRESS
    if [ -z "$CLAIM_REWARD_ADDRESS" ]; then
        echo -e "${RED}Ебать ты далбаеб,а адрес кошелка почему не вставил? Выход...${NC}"
        exit 1
    fi
else
    CLAIM_REWARD_ADDRESS=$1
fi

# Оновлення системи
echo -e "${YELLOW}Обновление пакетов...${NC}"
sudo apt update && sudo apt upgrade -y
if [ $? -eq 0 ]; then
    echo -e "${GREEN}Пакеты успешно обновлены!${NC}"
else
    echo -e "${RED}Ошибка при обновлении пакетов!${NC}"
    exit 1
fi

# Видалення старих каталогів, завантаження нових файлів
echo -e "${YELLOW}Удаление старых каталогов и установка новых${NC}"
rm -rf ~/cysic-verifier
mkdir ~/cysic-verifier
curl -L https://github.com/cysic-labs/phase2_libs/releases/download/v1.0.0/verifier_linux > ~/cysic-verifier/verifier
curl -L https://github.com/cysic-labs/phase2_libs/releases/download/v1.0.0/libdarwin_verifier.so > ~/cysic-verifier/libdarwin_verifier.so
if [ $? -eq 0 ]; then
    echo -e "${GREEN}Каталоги созданы успешно!${NC}"
else
    echo -e "${RED}Ошибка при создании каталогов!${NC}"
    exit 1
fi

# Створення конфігураційного файлу
cat <<EOF > ~/cysic-verifier/config.yaml
chain:
  endpoint: "grpc-testnet.prover.xyz:80"
  chain_id: "cysicmint_9001-1"
  gas_coin: "CYS"
  gas_price: 10
  claim_reward_address: "$CLAIM_REWARD_ADDRESS"

server:
  cysic_endpoint: "https://api-testnet.prover.xyz"
EOF

# Налаштування виконуваного файлу та запуск
chmod +x ~/cysic-verifier/verifier
echo "LD_LIBRARY_PATH=. CHAIN_ID=534352 ./verifier" > ~/cysic-verifier/start.sh
chmod +x ~/cysic-verifier/start.sh

# Створення скрипта управління
cat <<EOF > ~/cysic-verifier/manage_verifier.sh
#!/bin/bash

YELLOW='\e[0;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

case \$1 in
    start)
        echo -e "\${YELLOW}Старт cysic-verifier...\${NC}"
        cd ~/cysic-verifier && bash start.sh > ~/cysic-verifier/logs.txt 2>&1 &
        echo -e "\${GREEN}Cysic verifier запущен.\${NC}"
        ;;
    stop)
        echo -e "\${YELLOW}Остановка cysic-verifier...\${NC}"
        pkill -f "./verifier"
        echo -e "\${GREEN}Cysic-verifier остановлен.\${NC}"
        ;;
    status)
        echo -e "\${YELLOW}Проверка статуса cysic-verifier...\${NC}"
        ps aux | grep "./verifier" | grep -v "grep"
        ;;
    logs)
        echo -e "\${YELLOW}Проверка логов cysic-verifier...\${NC}"
        tail -f ~/cysic-verifier/logs.txt
        ;;
    *)
        echo "Usage: \$0 {start|stop|status|logs}"
        ;;
esac
EOF
chmod +x ~/cysic-verifier/manage_verifier.sh

# Створення сервісного файлу
cat <<EOF | sudo tee /etc/systemd/system/cysic-verifier.service > /dev/null
[Unit]
Description=Cysic Verifier Node
After=network.target

[Service]
User=root
WorkingDirectory=/root/cysic-verifier
ExecStart=/bin/bash /root/cysic-verifier/start.sh > ~/cysic-verifier/logs.txt 2>&1 &
Restart=on-failure
RestartSec=10
Environment=LD_LIBRARY_PATH=.
Environment=CHAIN_ID=534352

[Install]
WantedBy=multi-user.target
EOF

# Увімкнення сервісу
sudo systemctl enable cysic-verifier.service &>/dev/null
sudo systemctl daemon-reload
sudo systemctl start cysic-verifier.service

echo -e "${GREEN}Установка ноды Cysic завершена!${NC}"
