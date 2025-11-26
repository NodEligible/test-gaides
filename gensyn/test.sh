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
