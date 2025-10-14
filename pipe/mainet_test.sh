#!/bin/bash
# ================================================
# 🚀 PipeCDN Node Mainnet Auto-Installer
# ================================================

curl -s https://raw.githubusercontent.com/NodEligible/programs/refs/heads/main/display_logo.sh | bash

YELLOW='\033[0;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# === 1. Перевірка ОС ===
if [[ $(lsb_release -is) != "Ubuntu" && $(lsb_release -is) != "Debian" ]]; then
  echo -e "${RED}❌ Поддерживаются только Ubuntu 22.04+ или Debian 11+.${NC}"
  exit 1
fi

# Запрос інфи
# =====================================================================
# Автовизначення локації
CITY=$(curl -s ipinfo.io/city)
COUNTRY=$(curl -s ipinfo.io/country)
DEFAULT_LOCATION="${CITY}, ${COUNTRY}"
read -rp "➡️ Локация (Enter = ${DEFAULT_LOCATION}): " NODE_LOCATION
NODE_LOCATION=${NODE_LOCATION:-$DEFAULT_LOCATION}
# =====================================================================
# Адрес кошелька
# === Перевірка Solana wallet адреси ===
while true; do
  read -rp "➡️ Введите Solana wallet address: " WALLET
  if [[ "$WALLET" =~ ^[1-9A-HJ-NP-Za-km-z]{32,44}$ ]]; then
    echo -e "✅ Адрес Solana правильный."
    break
  else
    echo -e "❌ Неверный формат! Публичный Solana-адрес должен состоять из 32–44 символов Base58 (без '0x')."
  fi
done
# Назва ноди
read -rp "➡️ Введите имя ноды (NODE_NAME): " NODE_NAME
# Пошта
read -rp "➡️ Введите email оператора: " NODE_EMAIL
# RAM кеш
read -rp "➡️ Размер RAM-кэша в MB (рекомендовано 4096, Enter чтобы принять): " MEMORY_CACHE
if [[ -z "$MEMORY_CACHE" ]]; then
  MEMORY_CACHE=4096
  echo -e "🟢 Используется значение по умолчанию: ${MEMORY_CACHE} MB"
else
  echo -e "✅ Установлено пользовательское значение: ${MEMORY_CACHE} MB"
fi

# Дисковий кеш
read -rp "➡️ Размер дискового кэша в GB (рекомендовано 100, Enter чтобы принять): " DISK_CACHE
if [[ -z "$DISK_CACHE" ]]; then
  DISK_CACHE=100
  echo -e "🟢 Используется значение по умолчанию: ${DISK_CACHE} GB"
else
  echo -e "✅ Установлено пользовательское значение: ${DISK_CACHE} GB"
fi

# =====================================================================
# echo -e "${YELLOW}🛑 Удаляем PipeCDN Node если есть...${NC}"
sudo systemctl stop pipe &>/dev/null
sudo systemctl disable pipe &>/dev/null
sudo systemctl daemon-reload &>/dev/null

rm -rf /opt/pipe &>/dev/null
# Видалити прописні команди
rm -rf /usr/local/bin/pop &>/dev/null
rm -rf /etc/systemd/system/pipe.service &>/dev/null
# =====================================================================

echo -e "${YELLOW}🔧 Начинаем установку PipeCDN Node...${NC}"
sleep 1

# === 2. Оновлення системи ===
echo -e "${YELLOW}📦 Обновление системы (Установка скрыта просто ждите)...${NC}"
sudo apt update -y &>/dev/null
sudo apt upgrade -y &>/dev/null

