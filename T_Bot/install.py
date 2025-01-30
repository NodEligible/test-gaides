#!/usr/bin/env python3

# === Конфігурація ===
BOT_DIR="$HOME/NodEligiBot"
BOT_SCRIPT="bot.py"
SERVICE_FILE="/etc/systemd/system/nodeligibot.service"
BOT_TOKEN="7635090595:AAGF4JoWQHfp5tlluz6tkvFI9ZYq5AcjN6Q"  # Встав свій токен

echo "🔹 Починаємо встановлення Telegram-бота..."

# 1️⃣ Встановлення необхідних пакетів
echo "✅ Встановлюємо необхідні пакети..."
sudo apt update && sudo apt install -y python3 python3-pip curl jq
pip install aiogram

# 2️⃣ Створення папки для бота
echo "📁 Створюємо директорію для бота: $BOT_DIR"
mkdir -p "$BOT_DIR"

# 3️⃣ Створення `.env` для токена
echo "✅ Зберігаємо токен у .env..."
cat > "$BOT_DIR/.env" <<EOL
BOT_TOKEN="$BOT_TOKEN"
EOL

# 4️⃣ Створення файлу бота `bot.py`
echo "✅ Створюємо Python-скрипт бота..."
cat > "$BOT_DIR/$BOT_SCRIPT" <<'EOL'
import os
import logging
import asyncio
from aiogram import Bot, Dispatcher, types
from aiogram.types import InlineKeyboardMarkup, InlineKeyboardButton
from aiogram.utils import executor
import subprocess

from dotenv import load_dotenv

load_dotenv()  # Завантажує змінні з .env файлу
BOT_TOKEN = os.getenv("BOT_TOKEN")

print("✅ BOT_TOKEN:", BOT_TOKEN)  # Додай для дебагу

if not BOT_TOKEN:
    raise ValueError("❌ Помилка: BOT_TOKEN не знайдено! Переконайтеся, що він є у .env файлі.")

# === Налаштування бота ===
BOT_TOKEN = os.getenv("BOT_TOKEN")
CHAT_ID_FILE = "chat_id.txt"

# Якщо токен не передано через змінні середовища, беремо з .env
if not BOT_TOKEN:
    with open(".env") as f:
        for line in f:
            if line.startswith("BOT_TOKEN"):
                BOT_TOKEN = line.strip().split("=")[1]

bot = Bot(token=BOT_TOKEN)
dp = Dispatcher(bot)

# === Функція для отримання chat_id та збереження у файл ===
def get_chat_id():
    if os.path.exists(CHAT_ID_FILE):
        with open(CHAT_ID_FILE, "r") as f:
            return f.read().strip()
    return None

def save_chat_id(chat_id):
    with open(CHAT_ID_FILE, "w") as f:
        f.write(str(chat_id))

# === Отримання ID чату при першому повідомленні ===
@dp.message_handler(commands=["start"])
async def send_welcome(message: types.Message):
    chat_id = message.chat.id
    saved_chat_id = get_chat_id()

    if not saved_chat_id:
        save_chat_id(chat_id)
        await message.reply(f"✅ Ваш chat_id збережено: `{chat_id}`", parse_mode="Markdown")

    await message.reply("👋 *Вітаю! Я бот для моніторингу нод.*\n\n📌 *Оберіть команду:*", reply_markup=main_menu(), parse_mode="Markdown")

# === Функція для створення меню ===
def main_menu():
    keyboard = InlineKeyboardMarkup()
    nodes = ["Waku", "Privasea", "Cysic", "Nesa", "Ritual", "Elixir", "Hemi"]

    for node in nodes:
        keyboard.add(InlineKeyboardButton(f"🔍 Check Logs {node}", callback_data=f"status_{node}"))
        keyboard.add(InlineKeyboardButton(f"♻️ Restart {node}", callback_data=f"restart_{node}"))

    keyboard.add(InlineKeyboardButton("🏆 Check Sonaric Points", callback_data="points"))
    keyboard.add(InlineKeyboardButton("🔄 Restart Server", callback_data="reboot"))

    return keyboard

