#!/bin/bash

curl -s https://raw.githubusercontent.com/NodEligible/programs/refs/heads/main/display_logo.sh | bash

# Color codes for output
YELLOW='\e[0;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'


  echo -e "${YELLOW}Установка Docker...${NC}"
  bash <(curl -s https://raw.githubusercontent.com/NodEligible/programs/refs/heads/main/docker.sh)
  if [ $? -eq 0 ]; then
      echo -e "${GREEN}Docker успешно установлено!${NC}"
  else
      echo -e "${RED}Ошибка при установке Docker!${NC}"
  fi

  echo -e "${YELLOW}Установка Ufw...${NC}" 
  bash <(curl -s https://raw.githubusercontent.com/NodEligible/programs/refs/heads/main/ufw.sh)
  if [ $? -eq 0 ]; then
      echo -e "${GREEN}Ufw успешно установлено!${NC}"
  else
      echo -e "${RED}Ошибка при установке Ufw!${NC}"
  fi

  sudo apt install -y wget unzip

  echo -e "${YELLOW}Установка Hyperspace...${NC}"
  wget https://download.hyper.space/aios/linux -O hyperspace_0.2.1-cuda_amd64.dep
  
  #Распаковка
  sudo dpkg -i hyperspace_0.2.1-cuda_amd64.dep

  # Получаем имя текущего пользователя из переменной окружения $USER
MY_USER=$USER

# Проверяем, пустое ли имя пользователя или переменная не установлена
if [ -z "$MY_USER" ]; then
    echo "Ошибка: Переменная окружения \$USER не установлена."
    exit 1
fi

# Добавляем пользователя в группу docker
sudo usermod -aG docker "$MY_USER"

# Обновляем права доступа для сокета Docker
sudo chown root:docker /var/run/docker.sock
sudo chmod 660 /var/run/docker.sock

echo "Hyperspace успешно установлен!"
echo "Нажмите Enter, чтобы продолжить..."
read -r
newgrp docker

