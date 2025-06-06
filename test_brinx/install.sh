#!/bin/bash

YELLOW='\e[0;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}Установка Модель text-ui...${NC}"
docker run -d --name text-ui --network brinxai-network --cpus=4 --memory=4096m -p 127.0.0.1:5000:5000 --restart unless-stopped admier/brinxai_nodes-text-ui:latest
echo -e "${GREEN}Установка завершена${NC}"



echo -e "${YELLOW}Установка Модель rembg...${NC}"
docker run -d --name rembg --network brinxai-network --cpus=2 --memory=2048m -p 127.0.0.1:7000:7000 --restart unless-stopped admier/brinxai_nodes-rembg:latest
echo -e "${GREEN}Установка завершена${NC}"



echo -e "${YELLOW}Установка Модель upscaler...${NC}"
docker run -d --name upscaler --network brinxai-network --cpus=2 --memory=2048m -p 127.0.0.1:3030:3030 --restart unless-stopped admier/brinxai_nodes-upscaler:latest
echo -e "${GREEN}Установка завершена${NC}"
