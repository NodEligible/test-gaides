#!/bin/bash

curl -s https://raw.githubusercontent.com/NodEligible/programs/refs/heads/main/display_logo.sh | bash

YELLOW='\e[0;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

  echo -e "${YELLOW}Установка Main...${NC}"
  bash <(curl -s https://raw.githubusercontent.com/NodEligible/programs/refs/heads/main/main.sh)
  if [ $? -eq 0 ]; then
      echo -e "${GREEN}Main успешно установлен!${NC}"
  else
      echo -e "${RED}Ошибка при установке Main!${NC}"
  fi

    echo -e "${YELLOW}Установка Ufw...${NC}" 
  bash <(curl -s https://raw.githubusercontent.com/NodEligible/programs/refs/heads/main/ufw.sh)
  if [ $? -eq 0 ]; then
      echo -e "${GREEN}Ufw успешно установлено!${NC}"
  else
      echo -e "${RED}Ошибка при установке Ufw!${NC}"
  fi

FOLDER="rl-swarm"

if [ -d "$FOLDER" ]; then
    echo -e "${RED}Ошибка: Папка '$FOLDER' уже существует. Удалите и перезапустите скрипт.${NC}" >&2
    exit 1
fi

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    echo -e "${YELLOW}Node.js не установлена. Устанавливаем...${NC}"
    curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
    sudo apt install -y nodejs
fi

# Get Node.js version
NODE_VERSION=$(node -v 2>/dev/null | cut -d 'v' -f 2)

# Check if the version is lower than 4.0.0
if [[ -n "$NODE_VERSION" && $(echo -e "$NODE_VERSION\n18.0.0" | sort -V | head -n1) == "$NODE_VERSION" ]]; then
    echo -e "${RED}Ошибка: Node.js version is lower than 18.0.0 ($NODE_VERSION). Обновите вручную.${NC}"
    exit 1
fi

echo -e "${GREEN}Node.js версия $NODE_VERSION. Продолжаем...${NC}"

#preinstall yarn, so its properly registered in ~/profile
if ! command -v yarn >/dev/null 2>&1; then
      echo -e "${YELLOW}Yarn не установлен. Устанавливаем...${NC}"
      curl -o- -L https://yarnpkg.com/install.sh 2>/dev/null | sh >/dev/null 2>&1
      echo 'export PATH="$HOME/.yarn/bin:$HOME/.config/yarn/global/node_modules/.bin:$PATH"' >> ~/.profile
      source ~/.profile
fi

echo -e "${YELLOW}Клонируем GIT проекта...${NC}"
REPO_URL="https://github.com/gensyn-ai/rl-swarm.git"
git clone "$REPO_URL" &>/dev/null
cd rl-swarm || { echo -e "${RED}Не удалось войти в директорию rl-swarm${NC}"; exit 1; }
python3 -m venv .venv
source .venv/bin/activate


ROOT=$PWD

export PUB_MULTI_ADDRS
export PEER_MULTI_ADDRS
export HOST_MULTI_ADDRS
export IDENTITY_PATH
export CONNECT_TO_TESTNET
export ORG_ID
export HF_HUB_DOWNLOAD_TIMEOUT=120  # 2 minutes

#Check if public multi-address is given else set to default
DEFAULT_PUB_MULTI_ADDRS=""
PUB_MULTI_ADDRS=${PUB_MULTI_ADDRS:-$DEFAULT_PUB_MULTI_ADDRS}

#Check if peer multi-address is given else set to default
DEFAULT_PEER_MULTI_ADDRS="/ip4/38.101.215.13/tcp/30002/p2p/QmQ2gEXoPJg6iMBSUFWGzAabS2VhnzuS782Y637hGjfsRJ" # gensyn coordinator node
PEER_MULTI_ADDRS=${PEER_MULTI_ADDRS:-$DEFAULT_PEER_MULTI_ADDRS}

#Check if host multi-address is given else set to default
DEFAULT_HOST_MULTI_ADDRS="/ip4/0.0.0.0/tcp/38331"
HOST_MULTI_ADDRS=${HOST_MULTI_ADDRS:-$DEFAULT_HOST_MULTI_ADDRS}

# Path to an RSA private key. If this path does not exist, a new key pair will be created.
# Remove this file if you want a new PeerID.
DEFAULT_IDENTITY_PATH="$ROOT"/swarm.pem
IDENTITY_PATH=${IDENTITY_PATH:-$DEFAULT_IDENTITY_PATH}

# rl-swarm code
    # run modal_login server
    cd modal-login

    echo -e "${YELLOW}Запускаем yarn install просто ждите...${NC}"
    yarn install &>/dev/null
    yarn upgrade &>/dev/null
    yarn add next@latest react react-dom &>/dev/null
    yarn add viem@latest &>/dev/null
    yarn dev > /dev/null 2>&1 & # Run in background and suppress output
   echo -e "${GREEN}yarn install запущен${NC}"

    echo -e "${YELLOW}Пожалуйста, войдите в систему, чтобы создать кошелек сервера Ethereum.${NC}"
    SERVER_PID=$!  # Store the process ID
    sleep 5
    #open http://localhost:3000
    cd ..

    # Wait until modal-login/temp-data/userData.json exists
    while [ ! -f "modal-login/temp-data/userData.json" ]; do
        echo -e "${YELLOW}Ждем авторизацию (localhost:3000)...${NC}"
        sleep 5  # Wait for 5 seconds before checking again
    done
    echo -e "${GREEN}Авторизировано.${NC}"

    ORG_ID=$(awk 'BEGIN { FS = "\"" } !/^[ \t]*[{}]/ { print $(NF - 1); exit }' modal-login/temp-data/userData.json)
    echo "ORG_ID set to: $ORG_ID"

    # Function to clean up the server process
    cleanup() {
        echo "Shutting down server..."
        kill $SERVER_PID
        rm -r modal-login/temp-data/*.json
        exit 0
    }

    # Set up trap to catch Ctrl+C and call cleanup
    trap cleanup INT

#lets go!
echo -e "${YELLOW}Ставим python dependencies просто ждите...${NC}"
pip install -r "$ROOT"/requirements-hivemind.txt > /dev/null
pip install -r "$ROOT"/requirements.txt > /dev/null

if ! which nvidia-smi; then
   #You don't have a NVIDIA GPU
   CONFIG_PATH="$ROOT/hivemind_exp/configs/mac/grpo-qwen-2.5-0.5b-deepseek-r1.yaml"
elif [ -n "$CPU_ONLY" ]; then
   # ... or we don't want to use it
   CONFIG_PATH="$ROOT/hivemind_exp/configs/mac/grpo-qwen-2.5-0.5b-deepseek-r1.yaml"
else
   #NVIDIA GPU found
   pip install -r "$ROOT"/requirements_gpu.txt > /dev/null
   CONFIG_PATH="$ROOT/hivemind_exp/configs/gpu/grpo-qwen-2.5-0.5b-deepseek-r1.yaml"
fi

echo -e "${GREEN}Готово!${NC}"

if [ -n "${HF_TOKEN}" ]; then # Check if HF_TOKEN is already set and use if so. Else give user a prompt to choose.
   HUGGINGFACE_ACCESS_TOKEN=${HF_TOKEN}
else
   read -p "Хотите ли вы перенести модели, которых вы обучаете в RL-рое, в Hugging Face Hub? [y/N] " yn
   yn=${yn:-N}  # Default to "N" if the user presses Enter
   case $yn in
      [Yy]* ) read -p "Введите свой токен доступа Hugging Face: " HUGGINGFACE_ACCESS_TOKEN;;
      [Nn]* ) HUGGINGFACE_ACCESS_TOKEN="None";;
      * ) echo " Ответ не был дан, поэтому НИ ОДНА модель не будет отправлена ​​в Hugging Face Hub." && HUGGINGFACE_ACCESS_TOKEN="None";;
   esac
fi

echo -e "${GREEN}Удачи в рое!${NC}"
# end official script part

# делаем скрипт для будущего systemd сервиса
echo -e "${YELLOW}Создаем скрипт для systemd сервиса...${NC}"
OUTPUT_SCRIPT="$ROOT/gensyn_service.sh"

if [ -n "$ORG_ID" ]; then
cat <<EOF > "$OUTPUT_SCRIPT"
#!/bin/bash

# Set working directory
FOLDER="$ROOT"
cd "\$FOLDER" || exit 1

source /root/.profile
source .venv/bin/activate

cd modal-login
yarn install
yarn dev > /dev/null 2>&1 &
cd ..

# Set parameters
HUGGINGFACE_ACCESS_TOKEN="$HUGGINGFACE_ACCESS_TOKEN"
IDENTITY_PATH="$IDENTITY_PATH"
ORG_ID="$ORG_ID"
CONFIG_PATH="$CONFIG_PATH"

    python -m hivemind_exp.gsm8k.train_single_gpu \
        --hf_token "$HUGGINGFACE_ACCESS_TOKEN" \
        --identity_path "$IDENTITY_PATH" \
        --modal_org_id "$ORG_ID" \
        --config "$CONFIG_PATH"

wait
EOF
else
cat <<EOF > "$OUTPUT_SCRIPT"
#!/bin/bash

# Set working directory
FOLDER="$ROOT"
cd "\$FOLDER" || exit 1

source .venv/bin/activate

if [ ! -f "$ROOT/modal-login//temp-data/userApiKey.json" ]; then
    cp "$ROOT/userApiKey_backup.json" "$ROOT/modal-login//temp-data/userApiKey.json"
fi

if [ ! -f "$ROOT/modal-login//temp-data/userData.json" ]; then
    cp "$ROOT/userData_backup.json" "$ROOT/modal-login//temp-data/userData.json"
fi


# Set parameters
HUGGINGFACE_ACCESS_TOKEN="$HUGGINGFACE_ACCESS_TOKEN"
IDENTITY_PATH="$IDENTITY_PATH"
CONFIG_PATH="$CONFIG_PATH"
PUB_MULTI_ADDRS="$PUB_MULTI_ADDRS"
PEER_MULTI_ADDRS="$PEER_MULTI_ADDRS"
HOST_MULTI_ADDRS="$HOST_MULTI_ADDRS"


python -m hivemind_exp.gsm8k.train_single_gpu \
        --hf_token "$HUGGINGFACE_ACCESS_TOKEN" \
        --identity_path "$IDENTITY_PATH" \
        --public_maddr "$PUB_MULTI_ADDRS" \
        --initial_peers "$PEER_MULTI_ADDRS"\
        --host_maddr "$HOST_MULTI_ADDRS" \
        --config "$CONFIG_PATH"

wait
EOF
fi
chmod +x "$OUTPUT_SCRIPT"
echo -e "${GREEN}Скрипт для systemd сервиса создан: $OUTPUT_SCRIPT${NC}"

# создаем сам сервис в системе
SERVICE_NAME="gensyn.service"
SERVICE_FILE="/etc/systemd/system/$SERVICE_NAME"
LOG_FILE="/var/log/gensyn.log"
ERROR_LOG_FILE="/var/log/gensyn_error.log"

# удаляем сервис если уже стоит
if systemctl list-units --type=service --all | grep -q "$SERVICE_NAME"; then
    sudo systemctl stop "$SERVICE_NAME"
    sudo systemctl disable "$SERVICE_NAME"
    if [ -f "$SERVICE_FILE" ]; then
        sudo rm "$SERVICE_FILE"
    fi
    > "$ERROR_LOG_FILE"
    sudo systemctl daemon-reload
    echo "Существующий $SERVICE_NAME удален."
fi


# Create the systemd service file
cat <<EOF | sudo tee "$SERVICE_FILE" > /dev/null
[Unit]
Description=Gensyn Service
After=network.target

[Service]
User=root
WorkingDirectory=$ROOT
ExecStart=/bin/bash $ROOT/gensyn_service.sh
Restart=always
RestartSec=5
StandardOutput=append:$LOG_FILE
StandardError=append:$ERROR_LOG_FILE

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd, enable and start the service
sudo systemctl daemon-reload
sudo systemctl enable gensyn.service
sudo systemctl start gensyn.service

sleep 10
cp "$ROOT/modal-login/temp-data/userApiKey.json" "$ROOT/userApiKey_backup.json"
cp "$ROOT/modal-login/temp-data/userData.json" "$ROOT/userData_backup.json"

echo -e "${GREEN}Установка завершена.${NC}"
