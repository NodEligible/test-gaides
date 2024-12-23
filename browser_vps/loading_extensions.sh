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

# Запрашиваем ссылку на расширение
read -p "Введите ссылку на расширение: " EXT_URL

# Проверяем, ввели ли ссылку
if [ -z "$EXT_URL" ]; then
    echo -e "${RED}Ссылка на расширение не введена. Попробуйте снова.${NC}"
    exit 1
fi

# Генерация уникального ID для хранения расширения
EXT_ID=$(basename "$EXT_URL" | cut -d'?' -f1 | md5sum | cut -d' ' -f1)

# Загружаем расширение
echo -e "${YELLOW}Загружаем расширение из: $EXT_URL...${NC}"
curl -L -o "$EXT_DIR/$EXT_ID.zip" "$EXT_URL"
if [ $? -ne 0 ]; then
    echo -e "${RED}Ошибка при загрузке расширения. Проверьте ссылку.${NC}"
    exit 1
fi

# Проверяем корректность файла перед распаковкой
if file "$EXT_DIR/$EXT_ID.zip" | grep -q "Zip archive data"; then
    echo -e "${GREEN}Файл корректен. Распаковываем...${NC}"
    unzip "$EXT_DIR/$EXT_ID.zip" -d "$EXT_DIR/$EXT_ID" > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Расширение успешно установлено в $EXT_DIR/$EXT_ID.${NC}"
        rm "$EXT_DIR/$EXT_ID.zip"
    else
        echo -e "${RED}Ошибка при распаковке. Проверьте содержимое файла.${NC}"
        rm "$EXT_DIR/$EXT_ID.zip"
        exit 1
    fi
else
    echo -e "${RED}Файл не является корректным ZIP-архивом. Проверьте ссылку.${NC}"
    rm "$EXT_DIR/$EXT_ID.zip"
    exit 1
fi
