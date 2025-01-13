#!/bin/bash

# Змінні кольорів
YELLOW='\e[0;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Перевірка наявності параметра (гаманця)
if [ "$#" -ne 1 ]; then
    read -p "Введите адрес кошелька для ревардов: " YOUR_WALLET_ADDRESS
    if [ -z "$YOUR_WALLET_ADDRESS" ]; then
        echo -e "${RED}Адрес получения не может быть пустым. Выход...${NC}"
        exit 1
    fi
else
    YOUR_WALLET_ADDRESS=$1
fi

# Назва образу
IMAGE_NAME="iniminer:latest"

# Перевіряємо, чи існує образ, якщо ні — будуємо його
if ! docker image inspect $IMAGE_NAME > /dev/null 2>&1; then
    echo -e "${YELLOW}Создаем Docker образ...${NC}"
    docker build -t $IMAGE_NAME .
fi

# Запускаємо Docker-контейнер
echo -e "${GREEN}Запуск Docker-контейнера...${NC}"
docker run -d --name iniminer \
    --restart unless-stopped \
    $IMAGE_NAME \
    --pool stratum+tcp://$YOUR_WALLET_ADDRESS.Worker001@pool-core-testnet.inichain.com:32672

# Перевіряємо, чи контейнер успішно запущено
if [ "$(docker ps -q -f name=iniminer)" ]; then
    echo -e "${GREEN}Контейнер успешно запущен!${NC}"
    echo "Для просмотра логов используйте: docker logs -f iniminer"
else
    echo -e "${RED}Ошибка запуска контейнера. Проверьте конфигурацию.${NC}"
fi
