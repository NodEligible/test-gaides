#!/bin/bash

YELLOW='\e[0;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Шлях для встановлення
INSTALL_DIR="/root/ritual_service"
SERVICE_NAME="ritual-container"

echo -e "${YELLOW}📁 Создание папки $INSTALL_DIR...${NC}"
mkdir -p "$INSTALL_DIR"

# Шлях до файлу логування
LOG_FILE="$HOME/ritual_service/monitor.log"

# Створюємо директорію, якщо її немає
mkdir -p "$(dirname "$LOG_FILE")"

# Створюємо файл логування, якщо він не існує
touch "$LOG_FILE"

# Надаємо права на запис у файл
chmod 644 "$LOG_FILE"

# Шлях до файлу docker-compose
COMPOSE_FILE="/root/infernet-container-starter/deploy/docker-compose.yaml"

# Створення скрипта моніторингу контейнерів
echo -e "${YELLOW}📝 Создание файла мониторинга...${NC}"
cat <<EOF > "$INSTALL_DIR/monitor.sh"
#!/bin/bash

# Кольорові змінні
YELLOW='\e[0;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Лог-файл
LOG_FILE="$HOME/ritual_service/monitor.log"

# Масив контейнерів, які потрібно моніторити
containers=("infernet-node" "deploy-fluentbit-1" "deploy-redis-1" "hello-world")

# Шлях до файлу docker-compose
COMPOSE_FILE="$HOME/infernet-container-starter/deploy/docker-compose.yaml"

while true; do
    restart_needed=false

    for container in "${containers[@]}"; do
        if ! docker ps --format '{{.Names}}' | grep -q "^$container\$"; then
            echo "$(date): Контейнер $container не работает!"
            restart_needed=true
            break
        fi
    done

    if [ "$restart_needed" = true ]; then
        echo "$(date): Останавливаем все контейнеры..."
        docker compose -f "$COMPOSE_FILE" down
        
        echo "$(date): Ожидание 30 секунд перед перезапуском..."
        sleep 30

        echo "$(date): Запускаем все контейнеры..."
        docker compose -f "$COMPOSE_FILE" up -d
    else
        echo "$(date): Все контейнеры работают корректно."
    fi

    sleep 1m
done
EOF

# Робимо скрипт виконуваним
chmod +x "$INSTALL_DIR/monitor.sh"

# Створення systemd-сервісу
echo "📝 Создание systemd-сервиса..."
cat <<EOF > "/etc/systemd/system/$SERVICE_NAME.service"
[Unit]
Description=Мониторинг и перезапуск контейнеров Ritual
After=docker.service
Requires=docker.service

[Service]
ExecStart=$INSTALL_DIR/monitor.sh
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

# Оновлення systemd
echo "🔄 Обновление systemd..."
systemctl daemon-reload

# Додавання в автозапуск
echo "🔧 Включение сервиса..."
systemctl enable "$SERVICE_NAME.service"

# Запуск сервісу
echo "🚀 Запуск сервиса..."
systemctl start "$SERVICE_NAME.service"

# Для проверки логов
# journalctl -u ritual-container.service -f
# systemctl stop ritual-container.service
# systemctl disable ritual-container.service
# systemctl daemon-reload

echo "✅ Успешно установлено!"
