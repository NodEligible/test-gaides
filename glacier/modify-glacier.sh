#!/bin/bash

# Переменные
IMAGE_TAR="glacier-verifier-v0.0.3.tar"
EXTRACT_DIR="glacier-verifier-extract"
MODIFIED_TAR="glacier-verifier-modified.tar"

# Шаг 1: Очистите предыдущее извлечение, если оно существует
if [ -d "$EXTRACT_DIR" ]; then
  echo "Cleaning previous extraction..."
  rm -rf "$EXTRACT_DIR"
fi

# Шаг 2: Извлеките tar-изображение
echo "Extracting image tar..."
mkdir "$EXTRACT_DIR"
tar -xf "$IMAGE_TAR" -C "$EXTRACT_DIR"

# Шаг 3: Запросите закрытый ключ
read -p "Enter your private key: " PRIVATE_KEY

# Шаг 4: Внедрить закрытый ключ в изображение (например, создание файла с ключом)
BLOBS_DIR=$(find "$EXTRACT_DIR" -type d -name blobs)
echo "Adding private key to the image..."
echo "$PRIVATE_KEY" > "$BLOBS_DIR/private_key.txt"

# Шаг 5: Перепакуйте измененный образ
echo "Repacking modified image..."
tar -cf "$MODIFIED_TAR" -C "$EXTRACT_DIR" .

# Очистка
echo "Cleaning up temporary files..."
rm -rf "$EXTRACT_DIR"

echo "Modified image saved as $MODIFIED_TAR"