# === Функція для отримання логів ===
async def get_logs(node):
    log_file = f"/tmp/{node}_logs.txt"
    commands = {
        "Privasea": "docker logs --tail=100 privasea-node",
        "Cysic": "~/cysic-verifier/manage_verifier.sh logs | tail -n 100",
        "Waku": "docker-compose -f $HOME/nwaku-compose/docker-compose.yml logs --tail=100",
        "Nesa": "docker logs --tail=100 orchestrator",
        "Ritual": "docker compose -f $HOME/infernet-container-starter/deploy/docker-compose.yaml logs --tail=100",
        "Elixir": "docker logs --tail=100 elixir",
        "Hemi": "journalctl -n 100 -u hemi -o cat",
    }

    if node not in commands:
        return None

    result = subprocess.run(commands[node], shell=True, capture_output=True, text=True)

    with open(log_file, "w") as f:
        f.write(result.stdout or "❌ Логи порожні або не знайдені!")

    return log_file

# === Функція для перезапуску ноди ===
async def restart_node(node):
    commands = {
        "Privasea": "docker restart privasea-node",
        "Cysic": "~/cysic-verifier/manage_verifier.sh restart",
        "Waku": "docker-compose -f $HOME/nwaku-compose/docker-compose.yml restart",
        "Nesa": "docker restart orchestrator ipfs_node mongodb docker-watchtower-1",
        "Ritual": "docker compose -f $HOME/infernet-container-starter/deploy/docker-compose.yaml restart",
        "Elixir": "docker restart elixir",
        "Hemi": "sudo systemctl restart hemi",
        "Sonaric": "sonaric points",
        "server": "reboot",
    }

    if node not in commands:
        return False

    subprocess.run(commands[node], shell=True)
    return True

# === Обробка кнопок ===
@dp.callback_query_handler(lambda c: c.data.startswith("status_") or c.data.startswith("restart_") or c.data in ["points", "reboot"])
async def process_callback(callback_query: types.CallbackQuery):
    action, node = callback_query.data.split("_") if "_" in callback_query.data else (callback_query.data, None)
    chat_id = get_chat_id()

    if not chat_id:
        await callback_query.message.answer("⚠️ Chat ID не знайдено! Відправте /start, щоб зберегти ваш chat_id.")
        return

    if action == "status" and node:
        log_file = await get_logs(node)
        if log_file:
            await bot.send_document(chat_id, types.InputFile(log_file), caption=f"🔍 Логи ноди {node}")
        else:
            await bot.send_message(chat_id, f"❌ Логи для {node} не знайдені!")

    elif action == "restart" and node:
        success = await restart_node(node)
        if success:
            await bot.send_message(chat_id, f"♻️ Нода {node} успішно перезапущена!")
        else:
            await bot.send_message(chat_id, f"❌ Не вдалося перезапустити {node}!")

    elif action == "points":
        result = subprocess.run("sonaric points", shell=True, capture_output=True, text=True)
        await bot.send_message(chat_id, f"🏆 Sonaric Points:\n```\n{result.stdout or 'Немає даних'}\n```", parse_mode="Markdown")

    elif action == "reboot":
        await bot.send_message(chat_id, "🔄 Сервер перезавантажується...")
        await restart_node("server")

    await bot.answer_callback_query(callback_query.id)

# === Запуск бота ===
if __name__ == "__main__":
    executor.start_polling(dp, skip_updates=True)
EOL

# 5️⃣ Налаштування systemd-сервісу
echo "✅ Налаштовуємо systemd-сервіс..."
sudo bash -c "cat > $SERVICE_FILE" <<EOL
[Unit]
Description=NodEligiBot Telegram Bot
After=network.target

[Service]
ExecStart=/usr/bin/python3 $BOT_DIR/$BOT_SCRIPT
Restart=always
User=$USER
WorkingDirectory=$BOT_DIR

[Install]
WantedBy=multi-user.target
EOL

# 6️⃣ Запуск бота через systemd
echo "✅ Запускаємо бота..."
sudo systemctl daemon-reload
sudo systemctl enable nodeligibot
sudo systemctl start nodeligibot

echo "✅ Бот встановлений у папку $BOT_DIR і запущений через systemd!"
