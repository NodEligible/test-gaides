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
        echo -e "${RED}Адрес получения вознаграждения не может быть пустым. Выход...${NC}"
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
    fi

# Перша секція команд: видалення старого каталогу cysic-verifier, створення нового каталогу та завантаження необхідних файлів
echo -e "${YELLOW}Удаление старых каталогов и установка новых${NC}"
rm -rf ~/cysic-verifier
cd ~
mkdir cysic-verifier
curl -L https://github.com/cysic-labs/phase2_libs/releases/download/v1.0.0/verifier_linux > ~/cysic-verifier/verifier
curl -L https://github.com/cysic-labs/phase2_libs/releases/download/v1.0.0/libdarwin_verifier.so > ~/cysic-verifier/libdarwin_verifier.so
if [ $? -eq 0 ]; then
        echo -e "${GREEN}Каталоги созданы успешно!${NC}"
    else
        echo -e "${RED}Ошибка при удалении или создании новых каталогов!${NC}"
    fi

# Друга секція команд: створення конфігураційного файлу
cat <<EOF > ~/cysic-verifier/config.yaml
# Not Change
chain:
  # Not Change
  # endpoint: "node-pre.prover.xyz:80"
  endpoint: "grpc-testnet.prover.xyz:80"
  # Not Change
  chain_id: "cysicmint_9001-1"
  # Not Change
  gas_coin: "CYS"
  # Not Change
  gas_price: 10
  # Modify Here：! Your Address (EVM) submitted to claim rewards
claim_reward_address: "$CLAIM_REWARD_ADDRESS"

server:
  # don't modify this
  # cysic_endpoint: "https://api-pre.prover.xyz"
  cysic_endpoint: "https://api-testnet.prover.xyz"
EOF

# Третя секція команд: налаштування прав виконання та запуск verifier
cd ~/cysic-verifier/
chmod +x ~/cysic-verifier/verifier
echo "LD_LIBRARY_PATH=. CHAIN_ID=534352 ./verifier" > ~/cysic-verifier/start.sh
chmod +x ~/cysic-verifier/start.sh

# Створення скрипта управління
cat <<EOF > ~/cysic-verifier/manage_verifier.sh
#!/bin/bash

case \$1 in
    start)
        echo -e "${YELLOW}Старт cysic-verifier...${NC}"
        cd ~/cysic-verifier && bash start.sh > ~/cysic-verifier/logs.txt 2>&1 &
        echo -e "${GREEN}Cysic verifier запущен..${NC}"
        ;;
    stop)
        echo -e "${YELLOW}Остановка cysic-verifier...${NC}"
        pkill -f "./verifier"
        echo -e "${GREEN}Cysic-verifier остановлен${NC}"
        ;;
    status)
        echo -e "${YELLOW}Проверка статуса cysic-verifier...${NC}"
        ps aux | grep "./verifier" | grep -v "grep"
        ;;
    logs)
        echo -e "${YELLOW}Проверка логов cysic-verifier...${NC}"
        tail -f ~/cysic-verifier/logs.txt
        ;;
    *)
        echo "Usage: \$0 {start|stop|status|logs}"
        ;;
esac
EOF

# Налаштування прав для скрипта управління
chmod +x ~/cysic-verifier/manage_verifier.sh

echo -e "${GREEN}Установка ноды Cysic завершена,проверте роботоспособность ноды командами из гайда!${NC}"
