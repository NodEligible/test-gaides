#!/usr/bin/env bash

set -e

# Перевірка прав адміністратора
if [[ $EUID -ne 0 ]]; then
    echo "Цей скрипт потрібно запускати з правами адміністратора (root)."
    exit 1
fi

# Змінні
KASM_VERSION="1.16.1.98d6fa"
KASM_DOWNLOAD_URL="https://kasm-static-content.s3.amazonaws.com/kasm_release_${KASM_VERSION}.tar.gz"
KASM_ARCHIVE="/tmp/kasm_release_${KASM_VERSION}.tar.gz"
KASM_INSTALL_DIR="/tmp/kasm_release"

# Завантаження Kasm
function download_kasm() {
    echo "Завантаження Kasm з ${KASM_DOWNLOAD_URL}..."
    curl -o "$KASM_ARCHIVE" "$KASM_DOWNLOAD_URL"
    if [[ $? -ne 0 ]]; then
        echo "Помилка під час завантаження Kasm."
        exit 1
    fi
}

# Розпакування архіву
function extract_kasm() {
    echo "Розпакування архіву Kasm..."
    tar -xf "$KASM_ARCHIVE" -C /tmp
    if [[ $? -ne 0 ]]; then
        echo "Помилка під час розпакування архіву Kasm."
        exit 1
    fi
}

# Запуск інсталяції
function install_kasm() {
    echo "Запуск інсталяції Kasm..."
    sudo bash "$KASM_INSTALL_DIR/install.sh"
    if [[ $? -ne 0 ]]; then
        echo "Помилка під час встановлення Kasm."
        exit 1
    fi
}

# Основний процес
function main() {
    download_kasm
    extract_kasm
    install_kasm
    echo "Установку Kasm завершено успішно."
}

main
