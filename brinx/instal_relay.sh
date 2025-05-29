#!/bin/bash

curl -s https://raw.githubusercontent.com/NodEligible/programs/refs/heads/main/display_logo.sh | bash

# Сменные для цветов
YELLOW='\e[0;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[38;5;81m'
NC='\033[0m' # Сброс цвета


  echo -e "${YELLOW}Установка Main...${NC}"
  bash <(curl -s https://raw.githubusercontent.com/NodEligible/programs/refs/heads/main/main.sh)
  if [ $? -eq 0 ]; then
      echo -e "${GREEN}Main успешно установлен!${NC}"
  else
      echo -e "${RED}Ошибка при установке Main!${NC}"
  fi

echo -e "${YELLOW}Удаляем ноду если установлена...${NC}"
docker stop watchtower
docker stop brinxai_relay 
docker rm -f brinxai_relay &>/dev/null
docker rmi -f admier/brinxai_nodes-relay &>/dev/null
docker rmi -f containrrr/watchtower &>/dev/null

echo -e "${YELLOW}Установка BrixAI Relay${NC}"
ARCH=$(dpkg --print-architecture)

if [ "$ARCH" = "amd64" ]; then
    URL="https://raw.githubusercontent.com/admier1/BrinxAI-Relay-Nodes/main/install_brinxai_relay_amd64.sh"
    CONTAINER_NAME="brinxai_relay_amd64"
else
    URL="https://raw.githubusercontent.com/admier1/BrinxAI-Relay-Nodes/main/install_brinxai_relay_arm64.sh"
    CONTAINER_NAME="brinxai_relay_arm64"
fi

# Download script to temp file
tmpfile=$(mktemp)
curl -s "$URL" -o "$tmpfile"
bash "$tmpfile"
rm "$tmpfile"

echo -e "${YELLOW}Фикс...${NC}"
VOLUME_PATH=$(docker inspect "$CONTAINER_NAME" --format '{{ range .Mounts }}{{ if eq .Destination "/etc/openvpn" }}{{ .Source }}{{ end }}{{ end }}')
if [ -z "$VOLUME_PATH" ]; then
  echo -e "${RED}Не удалось найти том /etc/openvpn в контейнере $CONTAINER_NAME${NC}"
  exit 1
fi

TA_KEY_PATH=$(find "$VOLUME_PATH" -type f -name "ta.key" | head -n 1)
if [ -z "$TA_KEY_PATH" ]; then
  echo -e "${RED}Файл ta.key не найден в ${VOLUME_PATH}${NC}"
  exit 1
fi

DEST_PATH="/var/lib/docker/volumes/openvpn_data/_data/"
cp "$TA_KEY_PATH" "$DEST_PATH"
if [ $? -eq 0 ]; then
  echo -e "${GREEN}Файл ta.key успешно скопирован в ${DEST_PATH}${NC}"
else
  echo -e "${RED}Ошибка копирования файла${NC}"
fi

CONF_FILE="${VOLUME_PATH}/openvpn.conf"
sed -i 's/^push "redirect-gateway def1 bypass-dhcp"$/push "redirect-gateway def1 bypass-dhcp"/' "$CONF_FILE"

echo -e "${YELLOW}Перезапуск контейнера${NC}"
docker restart "$CONTAINER_NAME"
