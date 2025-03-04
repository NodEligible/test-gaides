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

while true; do
    restart_needed=false

    for container in "\${containers[@]}"; do
        if ! docker ps --format '{{.Names}}' | grep -q "^\$container\$"; then
            current_time="$(/usr/bin/date '+%Y-%m-%d %H:%M:%S')"
            echo "$current_time ⛔️ Контейнер $container не работает!" | tee -a "$LOG_FILE"
            restart_needed=true
        fi
    done

    if [ "\$restart_needed" = true ]; then
       current_time="$(/usr/bin/date '+%Y-%m-%d %H:%M:%S')"
       echo "$current_time 🔄 Перезапускаем все контейнеры..." | tee -a "$LOG_FILE"

        docker compose -f "$COMPOSE_FILE" down
        sleep 20
        docker compose -f "$COMPOSE_FILE" up -d
        
    else
    current_time="$(/usr/bin/date '+%Y-%m-%d %H:%M:%S')"
    echo "$current_time ✅ Все контейнеры работают корректно." | tee -a "$LOG_FILE"
    fi

    sleep 1m
done
EOF

# Робимо скрипт виконуваним
chmod +x "$INSTALL_DIR/monitor.sh"

# Створення systemd-сервісу
echo -e "${YELLOW}📝 Создание systemd-сервиса...${NC}"
cat <<EOF > "/etc/systemd/system/$SERVICE_NAME.service"
[Unit]
Description=Мониторинг контейнеров Ritual
After=docker.service
Requires=docker.service

[Service]
Environment="PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
ExecStart=$INSTALL_DIR/monitor.sh
Restart=always
User=root
StandardOutput=append:/root/ritual_service/service.log
StandardError=append:/root/ritual_service/service.log

[Install]
WantedBy=multi-user.target
EOF

# Оновлення systemd
echo -e "${YELLOW}🔄 Обновление systemd...${NC}"
systemctl daemon-reload

# Додавання в автозапуск
echo -e "${YELLOW}🔧 Включение сервиса...${NC}"
systemctl enable "$SERVICE_NAME.service"

# Запуск сервісу
echo -e "${YELLOW}🚀 Запуск сервиса...${NC}"
systemctl start "$SERVICE_NAME.service"

echo -e "${GREEN}✅ Установка завершена!${NC}"
