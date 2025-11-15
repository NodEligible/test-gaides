#!/bin/bash

YELLOW='\e[0;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[38;5;81m'
NC='\033[0m'

echo -e "${YELLOW}⚙️ Установка зависимостей...${NC}"
sudo apt update && sudo apt upgrade -y

echo -e "${YELLOW}Установка Docker...${NC}"
bash <(curl -s https://raw.githubusercontent.com/NodEligible/programs/refs/heads/main/docker.sh)

# Install packages
sudo apt install curl iptables build-essential git wget lz4 jq make gcc nano automake autoconf tmux htop nvme-cli pkg-config libssl-dev libleveldb-dev tar clang bsdmainutils ncdu unzip libleveldb-dev libudev-dev protobuf-compiler -y

# Install node
sudo apt update
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo bash -
sudo apt install -y nodejs
node -v
npm install -g yarn
yarn -v

# Install yarn
curl -o- -L https://yarnpkg.com/install.sh | bash
export PATH="$HOME/.yarn/bin:$HOME/.config/yarn/global/node_modules/.bin:$PATH"
source ~/.bashrc

# Install Rust
sudo curl https://sh.rustup.rs -sSf | sh

# Add Rust to path
source $HOME/.cargo/env
export PATH="$HOME/.cargo/bin:$PATH"

rustup update

rustc --version

# Install Anchor
git clone https://github.com/coral-xyz/anchor.git
cd anchor
git checkout v0.31.1
cargo install --path cli --force

cd .. && rm -r anchor

# Verify Anchor
anchor --version

# Install Solana CLI
curl --proto '=https' --tlsv1.2 -sSfL https://solana-install.solana.workers.dev | bash

# Set PATH
PATH="/root/.local/share/solana/install/active_release/bin:$PATH"

# Verify installation
solana --version 



