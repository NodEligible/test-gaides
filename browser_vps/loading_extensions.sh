#!/bin/bash

# Цвета для сообщений
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

# Путь к директории для расширений
EXT_DIR="/root/chromium/config/.config/chromium/Default/Extensions"

# Проверяем, существует ли директория
if [ ! -d "$EXT_DIR" ]; then
    echo -e "${RED}Директория $EXT_DIR не существует. Создаём...${NC}"
    mkdir -p "$EXT_DIR"
fi

# Запрашиваем ID расширения
read -p "Введите ID расширения: " EXT_ID

# Проверяем, ввели ли ID
if [ -z "$EXT_ID" ]; then
    echo -e "${RED}ID расширения не введён. Попробуйте снова.${NC}"
    exit 1
fi

# Формируем URL для загрузки
URL="https://clients2.google.com/service/update2/crx?response=redirect&prodversion=91.0.4472.124&acceptformat=crx3&x=id%3D$EXT_ID%26installsource%3Dondemand%26uc"

echo -e "${YELLOW}Загружаем расширение с ID: $EXT_ID...${NC}"

# Загружаем расширение
curl -L -o "$EXT_DIR/$EXT_ID.zip" "$URL"
if [ $? -ne 0 ]; then
    echo -e "${RED}Ошибка при загрузке расширения. Проверьте ID.${NC}"
    exit 1
fi

# Распаковываем загруженное расширение
if unzip -tq "$EXT_DIR/$EXT_ID.zip" > /dev/null 2>&1; then
    echo -e "${GREEN}Файл корректен. Распаковываем...${NC}"
    unzip "$EXT_DIR/$EXT_ID.zip" -d "$EXT_DIR/$EXT_ID" > /dev/null 2>&1
    rm "$EXT_DIR/$EXT_ID.zip"
    echo -e "${GREEN}Расширение с ID $EXT_ID успешно установлено.${NC}"
else
    echo -e "${RED}Файл некорректен или повреждён. Проверьте ID или источник.${NC}"
    rm "$EXT_DIR/$EXT_ID.zip"
    exit 1
fi
