#!/bin/bash

# Цвета для вывода
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

# Путь к директории для расширений
EXT_DIR="/root/chromium/config/.config/chromium/Default/Extensions"

# Проверяем, существует ли директория
if [ ! -d "$EXT_DIR" ]; then
    echo -e "${YELLOW}Создаём директорию: $EXT_DIR${NC}"
    mkdir -p "$EXT_DIR"
fi

# Запросить ID или ссылку на расширение
read -p "Введите ссылку на расширение или его ID: " INPUT

# Определяем ID расширения
if [[ "$INPUT" =~ chromewebstore.google.com ]]; then
    EXT_ID=$(echo "$INPUT" | awk -F'/' '{print $NF}')
elif [[ "$INPUT" =~ ^[a-z]{32}$ ]]; then
    EXT_ID="$INPUT"
else
    echo -e "${RED}Некорректный ввод. Укажите ссылку или ID расширения.${NC}"
    exit 1
fi

# Формируем URL для загрузки CRX
CRX_URL="https://clients2.google.com/service/update2/crx?response=redirect&prodversion=91.0.4472.124&acceptformat=crx3&x=id%3D$EXT_ID%26installsource%3Dondemand%26uc"

# Скачиваем CRX
CRX_FILE="$EXT_DIR/$EXT_ID.crx"
echo -e "${YELLOW}Загружаем CRX-файл из: $CRX_URL${NC}"
curl -L -o "$CRX_FILE" "$CRX_URL"
if [ $? -ne 0 ]; then
    echo -e "${RED}Ошибка при загрузке CRX-файла.${NC}"
    exit 1
fi

# Распаковываем CRX
EXT_OUTPUT_DIR="$EXT_DIR/$EXT_ID"
echo -e "${YELLOW}Распаковываем CRX в директорию: $EXT_OUTPUT_DIR${NC}"
unzip -q "$CRX_FILE" -d "$EXT_OUTPUT_DIR"
if [ $? -eq 0 ]; then
    echo -e "${GREEN}Расширение успешно установлено в: $EXT_OUTPUT_DIR${NC}"
    rm "$CRX_FILE"
else
    echo -e "${RED}Ошибка при распаковке CRX-файла. Проверьте содержимое.${NC}"
    exit 1
fi
