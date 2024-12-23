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

# Проверяем, начинается ли файл с "Cr24"
MAGIC_HEADER=$(xxd -l 4 -ps "$CRX_FILE")
if [ "$MAGIC_HEADER" != "43723234" ]; then
    echo -e "${RED}Файл не является корректным CRX.${NC}"
    exit 1
fi

# Используем Node.js для обработки CRX-файла
NODE_SCRIPT=$(cat <<EOF
const fs = require('fs');

// Путь к CRX-файлу
const crxFilePath = process.argv[2];
const extDir = process.argv[3];
const extId = process.argv[4];

try {
    const crxFile = fs.readFileSync(crxFilePath);
    const headerSize = crxFile.readUInt32LE(8);

    if (headerSize <= 0 || headerSize >= crxFile.length) {
        console.error("Некорректный размер заголовка.");
        process.exit(1);
    }

    // Удаляем заголовок и сохраняем ZIP-часть
    const zipFilePath = \`\${extDir}/\${extId}.zip\`;
    fs.writeFileSync(zipFilePath, crxFile.slice(headerSize));

    console.log("ZIP-файл успешно сохранён:", zipFilePath);
} catch (err) {
    console.error("Ошибка обработки CRX-файла:", err.message);
    process.exit(1);
}
EOF
)

# Передаём Node.js данные для обработки
node -e "$NODE_SCRIPT" "$CRX_FILE" "$EXT_DIR" "$EXT_ID"
if [ $? -ne 0 ]; then
    echo -e "${RED}Ошибка обработки CRX-файла через Node.js.${NC}"
    exit 1
fi

# Распаковываем ZIP
ZIP_FILE="$EXT_DIR/$EXT_ID.zip"
EXT_OUTPUT_DIR="$EXT_DIR/$EXT_ID"
echo -e "${YELLOW}Распаковываем ZIP в директорию: $EXT_OUTPUT_DIR${NC}"
unzip -q "$ZIP_FILE" -d "$EXT_OUTPUT_DIR"
if [ $? -eq 0 ]; then
    echo -e "${GREEN}Расширение успешно установлено в: $EXT_OUTPUT_DIR${NC}"
    rm "$CRX_FILE" "$ZIP_FILE"
else
    echo -e "${RED}Ошибка при распаковке ZIP-файла. Проверьте содержимое.${NC}"
    rm "$CRX_FILE" "$ZIP_FILE"
    exit 1
fi
