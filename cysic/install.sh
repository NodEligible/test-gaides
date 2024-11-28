#!/bin/bash

# Відображення логотипу
curl -s https://raw.githubusercontent.com/NodEligible/programs/refs/heads/main/display_logo.sh | bash

YELLOW='\e[0;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Перевірка, чи передано параметри
if [ "$#" -ne 1 ]; then
    read -p "Введите адрес кошелька для ревардов: " CLAIM_REWARD_ADDRESS
    if [ -z "$CLAIM_REWARD_ADDRESS" ]; then
        echo -e "${RED}Адрес получения вознаграждения не может быть пустым. Выход...${NC}"
        exit 1
    fi
else
    CLAIM_REWARD_ADDRESS=$1
fi

# Перевірка формату адреси (EVM-адреса)
if ! [[ $CLAIM_REWARD_ADDRESS =~ ^0x[a-fA-F0-9]{40}$ ]]; then
    echo -e "${RED}Ошибка: Неверный формат EVM-адреса. Убедитесь, что адрес начинается с 0x и содержит 40 символов.${NC}"
    exit 1
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

# Видалення старих каталогів і створення нових
echo -e "${YELLOW}Удаление старых каталогов и создание новых...${NC}"
rm -rf /root/cysic-verifier
mkdir -p /root/cysic-verifier
if [ $? -ne 0 ]; then
    echo -e "${RED}Ошибка при создании каталога /root/cysic-verifier.${NC}"
    exit 1
fi

# Завантаження необхідних файлів
echo -e "${YELLOW}Загрузка необходимых файлов...${NC}"
curl -L https://github.com/cysic-labs/phase2_libs/releases/download/v1.0.0/verifier_linux > /root/cysic-verifier/verifier
curl -L https://github.com/cysic-labs/phase2_libs/releases/download/v1.0.0/libdarwin_verifier.so > /root/cysic-verifier/libdarwin_verifier.so
if [ ! -f /root/cysic-verifier/verifier ] || [ ! -f /root/cysic-verifier/libdarwin_verifier.so ]; then
    echo -e "${RED}Ошибка: Не удалось загрузить необходимые файлы.${NC}"
    exit 1
fi
chmod +x /root/cysic-verifier/verifier

# Створення конфігураційного файлу
echo -e "${YELLOW}Создание конфигурационного файла...${NC}"
cat <<EOF > /root/cysic-verifier/config.yaml
chain:
  endpoint: "grpc-testnet.prover.xyz:80"
  chain_id: "cysicmint_9001-1"
  gas_coin: "CYS"
  gas_price: 10
  claim_reward_address: "$CLAIM_REWARD_ADDRESS"

server:
  cysic_endpoint: "https://api-testnet.prover.xyz"
EOF

if ! grep -q "claim_reward_address: \"$CLAIM_REWARD_ADDRESS\"" /root/cysic-verifier/config.yaml; then
    echo -e "${RED}Ошибка: Адрес не записан в config.yaml. Проверьте скрипт.${NC}"
    exit 1
fi

# Створення або оновлення start.sh
echo -e "${YELLOW}Создание файла start.sh...${NC}"
cat <<EOF > /root/cysic-verifier/start.sh
#!/bin/bash

# Перевірка, чи існує файл logs.txt
if [ ! -f /root/cysic-verifier/logs.txt ]; then
    touch /root/cysic-verifier/logs.txt
    chmod 644 /root/cysic-verifier/logs.txt
fi

# Запуск verifier
LD_LIBRARY_PATH=. CHAIN_ID=534352 ./verifier >> /root/cysic-verifier/logs.txt 2>&1
EOF
chmod +x /root/cysic-verifier/start.sh

# Створення скрипта управління
echo -e "${YELLOW}Создание файла manage_verifier.sh...${NC}"
cat <<EOF > /root/cysic-verifier/manage_verifier.sh
#!/bin/bash

YELLOW='\e[0;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

case \$1 in
    start)
        echo -e "\${YELLOW}Старт cysic-verifier...\${NC}"
        cd /root/cysic-verifier && bash start.sh
        echo -e "\${GREEN}Cysic verifier запущен.${NC}"
        ;;
    stop)
        echo -e "\${YELLOW}Остановка cysic-verifier...\${NC}"
        pkill -f "./verifier"
        echo -e "\${GREEN}Cysic-verifier остановлен.${NC}"
        ;;
    status)
        echo -e "\${YELLOW}Проверка статуса cysic-verifier...\${NC}"
        ps aux | grep "./verifier" | grep -v "grep"
        ;;
    logs)
        echo -e "\${YELLOW}Проверка логов cysic-verifier...\${NC}"
        tail -f /root/cysic-verifier/logs.txt
        ;;
    restart)
        echo -e "\${YELLOW}Перезапуск cysic-verifier...\${NC}"
        pkill -f "./verifier"
        sleep 2
        cd /root/cysic-verifier && bash start.sh > /root/cysic-verifier/logs.txt 2>&1 &
        echo -e "\${GREEN}Cysic-verifier успешно перезапущен.${NC}"
        ;;
    *)
        echo "Usage: \$0 {start|stop|status|logs|restart}"
        ;;
esac
EOF
chmod +x /root/cysic-verifier/manage_verifier.sh

# Створення сервісного файлу
echo -e "${YELLOW}Создание системного сервиса...${NC}"
cat <<EOF | sudo tee /etc/systemd/system/cysic-verifier.service > /dev/null
[Unit]
Description=Cysic Verifier Node
After=network.target

[Service]
User=root
WorkingDirectory=/root/cysic-verifier
ExecStartPre=/bin/bash -c "touch /root/cysic-verifier/logs.txt && chmod 644 /root/cysic-verifier/logs.txt"
ExecStart=/bin/bash /root/cysic-verifier/start.sh
Restart=always
RestartSec=10
Environment=LD_LIBRARY_PATH=.
Environment=CHAIN_ID=534352

[Install]
WantedBy=multi-user.target
EOF

# Увімкнення сервісу
echo -e "${YELLOW}Запуск системного сервиса...${NC}"
sudo systemctl enable cysic-verifier.service &>/dev/null
sudo systemctl daemon-reload
sudo systemctl restart cysic-verifier.service

echo -e "${GREEN}Установка ноды Cysic завершена!${NC}"
