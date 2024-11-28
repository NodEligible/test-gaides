#!/bin/bash

# Перевірка, чи передано параметри
if [ "$#" -ne 1 ]; then
    read -p "Введите адрес кошелька для ревардов: " CLAIM_REWARD_ADDRESS
    if [ -z "$CLAIM_REWARD_ADDRESS" ]; then
        echo "Claim reward address cannot be empty. Exiting..."
        exit 1
    fi
else
    CLAIM_REWARD_ADDRESS=$1
fi

# Оновлення системи
sudo apt update && sudo apt upgrade -y

# Перша секція команд: видалення старого каталогу cysic-verifier, створення нового каталогу та завантаження необхідних файлів
rm -rf ~/cysic-verifier
cd ~
mkdir cysic-verifier
curl -L https://github.com/cysic-labs/phase2_libs/releases/download/v1.0.0/verifier_linux > ~/cysic-verifier/verifier
curl -L https://github.com/cysic-labs/phase2_libs/releases/download/v1.0.0/libdarwin_verifier.so > ~/cysic-verifier/libdarwin_verifier.so

# Друга секція команд: створення конфігураційного файлу
cat <<EOF > ~/cysic-verifier/config.yaml
# Not Change
chain:
  endpoint: "grpc-testnet.prover.xyz:80"
  chain_id: "cysicmint_9001-1"
  gas_coin: "CYS"
  gas_price: 10
  claim_reward_address: "$CLAIM_REWARD_ADDRESS"

server:
  cysic_endpoint: "https://api-testnet.prover.xyz"
EOF

# Третя секція команд: налаштування прав виконання
cd ~/cysic-verifier/
chmod +x ~/cysic-verifier/verifier
echo "LD_LIBRARY_PATH=. CHAIN_ID=534352 ./verifier" > ~/cysic-verifier/start.sh
chmod +x ~/cysic-verifier/start.sh

# Створення скрипта управління
cat <<EOF > ~/cysic-verifier/manage_verifier.sh
#!/bin/bash

case \$1 in
    start)
        echo "Starting cysic-verifier..."
        cd ~/cysic-verifier && bash start.sh > ~/cysic-verifier/logs.txt 2>&1 &
        echo "Cysic verifier started. Logs are being saved to ~/cysic-verifier/logs.txt"
        ;;
    stop)
        echo "Stopping cysic-verifier..."
        pkill -f "./verifier"
        echo "Cysic verifier stopped."
        ;;
    status)
        echo "Checking status of cysic-verifier..."
        ps aux | grep "./verifier" | grep -v "grep"
        ;;
    logs)
        echo "Showing logs of cysic-verifier..."
        tail -f ~/cysic-verifier/logs.txt
        ;;
    *)
        echo "Usage: \$0 {start|stop|status|logs}"
        ;;
esac
EOF

# Налаштування прав для скрипта управління
chmod +x ~/cysic-verifier/manage_verifier.sh

echo "Setup complete. Use '~/cysic-verifier/manage_verifier.sh start|stop|status|logs' to manage the verifier."