bash <(curl -s https://raw.githubusercontent.com/NodEligible/programs/refs/heads/main/main.sh) &>/dev/null
bash <(curl -s https://raw.githubusercontent.com/NodEligible/programs/refs/heads/main/ufw.sh) &>/dev/null
sudo apt install gawk bison build-essential manpages-dev ca-certificates -y &>/dev/null

# === 3. Встановлення залежностей ===
sudo apt install -y curl lsof jq ufw bc &>/dev/null

# ---------------------------------------------------------------------------
# Створюємо окремого користувача для ноди і обмежуємо від основної системи
USERNAME="pipe"

if id "$USERNAME" &>/dev/null; then
    echo -e "${YELLOW}Пользователь${NC} '$USERNAME' ${YELLOW}существует${NC}"
else
    sudo useradd -m -s /bin/bash "$USERNAME"
    echo -e "${GREEN}Пользователь${NC} '$USERNAME' ${GREEN}создан.${NC}"
fi
sudo usermod -aG sudo "$USERNAME"

sudo tee /etc/sysctl.d/99-pipe.conf > /dev/null << "EOL"
net.ipv4.ip_local_port_range = 1024 65535
net.core.somaxconn = 65535
net.ipv4.tcp_low_latency = 1
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_wmem = 4096 65536 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.core.wmem_max = 16777216
net.core.rmem_max = 16777216
EOL

sudo sysctl --system &>/dev/null

sudo tee /etc/security/limits.d/pipe.conf > /dev/null << "EOL"
*    hard nofile 65535
*    soft nofile 65535
EOL

# ---------------------------------------------------------------------------

# === 4. Створення директорії ===
echo -e "${YELLOW}📁 Создаем /opt/pipe ...${NC}"
sudo mkdir -p /opt/pipe && cd /opt/pipe || exit 1

# === 5. Завантаження останнього binary ===
echo -e "${YELLOW}⬇️ Загрузка последнего релиза pop...${NC}"
sudo curl -L https://pipe.network/p1-cdn/releases/latest/download/pop -o pop
# Перевірка чи pop дійсно викачався 
if [[ ! -f /opt/pipe/pop ]]; then
  echo -e "${RED}❌ Ошибка: не удалось скачать бинарный файл pop.${NC}"
  exit 1
else
  echo -e "${GREEN}✅ Файл pop успешно загружен!${NC}"
fi

sudo chmod +x pop

# === 6. Створення .env ===
echo -e "${YELLOW}🧾 Создаем .env файл...${NC}"

sudo tee /opt/pipe/.env > /dev/null <<EOF
# PipeCDN Node Configuration

NODE_SOLANA_PUBLIC_KEY=$WALLET
NODE_NAME=$NODE_NAME
NODE_EMAIL="$NODE_EMAIL"
NODE_LOCATION="$NODE_LOCATION"

MEMORY_CACHE_SIZE_MB=$MEMORY_CACHE
DISK_CACHE_SIZE_GB=$DISK_CACHE
DISK_CACHE_PATH=./cache

HTTP_PORT=80
HTTPS_PORT=443

UPNP_ENABLED=false
EOF

# === GLIBC ===
GLIBC_VER=$(ldd --version | head -n1 | awk '{print $NF}')
if (( $(echo "$GLIBC_VER < 2.39" | bc -l) )); then
    echo -e "${YELLOW}⚙️ Обнаружена glibc версии $GLIBC_VER — требуется 2.39.${NC}"

    if [ -d "/opt/glibc-build/glibc-2.39-install" ]; then
        echo -e "${GREEN}✅ Локальная GLIBC 2.39 уже установлена, пересборка не требуется.${NC}"
    else
        echo -e "${YELLOW}🧩 Билдим GLIBC 2.39 (первый раз, это может занять 10–20 минут)...${NC}"

        mkdir -p /opt/glibc-build && cd /opt/glibc-build
        wget -q http://ftp.gnu.org/gnu/libc/glibc-2.39.tar.gz
        tar -xf glibc-2.39.tar.gz &>/dev/null
        mkdir glibc-2.39-build glibc-2.39-install
        cd glibc-2.39-build
        ../glibc-2.39/configure --prefix=/opt/glibc-build/glibc-2.39-install &>/dev/null
        make -j$(nproc) &>/dev/null
        make install &>/dev/null
        sudo chown -R root:root /opt/glibc-build
        chmod -R a+rx /opt/glibc-build
        echo -e "${GREEN}✅ GLIBC 2.39 успешно установлена локально.${NC}"
    fi

    pop_cmd="/opt/glibc-build/glibc-2.39-install/lib/ld-linux-x86-64.so.2 --library-path \"/opt/glibc-build/glibc-2.39-install/lib:/usr/lib/x86_64-linux-gnu/\" /opt/pipe/pop"
else
    echo -e "${GREEN}✅ GLIBC версии $GLIBC_VER уже подходит.${NC}"
    pop_cmd="/opt/pipe/pop"
fi

# === 7. Налаштування UFW ===
echo -e "${YELLOW}🧱 Открываем порты 80 і 443...${NC}"
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 8081/tcp
sudo ufw allow 9090/tcp
sudo ufw reload
# Створюємо папку для логів і надаємо права
sudo mkdir -p /opt/pipe/logs
sudo chmod 755 /opt/pipe/logs


# прописуємо шлях для команд так як вони не працюють по дефолту в ubuntu 22.04, а нода зроблена під 24.04
# === Додаємо глобальний wrapper для pop ===
echo -e "${YELLOW}🔧 Добавляем глобальную команду pop (для Ubuntu 22.04)...${NC}"

sudo tee /usr/local/bin/pop > /dev/null <<'EOF'
#!/bin/bash
# === Pipe POP wrapper with GLIBC 2.39 support ===
LD_PATH="/opt/glibc-build/glibc-2.39-install/lib"
POP_BIN="/opt/pipe/pop"

# Завантажуємо змінні середовища
if [ -f /opt/pipe/.env ]; then
  source /opt/pipe/.env
fi

exec "$LD_PATH/ld-linux-x86-64.so.2" \
  --library-path "$LD_PATH:/usr/lib/x86_64-linux-gnu/" \
  "$POP_BIN" "$@"
EOF

sudo chmod +x /usr/local/bin/pop
sudo chown -R pipe:pipe /opt/pipe

# === 8. Створення systemd сервісу ===
echo -e "${YELLOW}⚙️ Создание systemd сервиса...${NC}"

sudo tee /etc/systemd/system/pipe.service > /dev/null <<EOF
[Unit]
Description=Pipe Network POP Node
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=pipe
Group=pipe
WorkingDirectory=/opt/pipe
EnvironmentFile=/opt/pipe/.env
ExecStart=$pop_cmd
Restart=always
RestartSec=5
StandardOutput=append:/opt/pipe/logs/stdout.log
StandardError=append:/opt/pipe/logs/stderr.log
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

# === 9. Активація сервісу ===
echo -e "${YELLOW}🚀 Запуск сервиса Pipe...${NC}"
sudo systemctl daemon-reload
sudo systemctl enable pipe
sudo systemctl start pipe

sleep 2
if systemctl is-active --quiet pipe; then
  echo -e "${GREEN}✅ PipeCDN нода успешно запущена!${NC}"
else
  echo -e "${RED}❌ Ошибка при запуске сервиса! Проверьте логи: sudo journalctl -u pipe -f${NC}"
  exit 1
fi

# === 10. Перевірка статусу ===
# echo -e "${YELLOW}🩺 Проверка состояния...${NC}"
# sleep 3
# curl -s http://localhost:8081/health || echo -e "${RED}❌ Не удалось подключиться к /health${NC}"

echo -e "${GREEN}🎉 Установка завершена!${NC}"
echo -e "${GREEN}Проверить логи:${NC} tail -n 100 -f /opt/pipe/logs/stdout.log"
