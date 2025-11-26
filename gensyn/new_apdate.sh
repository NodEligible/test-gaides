#!/bin/bash

curl -s https://raw.githubusercontent.com/NodEligible/programs/refs/heads/main/display_logo.sh | bash

YELLOW='\e[0;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}Установка дополнительных програм скрыта, просто ждите...${NC}"

bash <(curl -s https://raw.githubusercontent.com/NodEligible/programs/refs/heads/main/nodejs.sh) &>/dev/null

bash <(curl -s https://raw.githubusercontent.com/NodEligible/programs/refs/heads/main/main.sh) &>/dev/null

bash <(curl -s https://raw.githubusercontent.com/NodEligible/programs/refs/heads/main/ufw.sh) &>/dev/null

apt-get install python3 python3-pip python3-venv python3-dev -y &>/dev/null

# Get the current Python version (major.minor format)
current_version=$(python3 --version 2>&1 | awk '{print $2}')
required_version="3.13"
if [[ "$(echo -e "$current_version\n$required_version" | sort -V | head -n1)" != "$required_version" ]]; then
    echo "Python версия ниже за 3.13. Устанавливаю Python 3.13..."
    sudo apt install -y software-properties-common &>/dev/null
    sudo add-apt-repository -y ppa:deadsnakes/ppa &>/dev/null
    sudo apt update &>/dev/null
    sudo apt install -y python3.13 python3.13-venv python3.13-dev &>/dev/null
    sudo update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.13 13
    #sudo update-alternatives --set python3 /usr/bin/python3.13
    curl -sS https://bootstrap.pypa.io/get-pip.py | sudo python3.13 &>/dev/null
fi

SERVICE_NAME="gensyn.service"
if systemctl list-units --type=service --all | grep -q "$SERVICE_NAME"; then
    echo "Нашли существующий сервис gensyn, останавливаем..."
    sudo systemctl stop "$SERVICE_NAME"
    pkill next-server
fi

FOLDER="rl-swarm"
PEM_FILE="swarm.pem"

if [[ -f "$FOLDER/$PEM_FILE" ]]; then
    echo "Нашли файл $PEM_FILE в $FOLDER. Копирую в /root/..."
    cp "$FOLDER/$PEM_FILE" /root/
    echo "Бекап $PEM_FILE сохранен - /root/$PEM_FILE."
fi

if [ -d "$FOLDER" ]; then
    echo "Удаляем папку $FOLDER перед установкой."
    rm -rf "$FOLDER"
fi

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    echo "Node.js не установлена. Устанавливаем..."
    curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
    sudo apt install -y nodejs
fi

# Get Node.js version
NODE_VERSION=$(node -v 2>/dev/null | cut -d 'v' -f 2)

# Check if the version is lower than 20.18.0
if [[ -n "$NODE_VERSION" && $(echo -e "$NODE_VERSION\n20.18.0" | sort -V | head -n1) == "$NODE_VERSION" ]]; then
    echo "Версия NodeJS ниже 20.18.0 ($NODE_VERSION). Обновляем..."
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash - >/dev/null 2>&1
    sudo apt install -y nodejs >/dev/null 2>&1
    echo "NodeJS обновлена: "
    node -v
fi

NODE_VERSION=$(node -v 2>/dev/null | cut -d 'v' -f 2)
echo "Node.js версия  $NODE_VERSION. Продолжаем..."

#preinstall yarn, so its properly registered in ~/profile
if ! command -v yarn >/dev/null 2>&1; then
      echo "Yarn не установлен. Устанавливаем..."
      curl -o- -L https://yarnpkg.com/install.sh 2>/dev/null | sh >/dev/null 2>&1
      echo 'export PATH="$HOME/.yarn/bin:$HOME/.config/yarn/global/node_modules/.bin:$PATH"' >> ~/.profile
      source ~/.profile
fi

echo "Клонируем GIT проекта..."
REPO_URL="https://github.com/gensyn-ai/rl-swarm.git"
git clone "$REPO_URL" &>/dev/null
cd rl-swarm || { echo "Failed to enter directory rl-swarm"; exit 1; }
if [[ -x /usr/bin/python3.13 ]]; then
    /usr/bin/python3.13 -m venv .venv
else
    python3 -m venv .venv
fi
source .venv/bin/activate


set -euo pipefail

# General arguments
ROOT=$PWD

# GenRL Swarm version to use
GENRL_TAG="0.1.11"

export IDENTITY_PATH
export GENSYN_RESET_CONFIG
export CONNECT_TO_TESTNET=true
export ORG_ID
export HF_HUB_DOWNLOAD_TIMEOUT=120  # 2 minutes
export SWARM_CONTRACT="0xFaD7C5e93f28257429569B854151A1B8DCD404c2"
export PRG_CONTRACT="0x51D4db531ae706a6eC732458825465058fA23a35"
export HUGGINGFACE_ACCESS_TOKEN="None"
export PRG_GAME=true

# Path to an RSA private key. If this path does not exist, a new key pair will be created.
# Remove this file if you want a new PeerID.
DEFAULT_IDENTITY_PATH="$ROOT"/swarm.pem
IDENTITY_PATH=${IDENTITY_PATH:-$DEFAULT_IDENTITY_PATH}

DOCKER=${DOCKER:-""}
GENSYN_RESET_CONFIG=${GENSYN_RESET_CONFIG:-""}

# Bit of a workaround for the non-root docker container.
if [ -n "$DOCKER" ]; then
    volumes=(
        /home/gensyn/rl_swarm/modal-login/temp-data
        /home/gensyn/rl_swarm/keys
        /home/gensyn/rl_swarm/configs
        /home/gensyn/rl_swarm/logs
    )

    for volume in ${volumes[@]}; do
        sudo chown -R 1001:1001 $volume
    done
fi

# Will ignore any visible GPUs if set.
CPU_ONLY=${CPU_ONLY:-""}

# Set if successfully parsed from modal-login/temp-data/userData.json.
ORG_ID=${ORG_ID:-""}

GREEN_TEXT="\033[32m"
BLUE_TEXT="\033[34m"
RED_TEXT="\033[31m"
RESET_TEXT="\033[0m"

echo_green() {
    echo -e "$GREEN_TEXT$1$RESET_TEXT"
}

echo_blue() {
    echo -e "$BLUE_TEXT$1$RESET_TEXT"
}

echo_red() {
    echo -e "$RED_TEXT$1$RESET_TEXT"
}

ROOT_DIR="$(cd $(dirname ${BASH_SOURCE[0]}) && pwd)"

errnotify() {
    echo_red ">> An error was detected while running rl-swarm. See $ROOT/logs for full logs."
}

trap errnotify ERR

echo -e "\033[38;5;224m"
cat << "EOF"
    ██████  ██            ███████ ██     ██  █████  ██████  ███    ███
    ██   ██ ██            ██      ██     ██ ██   ██ ██   ██ ████  ████
    ██████  ██      █████ ███████ ██  █  ██ ███████ ██████  ██ ████ ██
    ██   ██ ██                 ██ ██ ███ ██ ██   ██ ██   ██ ██  ██  ██
    ██   ██ ███████       ███████  ███ ███  ██   ██ ██   ██ ██      ██

    From Gensyn

EOF

# Create logs directory if it doesn't exist
mkdir -p "$ROOT/logs"

if [ "$CONNECT_TO_TESTNET" = true ]; then
    # Run modal_login server.
    echo "Please login to create an Ethereum Server Wallet"
    cd modal-login
    # Check if the yarn command exists; if not, install Yarn.

    # Node.js + NVM setup
    if ! command -v node > /dev/null 2>&1; then
        echo "Node.js not found. Installing NVM and latest Node.js..."
        export NVM_DIR="$HOME/.nvm"
        if [ ! -d "$NVM_DIR" ]; then
            curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
        fi
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
        [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
        nvm install node &>/dev/null
    else
        echo "Node.js is already installed: $(node -v)"
    fi

    if ! command -v yarn > /dev/null 2>&1; then
        # Detect Ubuntu (including WSL Ubuntu) and install Yarn accordingly
        if grep -qi "ubuntu" /etc/os-release 2> /dev/null || uname -r | grep -qi "microsoft"; then
            echo "Detected Ubuntu or WSL Ubuntu. Installing Yarn via apt..."
            curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
            echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list
            sudo apt install -y yarn > /dev/null 2>&1
        else
            echo "Yarn not found. Installing Yarn globally with npm (no profile edits)…"
            # This lands in $NVM_DIR/versions/node/<ver>/bin which is already on PATH
            npm install -g --silent yarn
        fi
    fi

    ENV_FILE="$ROOT"/modal-login/.env
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS version
        sed -i '' "3s/.*/SWARM_CONTRACT_ADDRESS=$SWARM_CONTRACT/" "$ENV_FILE"
        sed -i '' "4s/.*/PRG_CONTRACT_ADDRESS=$PRG_CONTRACT/" "$ENV_FILE"
    else
        # Linux version
        sed -i "3s/.*/SWARM_CONTRACT_ADDRESS=$SWARM_CONTRACT/" "$ENV_FILE"
        sed -i "4s/.*/PRG_CONTRACT_ADDRESS=$PRG_CONTRACT/" "$ENV_FILE"
    fi


    # Docker image already builds it, no need to again.
    if [ -z "$DOCKER" ]; then
        yarn install --immutable --silent > /dev/null 2>&1
        echo "Building server"
        yarn build > "$ROOT/logs/yarn.log" 2>&1
    fi
    yarn start >> "$ROOT/logs/yarn.log" 2>&1 & # Run in background and log output

    #SERVER_PID=$!  # Store the process ID
    #echo "Started server process: $SERVER_PID"
    sleep 5

    cd ..

    echo_green ">> Ждем файл userData.json (нужно залогиниться)..."
    while [ ! -f "modal-login/temp-data/userData.json" ]; do
        sleep 5  # Wait for 5 seconds before checking again
    done
    echo "Найден файл userData.json. Продолжаем..."

    ORG_ID=$(awk 'BEGIN { FS = "\"" } !/^[ \t]*[{}]/ { print $(NF - 1); exit }' modal-login/temp-data/userData.json)
    echo "Your ORG_ID is set to: $ORG_ID"

    # Wait until the API key is activated by the client
    echo "Waiting for API key to become activated..."
    while true; do
        STATUS=$(curl -s "http://localhost:3000/api/get-api-key-status?orgId=$ORG_ID")
        if [[ "$STATUS" == "activated" ]]; then
            echo "API key is activated! Proceeding..."
            break
        else
            echo "Waiting for API key to be activated..."
            sleep 5
        fi
    done
    if [[ -f "/root/$PEM_FILE" ]]; then
        echo "Нашли бекап файла $PEM_FILE в /root/. Копирую в папку проекта $ROOT..."
        cp "/root/$PEM_FILE" "$ROOT/"
    fi
fi

echo_green ">> Ставим библиотеки с помощью pip..."
pip install --upgrade pip &>/dev/null

# echo_green ">> Installing GenRL..."
#pip install "trl<0.20.0"
#-------------------------------------------------------------------------------------------------------
echo_green ">> Installing GenRL..."

# Ollama already running as part of the docker compose file
if [ -z "$DOCKER" ]; then
    echo_green ">> Installing Ollama requires 'sudo' privileges. As an alternative, please use the Docker installation path as described in README.md"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # Install brew if not already installed
        if ! command -v brew > /dev/null 2>&1; then
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        fi
        # Install ollama if not already installed
        if ! command -v ollama > /dev/null 2>&1; then
            brew install ollama
        fi
    else
        # Install ollama if not already installed
        if ! command -v ollama > /dev/null 2>&1; then
            curl -fsSL https://ollama.com/install.sh | sh -s -- -y
        fi
    fi
    # Start ollama server if not already running, check by running ollama list
    if ! ollama list > /dev/null 2>&1; then
        echo ">> Starting ollama server..."
        nohup ollama serve > /tmp/ollama.log 2>&1 &
    fi
fi

pip install -r code_gen_exp/requirements.txt

if [ ! -d "$ROOT/configs" ]; then
    mkdir "$ROOT/configs"
fi  
if [ -f "$ROOT/configs/code-gen-swarm.yaml" ]; then
    # Use cmp -s for a silent comparison. If different, backup and copy.
    if ! cmp -s "$ROOT/code_gen_exp/config/code-gen-swarm.yaml" "$ROOT/configs/code-gen-swarm.yaml"; then
        if [ -z "$GENSYN_RESET_CONFIG" ]; then
            echo_green ">> Found differences in code-gen-swarm.yaml. If you would like to reset to the default, set GENSYN_RESET_CONFIG to a non-empty value."
        else
            echo_green ">> Found differences in code-gen-swarm.yaml. Backing up existing config."
            mv "$ROOT/configs/code-gen-swarm.yaml" "$ROOT/configs/code-gen-swarm.yaml.bak"
            cp "$ROOT/code_gen_exp/config/code-gen-swarm.yaml" "$ROOT/configs/code-gen-swarm.yaml"
        fi
    fi
else
    # If the config doesn't exist, just copy it.
    cp "$ROOT/code_gen_exp/config/code-gen-swarm.yaml" "$ROOT/configs/code-gen-swarm.yaml"
fi

if [ -n "$DOCKER" ]; then
    # Make it easier to edit the configs on Linux systems.
    sudo chmod -R 0777 /home/gensyn/rl_swarm/configs
fi

echo_green ">> Done!"


echo -en $GREEN_TEXT
read -p ">> Would you like to push models you train in the RL swarm to the Hugging Face Hub? [y/N] " yn
echo -en $RESET_TEXT
yn=${yn:-N} # Default to "N" if the user presses Enter
case $yn in
    [Yy]*) read -p "Enter your Hugging Face access token: " HUGGINGFACE_ACCESS_TOKEN ;;
    [Nn]*) HUGGINGFACE_ACCESS_TOKEN="None" ;;
    *) echo ">>> No answer was given, so NO models will be pushed to Hugging Face Hub" && HUGGINGFACE_ACCESS_TOKEN="None" ;;
esac


echo -en $GREEN_TEXT
read -p ">> Enter the name of the model you want to use in huggingface repo/name format, or press [Enter] to use the default model. " MODEL_NAME
echo -en $RESET_TEXT

# Only export MODEL_NAME if user provided a non-empty value
if [ -n "$MODEL_NAME" ]; then
    export MODEL_NAME
    echo_green ">> Using model: $MODEL_NAME"
else
    echo_green ">> Using default model from config"
fi
#logout to prevent weird env issues, if it fails unset and try again
if ! hf auth logout > /dev/null 2>&1; then
    unset HF_TOKEN
    unset HUGGING_FACE_HUB_TOKEN
    # if it fails a second time, report stderr
    hf auth logout > /dev/null 2>&1
fi

echo -en $RESET_TEXT
echo_green ">> Good luck in the swarm!"
echo_blue ">> And remember to star the repo on GitHub! --> https://github.com/gensyn-ai/rl-swarm"

python -m code_gen_exp.runner.swarm_launcher \
    --config-path "$ROOT/code_gen_exp/config" \
    --config-name "code-gen-swarm.yaml" 

wait
EOF
#-------------------------------------------------------------------------------------------------------
chmod +x "$OUTPUT_SCRIPT"
echo "Скрипт для systemd сервиса создан: $OUTPUT_SCRIPT"

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
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd, enable and start the service
sudo systemctl daemon-reload
sudo systemctl enable gensyn.service
sudo systemctl start gensyn.service

sleep 10
[ -f "$ROOT/swarm.pem" ] && cp "$ROOT/swarm.pem" "/root/swarm.pem.backup"

echo -e "${GREEN}Обновление завершено.${NC}"
echo "Смотреть логи можно командой: tail -n 100 -f $ERROR_LOG_FILE"
