#!/bin/bash

YELLOW='\e[0;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[38;5;81m'
NC='\033[0m'

echo -e "${YELLOW}⚙️ Оновлення системи...${NC}"
sudo apt update && sudo apt upgrade -y

echo -e "${YELLOW}📦 Установка необхідних пакетів...${NC}"
sudo apt install -y \
  curl wget git tmux htop unzip build-essential pkg-config \
  libssl-dev clang make jq

echo -e "${YELLOW}🐳 Установка Docker...${NC}"
bash <(curl -s https://raw.githubusercontent.com/NodEligible/programs/refs/heads/main/docker.sh)

echo -e "${YELLOW}🦀 Установка Rust...${NC}"
curl https://sh.rustup.rs -sSf | sh -s -- -y
source $HOME/.cargo/env

echo -e "${YELLOW}🌞 Установка Solana CLI...${NC}"
curl --proto '=https' --tlsv1.2 -sSfL https://solana-install.solana.workers.dev | bash
export PATH="/root/.local/share/solana/install/active_release/bin:$PATH"

echo -e "${GREEN}✅ Перевірка версій...${NC}"
solana --version
rustc --version
cargo --version
docker --version

echo -e "${GREEN}🎉 Підготовка завершена! Можна переходити до встановлення Arcium.${NC}"
