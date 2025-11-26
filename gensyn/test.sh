echo_green ">> Installing GenRL..."
pip install gensyn-genrl==${GENRL_TAG}
pip install reasoning-gym>=0.1.20 # for reasoning gym env
#pip install trl # for grpo config, will be deprecated soon
pip install hivemind@git+https://github.com/gensyn-ai/hivemind@639c964a8019de63135a2594663b5bec8e5356dd # We need the latest, 1.1.11 is broken


if [ ! -d "$ROOT/configs" ]; then
    mkdir "$ROOT/configs"
fi  
if [ -f "$ROOT/configs/rg-swarm.yaml" ]; then
    # Use cmp -s for a silent comparison. If different, backup and copy.
    if ! cmp -s "$ROOT/rgym_exp/config/rg-swarm.yaml" "$ROOT/configs/rg-swarm.yaml"; then
        if [ -z "$GENSYN_RESET_CONFIG" ]; then
            echo_green ">> Found differences in rg-swarm.yaml. If you would like to reset to the default, set GENSYN_RESET_CONFIG to a non-empty value."
        else
            echo_green ">> Found differences in rg-swarm.yaml. Backing up existing config."
            mv "$ROOT/configs/rg-swarm.yaml" "$ROOT/configs/rg-swarm.yaml.bak"
            cp "$ROOT/rgym_exp/config/rg-swarm.yaml" "$ROOT/configs/rg-swarm.yaml"
        fi
    fi
else
    # If the config doesn't exist, just copy it.
    cp "$ROOT/rgym_exp/config/rg-swarm.yaml" "$ROOT/configs/rg-swarm.yaml"
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

echo -en $GREEN_TEXT
read -p ">> Would you like your model to participate in the AI Prediction Market? [Y/n] " yn
if [ "$yn" = "n" ] || [ "$yn" = "N" ]; then
    PRG_GAME=false
    echo_green ">> Playing PRG game: false"
else
    echo_green ">> Playing PRG game: true"
fi
echo -en $RESET_TEXT

echo_green ">> Good luck in the swarm!"
# end official script part

# делаем скрипт для будущего systemd сервиса
OUTPUT_SCRIPT="$ROOT/gensyn_service.sh"

cat <<EOF > "$OUTPUT_SCRIPT"
#!/bin/bash

# Set working directory
ROOT="$ROOT"
cd "\$ROOT" || exit 1

source /root/.profile
source .venv/bin/activate

export IDENTITY_PATH
export GENSYN_RESET_CONFIG
export CONNECT_TO_TESTNET=true
export ORG_ID
export HF_HUB_DOWNLOAD_TIMEOUT=120  # 2 minutes
export SWARM_CONTRACT="0xFaD7C5e93f28257429569B854151A1B8DCD404c2"
export HUGGINGFACE_ACCESS_TOKEN="None"

DEFAULT_IDENTITY_PATH="$ROOT"/swarm.pem
IDENTITY_PATH=${IDENTITY_PATH:-$DEFAULT_IDENTITY_PATH}

GENSYN_RESET_CONFIG=${GENSYN_RESET_CONFIG:-""}
ORG_ID=$(awk 'BEGIN { FS = "\"" } !/^[ \t]*[{}]/ { print $(NF - 1); exit }' modal-login/temp-data/userData.json)

pkill next-server

cd modal-login
yarn start >> "$ROOT/logs/yarn.log" 2>&1 & # Run in background and log output

cd ..
python -m rgym_exp.runner.swarm_launcher \
    --config-path "$ROOT/rgym_exp/config" \
    --config-name "rg-swarm.yaml"

wait
