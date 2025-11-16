#!/bin/bash

YELLOW='\e[0;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

print_header() {
  echo -e "${CYAN}"
  echo "======================================="
  echo "     Arcium Dependencies Checker"
  echo "======================================="
  echo -e "${NC}"
}

check_cmd() {
  local cmd=$1
  local name=$2

  if command -v "$cmd" >/dev/null 2>&1; then
    VERSION=$("$cmd" --version 2>/dev/null | head -n1)
    echo -e "${GREEN}✔ $name найден: ${CYAN}$VERSION${NC}"
  else
    echo -e "${RED}✘ $name НЕ найден${NC}"
  fi
}

check_docker_compose() {
  if docker compose version >/dev/null 2>&1; then
    VERSION=$(docker compose version | head -n1)
    echo -e "${GREEN}✔ Docker Compose найден: ${CYAN}$VERSION${NC}"
  else
    echo -e "${RED}✘ Docker Compose НЕ найден${NC}"
  fi
}

print_header

echo -e "${YELLOW}🔍 Проверка основных зависимостей Arcium...${NC}"

check_cmd rustc "Rust"
check_cmd cargo "Cargo"
check_cmd solana "Solana CLI"
check_cmd yarn "Yarn"
check_cmd anchor "Anchor CLI"
check_cmd docker "Docker"
check_docker_compose

echo
echo -e "${YELLOW}🔚 Проверка завершена.${NC}"
echo -e "${YELLOW}📌 Если какие-то зависимости отсутствуют — их нужно установить перед запуском ноды Arcium.${NC}"
